defmodule Cachetastic.Backend.ETSTest do
  use ExUnit.Case

  alias Cachetastic.Backend.ETS

  setup do
    # Start a fresh ETS GenServer for each test
    {:ok, pid} = ETS.start_link(table_name: :test_cache, ttl: 600, sweep_interval: 60_000)
    %{pid: pid}
  end

  test "put and get value", %{pid: pid} do
    assert :ok == ETS.put(pid, "test_key", "test_value")
    assert {:ok, "test_value"} == ETS.get(pid, "test_key")
  end

  test "get non-existing value returns {:error, :not_found}", %{pid: pid} do
    assert {:error, :not_found} == ETS.get(pid, "non_existing_key")
  end

  test "delete value", %{pid: pid} do
    ETS.put(pid, "test_key", "test_value")
    assert :ok == ETS.delete(pid, "test_key")
    assert {:error, :not_found} == ETS.get(pid, "test_key")
  end

  test "clear cache", %{pid: pid} do
    ETS.put(pid, "key1", "value1")
    ETS.put(pid, "key2", "value2")
    assert :ok == ETS.clear(pid)
    assert {:error, :not_found} == ETS.get(pid, "key1")
    assert {:error, :not_found} == ETS.get(pid, "key2")
  end

  test "entries expire after TTL", %{pid: _pid} do
    # Start a separate ETS with a very short TTL
    {:ok, short_ttl_pid} = ETS.start_link(table_name: :ttl_test, ttl: 1, sweep_interval: 60_000)

    ETS.put(short_ttl_pid, "expiring_key", "value")
    assert {:ok, "value"} == ETS.get(short_ttl_pid, "expiring_key")

    # Wait for TTL to expire
    Process.sleep(1100)

    assert {:error, :not_found} == ETS.get(short_ttl_pid, "expiring_key")
  end

  test "per-entry TTL override", %{pid: pid} do
    # Put with a 1-second TTL override (default is 600)
    ETS.put(pid, "short_ttl_key", "value", 1)
    assert {:ok, "value"} == ETS.get(pid, "short_ttl_key")

    Process.sleep(1100)

    assert {:error, :not_found} == ETS.get(pid, "short_ttl_key")
  end
end
