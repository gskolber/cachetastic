defmodule Cachetastic.PatternDeleteTest do
  use ExUnit.Case

  setup do
    Application.put_env(:cachetastic, :backends,
      primary: :redis_pool,
      redis_pool: [host: "localhost", port: 6379, pool_size: 3],
      fault_tolerance: [primary: :redis_pool]
    )

    Application.delete_env(:cachetastic, :key_prefix)
    Cachetastic.ensure_backends_started()
    Cachetastic.clear()

    :ok
  end

  test "delete_pattern removes matching keys" do
    Cachetastic.put("user:1", "alice")
    Cachetastic.put("user:2", "bob")
    Cachetastic.put("post:1", "hello")

    assert :ok = Cachetastic.delete_pattern("user:*")

    assert {:error, :not_found} = Cachetastic.get("user:1")
    assert {:error, :not_found} = Cachetastic.get("user:2")
    assert {:ok, "hello"} = Cachetastic.get("post:1")
  end

  test "delete_pattern with named cache" do
    Cachetastic.put(:api, "v1:users", "data1", nil)
    Cachetastic.put(:api, "v1:posts", "data2", nil)
    Cachetastic.put(:api, "v2:users", "data3", nil)

    assert :ok = Cachetastic.delete_pattern(:api, "v1:*")

    assert {:error, :not_found} = Cachetastic.get(:api, "v1:users")
    assert {:error, :not_found} = Cachetastic.get(:api, "v1:posts")
    assert {:ok, "data3"} = Cachetastic.get(:api, "v2:users")
  end

  test "delete_pattern returns error on unsupported backend" do
    Application.put_env(:cachetastic, :backends,
      primary: :ets,
      ets: [],
      fault_tolerance: [primary: :ets]
    )

    Cachetastic.ensure_backends_started()

    assert {:error, :pattern_delete_not_supported} = Cachetastic.delete_pattern("key:*")
  end
end
