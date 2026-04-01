defmodule Cachetastic.FetchTest do
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

  test "fetch computes value on cache miss" do
    assert {:ok, "computed"} =
             Cachetastic.fetch("fetch_miss", fn -> "computed" end)
  end

  test "fetch returns cached value on hit" do
    Cachetastic.put("fetch_hit", "cached_value")

    call_count = :counters.new(1, [:atomics])

    assert {:ok, "cached_value"} =
             Cachetastic.fetch("fetch_hit", fn ->
               :counters.add(call_count, 1, 1)
               "should_not_be_used"
             end)

    assert :counters.get(call_count, 1) == 0
  end

  test "fetch caches the computed value" do
    Cachetastic.fetch("fetch_cache", fn -> "first_compute" end)

    # Value should now be cached
    assert {:ok, "first_compute"} = Cachetastic.get("fetch_cache")
  end

  test "fetch with custom TTL" do
    Cachetastic.fetch("fetch_ttl", fn -> "value" end, ttl: 1)

    assert {:ok, "value"} = Cachetastic.get("fetch_ttl")

    Process.sleep(1100)

    assert {:error, :not_found} = Cachetastic.get("fetch_ttl")
  end

  test "fetch with named cache" do
    assert {:ok, "session_data"} =
             Cachetastic.fetch(:sessions, "user:1", fn -> "session_data" end)

    assert {:ok, "session_data"} = Cachetastic.get(:sessions, "user:1")

    # Should not exist in default cache
    assert {:error, :not_found} = Cachetastic.get("user:1")
  end
end
