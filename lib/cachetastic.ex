defmodule Cachetastic do
  @moduledoc """
  Cachetastic main module for interacting with the cache.

  This module provides a unified interface for various caching mechanisms
  such as ETS and Redis, with built-in fault tolerance. It allows you to
  perform basic caching operations like put, get, delete, and clear.

  ## Configuration

  You can configure the backends and fault tolerance settings in your `config/config.exs`:

      use Mix.Config

      config :cachetastic,
        backends: [
          ets: [ttl: 600],
          redis: [host: "localhost", port: 6379, ttl: 3600]
        ],
        fault_tolerance: [primary: :redis, backup: :ets]

  ## Examples

      # Start the cache
      {:ok, _pid} = Cachetastic.start_link()

      # Perform cache operations
      Cachetastic.put("key", "value")
      {:ok, value} = Cachetastic.get("key")
      Cachetastic.delete("key")
      Cachetastic.clear()
  """

  alias Cachetastic.Config
  alias Cachetastic.FaultTolerance

  @doc """
  Starts the cache with the primary backend.
  """
  def start_link() do
    primary_backend = Config.primary_backend()
    Config.start_backend(primary_backend)
  end

  @doc """
  Puts a value in the cache with the specified key and optional TTL.
  """
  def put(key, value, ttl \\ nil) do
    primary_backend = Config.primary_backend()
    {:ok, primary_state} = Config.start_backend(primary_backend)

    if backup_backend = Config.backup_backend() do
      {:ok, backup_state} = Config.start_backend(backup_backend)

      FaultTolerance.with_fallback(
        fn -> apply(module_for(primary_backend), :put, [primary_state, key, value, ttl]) end,
        fn -> apply(module_for(backup_backend), :put, [backup_state, key, value, ttl]) end
      )
    else
      apply(module_for(primary_backend), :put, [primary_state, key, value, ttl])
    end
  end

  @doc """
  Gets a value from the cache by key.
  """
  def get(key) do
    primary_backend = Config.primary_backend()
    {:ok, primary_state} = Config.start_backend(primary_backend)

    if backup_backend = Config.backup_backend() do
      {:ok, backup_state} = Config.start_backend(backup_backend)

      FaultTolerance.with_fallback(
        fn -> apply(module_for(primary_backend), :get, [primary_state, key]) end,
        fn -> apply(module_for(backup_backend), :get, [backup_state, key]) end
      )
    else
      apply(module_for(primary_backend), :get, [primary_state, key])
    end
  end

  @doc """
  Deletes a value from the cache by key.
  """
  def delete(key) do
    primary_backend = Config.primary_backend()
    {:ok, primary_state} = Config.start_backend(primary_backend)

    if backup_backend = Config.backup_backend() do
      {:ok, backup_state} = Config.start_backend(backup_backend)

      FaultTolerance.with_fallback(
        fn -> apply(module_for(primary_backend), :delete, [primary_state, key]) end,
        fn -> apply(module_for(backup_backend), :delete, [backup_state, key]) end
      )
    else
      apply(module_for(primary_backend), :delete, [primary_state, key])
    end
  end

  @doc """
  Clears all values from the cache.
  """
  def clear() do
    primary_backend = Config.primary_backend()
    {:ok, primary_state} = Config.start_backend(primary_backend)

    if backup_backend = Config.backup_backend() do
      {:ok, backup_state} = Config.start_backend(backup_backend)

      FaultTolerance.with_fallback(
        fn -> apply(module_for(primary_backend), :clear, [primary_state]) end,
        fn -> apply(module_for(backup_backend), :clear, [backup_state]) end
      )
    else
      apply(module_for(primary_backend), :clear, [primary_state])
    end
  end

  defp module_for(:redis), do: Cachetastic.Backend.Redis
  defp module_for(:ets), do: Cachetastic.Backend.ETS
end
