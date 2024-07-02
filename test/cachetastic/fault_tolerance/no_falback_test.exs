defmodule Cachetastic.FaultTolerance.NoFallbackTest do
  use ExUnit.Case

  setup do
    # Configuração inicial sem tolerância a falhas, utilizando ETS como backend primário
    Application.put_env(:cachetastic, :fault_tolerance, primary: :ets)

    {:ok, _pid} = Cachetastic.start_link()
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
