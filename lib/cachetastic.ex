defmodule Cachetastic do
  @moduledoc """
  Cachetastic main module for interacting with the cache.
  """

  @backend Cachetastic.Config.backend_module()

  def start_link() do
    Cachetastic.Config.start_backend()
  end

  def put(key, value, ttl \\ nil) do
    {:ok, pid} = start_link()
    @backend.put(pid, key, value, ttl)
  end

  def get(key) do
    {:ok, pid} = start_link()
    @backend.get(pid, key)
  end

  def delete(key) do
    {:ok, pid} = start_link()
    @backend.delete(pid, key)
  end

  def clear() do
    {:ok, pid} = start_link()
    @backend.clear(pid)
  end
end
