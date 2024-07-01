defmodule Cachetastic do
  @moduledoc """
  Cachetastic main module for interacting with the cache.
  """

  alias Cachetastic.Backend
  alias Cachetastic.Config
  alias Cachetastic.FaultTolerance

  def start_link() do
    primary_backend = Config.primary_backend()
    Config.start_backend(primary_backend)
  end

  def put(key, value, ttl \\ nil) do
    primary_backend = Config.primary_backend()
    backup_backend = Config.backup_backend()

    {:ok, primary_pid} = Config.start_backend(primary_backend)
    {:ok, backup_pid} = Config.start_backend(backup_backend)

    FaultTolerance.with_fallback(
      fn -> apply(Backend, primary_backend).put(primary_pid, key, value, ttl) end,
      fn -> apply(Backend, backup_backend).put(backup_pid, key, value, ttl) end
    )
  end

  def get(key) do
    primary_backend = Config.primary_backend()
    backup_backend = Config.backup_backend()

    {:ok, primary_pid} = Config.start_backend(primary_backend)
    {:ok, backup_pid} = Config.start_backend(backup_backend)

    FaultTolerance.with_fallback(
      fn -> apply(Backend, primary_backend).get(primary_pid, key) end,
      fn -> apply(Backend, backup_backend).get(backup_pid, key) end
    )
  end

  def delete(key) do
    primary_backend = Config.primary_backend()
    backup_backend = Config.backup_backend()

    {:ok, primary_pid} = Config.start_backend(primary_backend)
    {:ok, backup_pid} = Config.start_backend(backup_backend)

    FaultTolerance.with_fallback(
      fn -> apply(Backend, primary_backend).delete(primary_pid, key) end,
      fn -> apply(Backend, backup_backend).delete(backup_pid, key) end
    )
  end

  def clear() do
    primary_backend = Config.primary_backend()
    backup_backend = Config.backup_backend()

    {:ok, primary_pid} = Config.start_backend(primary_backend)
    {:ok, backup_pid} = Config.start_backend(backup_backend)

    FaultTolerance.with_fallback(
      fn -> apply(Backend, primary_backend).clear(primary_pid) end,
      fn -> apply(Backend, backup_backend).clear(backup_pid) end
    )
  end
end
