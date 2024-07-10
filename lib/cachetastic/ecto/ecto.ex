defmodule Cachetastic.Ecto do
  @moduledoc """
  Provides caching functionality for Ecto queries.

  This module allows you to easily cache and retrieve Ecto query results using Cachetastic.
  It supports both ETS and Redis backends for caching.

  ## Usage

  To use this module, you need to include it in your Ecto repository and configure Cachetastic.

  ### Step 1: Add Cachetastic to Your Dependencies

  Update your `mix.exs` file to include Cachetastic as a dependency:

      defp deps do
        [
          {:cachetastic, "~> 0.1.0"}
        ]
      end

  Run `mix deps.get` to fetch the dependencies.

  ### Step 2: Configure Cachetastic

  Add the configuration for Cachetastic in your `config/config.exs` file:

      use Mix.Config

      config :cachetastic,
        backends: [
          ets: [ttl: 600],
          redis: [host: "localhost", port: 6379, ttl: 3600]
        ],
        fault_tolerance: [primary: :redis, backup: :ets]

  ### Step 3: Implement Cachetastic in Your Ecto Repo

  Add the Cachetastic plugin to your Ecto repo:

      defmodule MyApp.Repo do
        use Ecto.Repo,
          otp_app: :my_app,
          adapter: Ecto.Adapters.Postgres

        use Cachetastic.Ecto, repo: MyApp.Repo
      end

  ### Step 4: Use Cachetastic in Your Application

  Now you can use Cachetastic to cache and retrieve Ecto query results:

      defmodule MyApp.SomeModule do
        alias MyApp.Repo
        alias MyApp.User

        def some_function do
          query = from u in User, where: u.active == true

          # Fetch with cache
          {:ok, users} = Repo.get_with_cache(query)

          # Invalidate cache
          Repo.invalidate_cache(query)
        end
      end
  """

  alias Jason
  alias Ecto.Schema.Metadata

  @doc """
  Macro to be used in an Ecto repository module to enable caching for Ecto queries.

  ## Options

    * `:repo` - The Ecto repository module (required).

  ## Example

      defmodule MyApp.Repo do
        use Ecto.Repo,
          otp_app: :my_app,
          adapter: Ecto.Adapters.Postgres

        use Cachetastic.Ecto, repo: MyApp.Repo
      end
  """
  defmacro __using__(opts) do
    repo = Keyword.fetch!(opts, :repo)

    quote do
      @repo unquote(repo)

      @doc """
      Fetches query results from the cache if available, otherwise executes the query and caches the results.

      ## Parameters

        * `queryable` - The Ecto queryable to be executed.
        * `opts` - Options for the query (default: []).

      ## Returns

        * `{:ok, result}` - The query results, either from the cache or from the database.
        * `{:error, reason}` - An error occurred while fetching the results.

      ## Example

          query = from u in User, where: u.active == true
          {:ok, users} = Repo.get_with_cache(query)
      """
      def get_with_cache(queryable, opts \\ []) do
        cache_key = generate_cache_key(queryable, opts)

        case Cachetastic.get(cache_key) do
          {:ok, json_result} ->
            {:ok, cached_maps} = Jason.decode(json_result, keys: :atoms)
            result = Enum.map(cached_maps, &map_to_struct/1)
            {:ok, result}

          {:error, :not_found} ->
            result = @repo.all(queryable, opts)
            cache_maps = Enum.map(result, &struct_to_map/1)

            {:ok, json_result} = Jason.encode(cache_maps)
            Cachetastic.put(cache_key, json_result)

            {:ok, result}

          error ->
            {:error, %{error_data: error}}
        end
      end

      @doc """
      Invalidates the cache for the given query.

      ## Parameters

        * `queryable` - The Ecto queryable whose cache should be invalidated.
        * `opts` - Options for the query (default: []).

      ## Example

          query = from u in User, where: u.active == true
          Repo.invalidate_cache(query)
      """
      def invalidate_cache(queryable, opts \\ []) do
        cache_key = generate_cache_key(queryable, opts)
        Cachetastic.delete(cache_key)
      end

      defp generate_cache_key(queryable, opts), do: inspect(queryable) <> inspect(opts)

      defp struct_to_map(struct) do
        struct
        |> Map.from_struct()
        |> Map.put(:__struct__, Atom.to_string(struct.__struct__))
        |> Map.put(:__meta__, meta_to_map(struct.__meta__))
      end

      defp map_to_struct(map) do
        struct_module = String.to_existing_atom(map[:__struct__])
        meta = map_to_meta(map[:__meta__])

        struct_module
        |> struct(Map.drop(map, [:__meta__, :__struct__]))
        |> Map.put(:__meta__, meta)
        |> Map.put(:__struct__, struct_module)
      end

      defp meta_to_map(%Metadata{} = meta) do
        %{
          state: meta.state,
          source: meta.source,
          prefix: meta.prefix,
          context: meta.context,
          schema: meta.schema
        }
      end

      defp map_to_meta(map) when is_map(map) do
        %Metadata{
          state: map[:state] |> String.to_existing_atom(),
          source: map[:source],
          prefix: map[:prefix],
          context: map[:context],
          schema: map[:schema] |> String.to_existing_atom()
        }
      end
    end
  end
end
