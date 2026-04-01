defmodule Cachetastic.FaultToleranceTest do
  use ExUnit.Case
  use Patch

  alias Cachetastic.Backend.ETS

  setup do
    Application.put_env(:cachetastic, :backends,
      primary: :redis,
      redis: [host: "localhost", port: 6379],
      ets: [],
      fault_tolerance: [primary: :redis, backup: :ets]
    )

    Cachetastic.ensure_backends_started()

    :ok
  end

  test "put falls back to ETS on Redis failure" do
    patch(Redix, :command, fn _, _ -> {:error, "connection refused"} end)

    assert :ok == Cachetastic.put("key", "value")
  end

  test "get falls back to ETS on Redis failure" do
    ets_server = backend_server(:ets)
    ETS.put(ets_server, "key", "value")

    patch(Redix, :command, fn _, _ -> {:error, "connection refused"} end)

    assert {:ok, "value"} == Cachetastic.get("key")
  end

  test "delete falls back to ETS on Redis failure" do
    ets_server = backend_server(:ets)
    ETS.put(ets_server, "key", "value")

    patch(Redix, :command, fn _, _ -> {:error, "connection refused"} end)

    assert :ok == Cachetastic.delete("key")
    assert {:error, :not_found} == ETS.get(ets_server, "key")
  end

  test "clear falls back to ETS on Redis failure" do
    ets_server = backend_server(:ets)
    ETS.put(ets_server, "key1", "value1")
    ETS.put(ets_server, "key2", "value2")

    patch(Redix, :command, fn _, _ -> {:error, "connection refused"} end)

    assert :ok == Cachetastic.clear()
    assert {:error, :not_found} == ETS.get(ets_server, "key1")
    assert {:error, :not_found} == ETS.get(ets_server, "key2")
  end

  test "does not retry on :not_found" do
    call_count = :counters.new(1, [:atomics])

    result =
      Cachetastic.FaultTolerance.with_retries(fn ->
        :counters.add(call_count, 1, 1)
        {:error, :not_found}
      end)

    assert result == {:error, :not_found}
    assert :counters.get(call_count, 1) == 1
  end

  test "does not fall back on :not_found" do
    backup_called = :counters.new(1, [:atomics])

    result =
      Cachetastic.FaultTolerance.with_fallback(
        fn -> {:error, :not_found} end,
        fn ->
          :counters.add(backup_called, 1, 1)
          {:ok, "backup_value"}
        end
      )

    assert result == {:error, :not_found}
    assert :counters.get(backup_called, 1) == 0
  end

  test "retries configurable number of times" do
    call_count = :counters.new(1, [:atomics])

    result =
      Cachetastic.FaultTolerance.with_retries(
        fn ->
          :counters.add(call_count, 1, 1)
          {:error, :fail}
        end,
        retry_attempts: 2,
        retry_delay: 10
      )

    assert result == {:error, :operation_failed}
    assert :counters.get(call_count, 1) == 2
  end

  defp backend_server(backend) do
    {:via, Registry, {Cachetastic.Registry, {Cachetastic.Config, backend, :default}}}
  end
end
