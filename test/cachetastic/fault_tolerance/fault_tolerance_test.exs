defmodule Cachetastic.FaultToleranceTest do
  use ExUnit.Case
  use Patch

  alias Cachetastic.Backend.{ETS, Redis}

  setup do
    # Configuração inicial para tolerância a falhas
    Application.put_env(:cachetastic, :fault_tolerance, primary: :redis, backup: :ets)

    {:ok, ets_pid} = ETS.start_link([])
    {:ok, ets_pid: ets_pid}
  end

  test "put falls back to ETS on Redis failure", %{ets_pid: ets_pid} do
    patch(Redis, :put, fn _, _, _, _ -> {:error, "primary failure"} end)

    assert :ok == Cachetastic.put("key", "value")
    assert {:ok, "value"} == ETS.get(ets_pid, "key")
  end

  test "get falls back to ETS on Redis failure", %{ets_pid: ets_pid} do
    patch(Redis, :get, fn _, _ -> {:error, "primary failure"} end)

    ETS.put(ets_pid, "key", "value")
    assert {:ok, "value"} == Cachetastic.get("key")
  end

  test "delete falls back to ETS on Redis failure", %{ets_pid: ets_pid} do
    patch(Redis, :delete, fn _, _ -> {:error, "primary failure"} end)

    ETS.put(ets_pid, "key", "value")
    assert :ok == Cachetastic.delete("key")
    assert {:error, :not_found} == ETS.get(ets_pid, "key")
  end

  test "clear falls back to ETS on Redis failure", %{ets_pid: ets_pid} do
    patch(Redis, :clear, fn _ -> {:error, "primary failure"} end)

    ETS.put(ets_pid, "key1", "value1")
    ETS.put(ets_pid, "key2", "value2")
    assert :ok == Cachetastic.clear()
    assert {:error, :not_found} == ETS.get(ets_pid, "key1")
    assert {:error, :not_found} == ETS.get(ets_pid, "key2")
  end
end
