defmodule Cachetastic.StatsTest do
  use ExUnit.Case

  setup do
    Application.put_env(:cachetastic, :backends,
      primary: :ets,
      ets: [],
      fault_tolerance: [primary: :ets]
    )

    Cachetastic.ensure_backends_started()
    Cachetastic.Stats.reset()

    :ok
  end

  test "tracks puts" do
    Cachetastic.put("key1", "value1")
    Cachetastic.put("key2", "value2")

    # Give stats time to process telemetry messages
    Process.sleep(50)

    stats = Cachetastic.Stats.get()
    assert stats.puts == 2
  end

  test "tracks hits and misses" do
    Cachetastic.put("key", "value")
    Cachetastic.get("key")
    Cachetastic.get("nonexistent")

    Process.sleep(50)

    stats = Cachetastic.Stats.get()
    assert stats.hits == 1
    assert stats.misses == 1
    assert stats.hit_rate == 0.5
  end

  test "tracks deletes" do
    Cachetastic.put("key", "value")
    Cachetastic.delete("key")

    Process.sleep(50)

    stats = Cachetastic.Stats.get()
    assert stats.deletes == 1
  end

  test "tracks clears" do
    Cachetastic.clear()

    Process.sleep(50)

    stats = Cachetastic.Stats.get()
    assert stats.clears == 1
  end

  test "reset clears all stats" do
    Cachetastic.put("key", "value")
    Process.sleep(50)

    Cachetastic.Stats.reset()
    stats = Cachetastic.Stats.get()
    assert stats.puts == 0
  end

  test "tracks stats per named cache" do
    Cachetastic.put(:sessions, "key", "value", nil)
    Cachetastic.put("key", "value")

    Process.sleep(50)

    default_stats = Cachetastic.Stats.get(:default)
    session_stats = Cachetastic.Stats.get(:sessions)

    assert default_stats.puts == 1
    assert session_stats.puts == 1
  end
end
