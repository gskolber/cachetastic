defmodule Cachetastic.Backend.RedisPoolTest do
  use ExUnit.Case

  alias Cachetastic.Backend.RedisPool

  setup do
    {:ok, pid} = RedisPool.start_link(host: "localhost", port: 6379, pool_size: 3, ttl: 3600)
    RedisPool.clear(pid)
    %{pid: pid}
  end

  test "put and get a value", %{pid: pid} do
    assert :ok == RedisPool.put(pid, "pool_key", "pool_value")
    assert {:ok, "pool_value"} == RedisPool.get(pid, "pool_key")
  end

  test "delete a value", %{pid: pid} do
    RedisPool.put(pid, "pool_key", "pool_value")
    assert :ok == RedisPool.delete(pid, "pool_key")
    assert {:error, :not_found} == RedisPool.get(pid, "pool_key")
  end

  test "clear the cache", %{pid: pid} do
    RedisPool.put(pid, "k1", "v1")
    RedisPool.put(pid, "k2", "v2")
    assert :ok == RedisPool.clear(pid)
    assert {:error, :not_found} == RedisPool.get(pid, "k1")
    assert {:error, :not_found} == RedisPool.get(pid, "k2")
  end

  test "concurrent operations work with pool", %{pid: pid} do
    tasks =
      for i <- 1..20 do
        Task.async(fn ->
          key = "concurrent_#{i}"
          RedisPool.put(pid, key, "value_#{i}")
          RedisPool.get(pid, key)
        end)
      end

    results = Task.await_many(tasks, 5000)
    assert Enum.all?(results, &match?({:ok, _}, &1))
  end

  test "delete_pattern removes matching keys", %{pid: pid} do
    RedisPool.put(pid, "user:1", "alice")
    RedisPool.put(pid, "user:2", "bob")
    RedisPool.put(pid, "post:1", "hello")

    assert :ok == RedisPool.delete_pattern(pid, "user:*")

    assert {:error, :not_found} == RedisPool.get(pid, "user:1")
    assert {:error, :not_found} == RedisPool.get(pid, "user:2")
    assert {:ok, "hello"} == RedisPool.get(pid, "post:1")
  end
end
