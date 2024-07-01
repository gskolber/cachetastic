defmodule Cachetastic do
  @moduledoc """
  Cachetastic main module for interacting with the cache.
  """

  alias Cachetastic.Config
  alias Cachetastic.FaultTolerance

  def start_link() do
    primary_backend = Config.primary_backend()
    Config.start_backend(primary_backend)
  end

  def put(key, value, ttl \\ nil) do
    primary_backend = Config.primary_backend()
    backup_backend = Config.backup_backend()

    {:ok, primary_state} = Config.start_backend(primary_backend)
    {:ok, backup_state} = Config.start_backend(backup_backend)

    FaultTolerance.with_fallback(
      fn -> apply(module_for(primary_backend), :put, [primary_state, key, value, ttl]) end,
      fn -> apply(module_for(backup_backend), :put, [backup_state, key, value, ttl]) end
    )
  end

  def get(key) do
    primary_backend = Config.primary_backend()
    backup_backend = Config.backup_backend()

    {:ok, primary_state} = Config.start_backend(primary_backend)
    {:ok, backup_state} = Config.start_backend(backup_backend)

    FaultTolerance.with_fallback(
      fn -> apply(module_for(primary_backend), :get, [primary_state, key]) end,
      fn -> apply(module_for(backup_backend), :get, [backup_state, key]) end
    )
  end

  def delete(key) do
    primary_backend = Config.primary_backend()
    backup_backend = Config.backup_backend()

    {:ok, primary_state} = Config.start_backend(primary_backend)
    {:ok, backup_state} = Config.start_backend(backup_backend)

    FaultTolerance.with_fallback(
      fn -> apply(module_for(primary_backend), :delete, [primary_state, key]) end,
      fn -> apply(module_for(backup_backend), :delete, [backup_state, key]) end
    )
  end

  def clear() do
    primary_backend = Config.primary_backend()
    backup_backend = Config.backup_backend()

    {:ok, primary_state} = Config.start_backend(primary_backend)
    {:ok, backup_state} = Config.start_backend(backup_backend)

    FaultTolerance.with_fallback(
      fn -> apply(module_for(primary_backend), :clear, [primary_state]) end,
      fn -> apply(module_for(backup_backend), :clear, [backup_state]) end
    )
  end

  defp module_for(:redis), do: Cachetastic.Backend.Redis
  defp module_for(:ets), do: Cachetastic.Backend.ETS
end
