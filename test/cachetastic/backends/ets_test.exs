defmodule Cachetastic.Backend.ETSTest do
  use ExUnit.Case
  alias Cachetastic.Backend.ETS

  setup do
    {:ok, pid} = ETS.start_link([])
    {:ok, ets: pid}
  end

  test "put and get a value", %{ets: ets} do
    assert :ok == ETS.put(ets, "key", "value")
    assert {:ok, "value"} == ETS.get(ets, "key")
  end

  test "delete a value", %{ets: ets} do
    ETS.put(ets, "key", "value")
    assert :ok == ETS.delete(ets, "key")
    assert :error == ETS.get(ets, "key")
  end

  test "clear the cache", %{ets: ets} do
    ETS.put(ets, "key1", "value1")
    ETS.put(ets, "key2", "value2")
    assert :ok == ETS.clear(ets)
    assert :error == ETS.get(ets, "key1")
    assert :error == ETS.get(ets, "key2")
  end
end
