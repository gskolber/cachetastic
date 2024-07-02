defmodule Cachetastic.Backend.ETSTest do
  use ExUnit.Case

  alias Cachetastic.Backend.ETS

  setup do
    {:ok, state} = ETS.start_link(table_name: :test_cache, ttl: 600)
    %{state: state}
  end

  test "put and get value", %{state: state} do
    assert :ok == ETS.put(state, "test_key", "test_value")
    assert {:ok, "test_value"} == ETS.get(state, "test_key")
  end

  test "get non-existing value returns {:error, :not_found}", %{state: state} do
    assert {:error, :not_found} == ETS.get(state, "non_existing_key")
  end

  test "delete value", %{state: state} do
    ETS.put(state, "test_key", "test_value")
    assert :ok == ETS.delete(state, "test_key")
    assert {:error, :not_found} == ETS.get(state, "test_key")
  end

  test "clear cache", %{state: state} do
    ETS.put(state, "key1", "value1")
    ETS.put(state, "key2", "value2")
    assert :ok == ETS.clear(state)
    assert {:error, :not_found} == ETS.get(state, "key1")
    assert {:error, :not_found} == ETS.get(state, "key2")
  end
end
