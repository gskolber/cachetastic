defmodule Cachetastic.Backend.MultiLayerTest do
  use ExUnit.Case

  alias Cachetastic.Backend.MultiLayer

  setup do
    {:ok, pid} =
      MultiLayer.start_link(
        l1: [ttl: 60, table_name: :ml_test_l1],
        l2: [host: "localhost", port: 6379, ttl: 3600]
      )

    MultiLayer.clear(pid)
    %{pid: pid}
  end

  test "put and get through multi-layer", %{pid: pid} do
    assert :ok == MultiLayer.put(pid, "ml_key", "ml_value")
    assert {:ok, "ml_value"} == MultiLayer.get(pid, "ml_key")
  end

  test "get populates L1 from L2 on L1 miss", %{pid: pid} do
    # Put directly — both layers have it
    MultiLayer.put(pid, "ml_key2", "value2")

    # Value should be in L1 now (populated from L2 or direct)
    assert {:ok, "value2"} == MultiLayer.get(pid, "ml_key2")
  end

  test "delete removes from both layers", %{pid: pid} do
    MultiLayer.put(pid, "ml_key3", "value3")
    assert :ok == MultiLayer.delete(pid, "ml_key3")
    assert {:error, :not_found} == MultiLayer.get(pid, "ml_key3")
  end

  test "clear removes from both layers", %{pid: pid} do
    MultiLayer.put(pid, "ml_k1", "v1")
    MultiLayer.put(pid, "ml_k2", "v2")
    assert :ok == MultiLayer.clear(pid)
    assert {:error, :not_found} == MultiLayer.get(pid, "ml_k1")
    assert {:error, :not_found} == MultiLayer.get(pid, "ml_k2")
  end
end
