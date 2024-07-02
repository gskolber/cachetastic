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
    assert {:error, :not_found} == Redis.get(redis, "key")
  end

  test "clear the cache", %{redis: redis} do
    Redis.put(redis, "key1", "value1")
    Redis.put(redis, "key2", "value2")
    assert :ok == Redis.clear(redis)
    assert {:error, :not_found} == Redis.get(redis, "key1")
    assert {:error, :not_found} == Redis.get(redis, "key2")
  end

  test "start_link raises error if host is missing" do
    assert_raise ArgumentError, "Both :host and :port must be provided in options", fn ->
      Redis.start_link(port: 6379, ttl: 3600)
    end
  end

  test "start_link raises error if port is missing" do
    assert_raise ArgumentError, "Both :host and :port must be provided in options", fn ->
      Redis.start_link(host: "localhost", ttl: 3600)
    end
  end

  test "start_link works with both host and port" do
    assert {:ok, _state} = Redis.start_link(host: "localhost", port: 6379, ttl: 3600)
  end
end
