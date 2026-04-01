defmodule Cachetastic.FaultTolerance.NoFallbackTest do
  use ExUnit.Case

  setup do
    # Configure with ETS only, no backup
    Application.put_env(:cachetastic, :backends,
      primary: :ets,
      ets: [],
      fault_tolerance: [primary: :ets]
    )

    Cachetastic.ensure_backends_started()

    :ok
  end

  test "put without fallback" do
    assert :ok == Cachetastic.put("key", "value")
    assert {:ok, "value"} == Cachetastic.get("key")
  end

  test "get without fallback" do
    Cachetastic.put("key", "value")
    assert {:ok, "value"} == Cachetastic.get("key")
  end

  test "delete without fallback" do
    Cachetastic.put("key", "value")
    assert :ok == Cachetastic.delete("key")
    assert {:error, :not_found} == Cachetastic.get("key")
  end

  test "clear without fallback" do
    Cachetastic.put("key1", "value1")
    Cachetastic.put("key2", "value2")
    assert :ok == Cachetastic.clear()
    assert {:error, :not_found} == Cachetastic.get("key1")
    assert {:error, :not_found} == Cachetastic.get("key2")
  end
end
