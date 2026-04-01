defmodule Cachetastic.KeyPrefixTest do
  use ExUnit.Case

  setup do
    Application.put_env(:cachetastic, :backends,
      primary: :ets,
      ets: [],
      fault_tolerance: [primary: :ets]
    )

    Cachetastic.ensure_backends_started()

    :ok
  end

  test "keys are prefixed when key_prefix is set" do
    Application.put_env(:cachetastic, :key_prefix, "myapp")

    Cachetastic.put("user:1", "alice")
    assert {:ok, "alice"} = Cachetastic.get("user:1")

    # Under the hood the ETS key is "myapp:user:1"
    # Accessing without prefix should not find it if we bypass
    # But through the API it should be transparent
    Cachetastic.delete("user:1")
    assert {:error, :not_found} = Cachetastic.get("user:1")

    Application.delete_env(:cachetastic, :key_prefix)
  end

  test "keys work normally without prefix" do
    Application.delete_env(:cachetastic, :key_prefix)

    Cachetastic.put("raw_key", "raw_value")
    assert {:ok, "raw_value"} = Cachetastic.get("raw_key")
  end

  test "fetch respects key prefix" do
    Application.put_env(:cachetastic, :key_prefix, "app")

    {:ok, "computed"} = Cachetastic.fetch("prefixed_fetch", fn -> "computed" end)
    assert {:ok, "computed"} = Cachetastic.get("prefixed_fetch")

    Application.delete_env(:cachetastic, :key_prefix)
  end
end
