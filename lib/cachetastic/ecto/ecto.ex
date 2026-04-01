defmodule Cachetastic.Ecto do
  @moduledoc """
  Provides caching functionality for Ecto queries.

  Uses the configured `Cachetastic.Serializer` for encoding/decoding cached data.

  ## Usage

      defmodule MyApp.Repo do
        use Ecto.Repo,
          otp_app: :my_app,
          adapter: Ecto.Adapters.Postgres

        use Cachetastic.Ecto, repo: MyApp.Repo
      end

      query = from u in User, where: u.active == true
      {:ok, users} = Repo.get_with_cache(query)
      Repo.invalidate_cache(query)
  """

  alias Ecto.Schema.Metadata

  defmacro __using__(opts) do
    repo = Keyword.fetch!(opts, :repo)

    quote do
      @repo unquote(repo)

      @doc """
      Fetches query results from the cache or executes the query and caches the results.
      """
      def get_with_cache(queryable, opts \\ []) do
        cache_key = generate_cache_key(queryable, opts)
        serializer = Cachetastic.Serializer.configured()

        case Cachetastic.get(cache_key) do
          {:ok, cached} ->
            case serializer.decode(cached) do
              {:ok, decoded_maps} ->
                result = Enum.map(decoded_maps, &map_to_struct/1)
                {:ok, result}

              {:error, _} = error ->
                error
            end

          {:error, :not_found} ->
            result = @repo.all(queryable, opts)
            cache_maps = Enum.map(result, &struct_to_map/1)

            case serializer.encode(cache_maps) do
              {:ok, encoded} ->
                Cachetastic.put(cache_key, encoded)
                {:ok, result}

              {:error, _} = error ->
                error
            end

          error ->
            {:error, %{error_data: error}}
        end
      end

      @doc """
      Invalidates the cache for the given query.
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
        struct_module = String.to_existing_atom(map["__struct__"] || map[:__struct__])
        meta = map_to_meta(map["__meta__"] || map[:__meta__])

        struct_module
        |> struct(atomize_keys(Map.drop(map, ["__meta__", "__struct__", :__meta__, :__struct__])))
        |> Map.put(:__meta__, meta)
        |> Map.put(:__struct__, struct_module)
      end

      defp atomize_keys(map) when is_map(map) do
        Map.new(map, fn
          {k, v} when is_binary(k) -> {String.to_existing_atom(k), v}
          {k, v} -> {k, v}
        end)
      end

      defp meta_to_map(%Metadata{} = meta) do
        %{
          state: Atom.to_string(meta.state),
          source: meta.source,
          prefix: meta.prefix,
          context: meta.context,
          schema: Atom.to_string(meta.schema)
        }
      end

      defp map_to_meta(map) when is_map(map) do
        state = map["state"] || map[:state]
        schema = map["schema"] || map[:schema]

        %Metadata{
          state: to_existing_atom(state),
          source: map["source"] || map[:source],
          prefix: map["prefix"] || map[:prefix],
          context: map["context"] || map[:context],
          schema: to_existing_atom(schema)
        }
      end

      defp to_existing_atom(val) when is_atom(val), do: val
      defp to_existing_atom(val) when is_binary(val), do: String.to_existing_atom(val)
    end
  end
end
