defmodule Cachetastic.Backend.Redis do
  @moduledoc """
  Redis backend for Cachetastic.

  This module implements the Cachetastic.Behaviour using Redis as the storage mechanism.

  ## Options

    * `:host` - The Redis host (default: "localhost")
    * `:port` - The Redis port (default: 6379)
    * `:ttl` - The time-to-live for cache entries in seconds (default: 3600)

  ## Examples

      # Start the Redis backend
      {:ok, state} = Cachetastic.Backend.Redis.start_link(host: "localhost", port: 6379, ttl: 3600)

      # Put a value in the cache
      Cachetastic.Backend.Redis.put(state, "key", "value")

      # Get a value from the cache
      {:ok, value} = Cachetastic.Backend.Redis.get(state, "key")

      # Delete a value from the cache
      :ok = Cachetastic.Backend.Redis.delete(state, "key")

      # Clear all values from the cache
      :ok = Cachetastic.Backend.Redis.clear(state)
  """

  @behaviour Cachetastic.Behaviour

  @doc """
  Starts the Redis backend with the given options.
  """
  def start_link(opts) do
    host = Keyword.get(opts, :host, "localhost")
    port = Keyword.get(opts, :port, 6379)
    ttl = Keyword.get(opts, :ttl, 3600)
    {:ok, conn} = Redix.start_link(host: host, port: port)
    {:ok, %{conn: conn, ttl: ttl}}
  end

  @doc """
  Puts a value in the Redis cache.
  """
  def put(state, key, value, ttl \\ nil) do
    ttl = ttl || state.ttl

    case Redix.command(state.conn, ["SET", key, value, "EX", ttl]) do
      {:ok, "OK"} -> :ok
      error -> error
    end
  end

  @doc """
  Gets a value from the Redis cache by key.
  """
  def get(state, key) do
    case Redix.command(state.conn, ["GET", key]) do
      {:ok, nil} -> :error
      {:ok, value} -> {:ok, value}
      error -> error
    end
  end

  @doc """
  Deletes a value from the Redis cache by key.
  """
  def delete(state, key) do
    case Redix.command(state.conn, ["DEL", key]) do
      {:ok, _} -> :ok
      error -> error
    end
  end

  @doc """
  Clears all values from the Redis cache.
  """
  def clear(state) do
    case Redix.command(state.conn, ["FLUSHDB"]) do
      {:ok, _} -> :ok
      error -> error
    end
  end
end
