defmodule Cachetastic.Backend.RedisTest do
  use ExUnit.Case
  alias Cachetastic.Backend.Redis

  setup do
    {:ok, conn} = Redis.start_link(host: "localhost", port: 6379)
    {:ok, redis: conn}
  end

  test "put and get a value", %{redis: redis} do
    assert :ok == Redis.put(redis, "key", "value")
    assert {:ok, "value"} == Redis.get(redis, "key")
  end

  test "delete a value", %{redis: redis} do
    Redis.put(redis, "key", "value")
    assert :ok == Redis.delete(redis, "key")
    assert :error == Redis.get(redis, "key")
  end

  test "clear the cache", %{redis: redis} do
    Redis.put(redis, "key1", "value1")
    Redis.put(redis, "key2", "value2")
    assert :ok == Redis.clear(redis)
    assert :error == Redis.get(redis, "key1")
    assert :error == Redis.get(redis, "key2")
  end
end
