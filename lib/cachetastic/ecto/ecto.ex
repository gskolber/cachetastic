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
            Jason.decode(json_result, keys: :atoms)

          _ ->
            result = @repo.all(queryable, opts)
            {:ok, json_result} = Jason.encode(result)
            Cachetastic.put(cache_key, json_result)
            {:ok, result}
        end
      end

      def invalidate_cache(queryable, opts \\ []) do
        cache_key = generate_cache_key(queryable, opts)
        Cachetastic.delete(cache_key)
      end

      defp generate_cache_key(queryable, opts) do
        key = inspect(queryable)
        {:ok, json_key} = Jason.encode(key)
        json_key
      end
    end
  end
end
