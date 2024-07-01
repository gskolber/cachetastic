defmodule Cachetastic.FaultTolerance.NoFallbackTest do
  use ExUnit.Case

  alias Cachetastic.Backend.ETS

  setup do
    # Configuração inicial sem tolerância a falhas, utilizando ETS como backend primário
    Application.put_env(:cachetastic, :fault_tolerance, primary: :ets)

    {:ok, ets_state} = ETS.start_link(table_name: :cachetastic_ets)
    {:ok, ets_state: ets_state}
  end

  test "put without fallback", %{ets_state: _ets_state} do
    assert :ok == Cachetastic.put("key", "value")
    assert {:ok, "value"} == Cachetastic.get("key")
  end

  test "get without fallback", %{ets_state: _ets_state} do
    Cachetastic.put("key", "value")
    assert {:ok, "value"} == Cachetastic.get("key")
  end

  test "delete without fallback", %{ets_state: ets_state} do
    Cachetastic.put("key", "value")
    assert :ok == Cachetastic.delete("key")
    assert :error == ETS.get(ets_state, "key")
  end

  test "clear without fallback", %{ets_state: ets_state} do
    Cachetastic.put("key1", "value1")
    Cachetastic.put("key2", "value2")
    assert :ok == Cachetastic.clear()
    assert :error == ETS.get(ets_state, "key1")
    assert :error == ETS.get(ets_state, "key2")
  end
end
