defmodule Cachetastic.LockTest do
  use ExUnit.Case

  test "only one process computes for the same key" do
    computation_count = :counters.new(1, [:atomics])

    tasks =
      for _i <- 1..10 do
        Task.async(fn ->
          Cachetastic.Lock.run("herd_key", fn ->
            :counters.add(computation_count, 1, 1)
            Process.sleep(100)
            "computed_value"
          end)
        end)
      end

    results = Task.await_many(tasks, 5000)

    # All should get the same result
    assert Enum.all?(results, &match?({:ok, "computed_value"}, &1))

    # But the computation should only have run once
    assert :counters.get(computation_count, 1) == 1
  end

  test "different keys compute independently" do
    computation_count = :counters.new(1, [:atomics])

    tasks =
      for i <- 1..5 do
        Task.async(fn ->
          Cachetastic.Lock.run("independent_#{i}", fn ->
            :counters.add(computation_count, 1, 1)
            "value_#{i}"
          end)
        end)
      end

    Task.await_many(tasks, 5000)

    # Each key should compute once
    assert :counters.get(computation_count, 1) == 5
  end

  test "errors are propagated to all waiters" do
    tasks =
      for _i <- 1..5 do
        Task.async(fn ->
          Cachetastic.Lock.run("error_key", fn ->
            Process.sleep(50)
            raise "boom"
          end)
        end)
      end

    results = Task.await_many(tasks, 5000)
    assert Enum.all?(results, &match?({:error, %RuntimeError{message: "boom"}}, &1))
  end
end
