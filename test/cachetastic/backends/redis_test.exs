defmodule Cachetastic.Backend.RedisTest do
  use ExUnit.Case

  alias Cachetastic.Backend.Redis

  setup do
    {:ok, pid} = Redis.start_link(host: "localhost", port: 6379, ttl: 3600)
    Redis.clear(pid)
    %{pid: pid}
  end

  test "put and get a value", %{pid: pid} do
    assert :ok == Redis.put(pid, "key", "value")
    assert {:ok, "value"} == Redis.get(pid, "key")
  end

  test "delete a value", %{pid: pid} do
    Redis.put(pid, "key", "value")
    assert :ok == Redis.delete(pid, "key")
    assert {:error, :not_found} == Redis.get(pid, "key")
  end

  test "clear the cache", %{pid: pid} do
    Redis.put(pid, "key1", "value1")
    Redis.put(pid, "key2", "value2")
    assert :ok == Redis.clear(pid)
    assert {:error, :not_found} == Redis.get(pid, "key1")
    assert {:error, :not_found} == Redis.get(pid, "key2")
  end

  test "start_link fails if host is missing" do
    Process.flag(:trap_exit, true)
    assert {:error, _} = Redis.start_link(port: 6379, ttl: 3600)
  end

  test "start_link fails if port is missing" do
    Process.flag(:trap_exit, true)
    assert {:error, _} = Redis.start_link(host: "localhost", ttl: 3600)
  end

  test "start_link works with both host and port" do
    assert {:ok, _pid} = Redis.start_link(host: "localhost", port: 6379, ttl: 3600)
  end
end
