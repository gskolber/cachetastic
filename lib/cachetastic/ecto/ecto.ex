defmodule Cachetastic.Ecto do
  @moduledoc """
  Provides caching functionality for Ecto queries.
  """

  alias Jason

  defmacro __using__(opts) do
    repo = Keyword.fetch!(opts, :repo)

    quote do
      @repo unquote(repo)

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

      def invalidate_cache(queryable, opts \\ []) do
        cache_key = generate_cache_key(queryable, opts)
        Cachetastic.delete(cache_key)
      end

      defp generate_cache_key(queryable, opts), do: inspect(queryable) <> inspect(opts)

      defp struct_to_map(struct) do
        struct
        |> Map.from_struct()
        |> Map.put(:__struct__, Atom.to_string(struct.__struct__))
        |> Map.drop([:__meta__])
      end

      defp map_to_struct(map) do
        struct_module = String.to_existing_atom(map[:__struct__])

        struct(struct_module, map)
      end
    end
  end
end
