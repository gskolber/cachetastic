defmodule Cachetastic.Backend.ETS do
  @moduledoc """
  ETS backend for Cachetastic.

  This module implements the Cachetastic.Behaviour using ETS as the storage mechanism.

  ## Options

    * `:table_name` - The name of the ETS table (default: :cachetastic)
    * `:ttl` - The time-to-live for cache entries in seconds (default: 600)

  ## Examples

      # Start the ETS backend
      {:ok, state} = Cachetastic.Backend.ETS.start_link(table_name: :my_cache, ttl: 3600)

      # Put a value in the cache
      Cachetastic.Backend.ETS.put(state, "key", "value")

      # Get a value from the cache
      {:ok, value} = Cachetastic.Backend.ETS.get(state, "key")

      # Delete a value from the cache
      :ok = Cachetastic.Backend.ETS.delete(state, "key")

      # Clear all values from the cache
      :ok = Cachetastic.Backend.ETS.clear(state)
  """

  @behaviour Cachetastic.Behaviour

  @doc """
  Starts the ETS backend with the given options.
  """
  def start_link(opts) do
    table_name = Keyword.get(opts, :table_name, :cachetastic)
    ttl = Keyword.get(opts, :ttl, 600)

    if :ets.info(table_name) == :undefined do
      :ets.new(table_name, [:named_table, :public, :set])
    end

    {:ok,
     %{
       table_name: table_name,
       ttl: ttl
     }}
  end

  @doc """
  Puts a value in the ETS cache.
  """
  def put(state, key, value, _ttl \\ nil) do
    :ets.insert(state.table_name, {key, value})
    :ok
  end

  @doc """
  Gets a value from the ETS cache by key.
  """
  def get(state, key) do
    case :ets.lookup(state.table_name, key) do
      [{^key, value}] -> {:ok, value}
      _ -> :error
    end
  end

  @doc """
  Deletes a value from the ETS cache by key.
  """
  def delete(state, key) do
    :ets.delete(state.table_name, key)
    :ok
  end

  @doc """
  Clears all values from the ETS cache.
  """
  def clear(state) do
    :ets.delete_all_objects(state.table_name)
    :ok
  end
end
