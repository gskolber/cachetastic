defmodule Cachetastic.TelemetryTest do
  use ExUnit.Case

  setup do
    Application.put_env(:cachetastic, :backends,
      primary: :ets,
      ets: [],
      fault_tolerance: [primary: :ets]
    )

    Cachetastic.ensure_backends_started()

    test_pid = self()

    :telemetry.attach_many(
      "test-telemetry-#{inspect(self())}",
      [
        [:cachetastic, :cache, :put],
        [:cachetastic, :cache, :get],
        [:cachetastic, :cache, :delete],
        [:cachetastic, :cache, :clear],
        [:cachetastic, :cache, :get, :result],
        [:cachetastic, :cache, :fetch],
        [:cachetastic, :cache, :fetch, :result]
      ],
      fn event, measurements, metadata, _config ->
        send(test_pid, {:telemetry, event, measurements, metadata})
      end,
      nil
    )

    on_exit(fn ->
      :telemetry.detach("test-telemetry-#{inspect(test_pid)}")
    end)

    :ok
  end

  test "emits put telemetry event" do
    Cachetastic.put("tel_key", "value")

    assert_receive {:telemetry, [:cachetastic, :cache, :put], %{duration: _}, %{key: "tel_key"}}
  end

  test "emits get telemetry events" do
    Cachetastic.put("tel_key", "value")
    Cachetastic.get("tel_key")

    assert_receive {:telemetry, [:cachetastic, :cache, :get], %{duration: _}, %{key: "tel_key"}}
    assert_receive {:telemetry, [:cachetastic, :cache, :get, :result], _, %{result: :hit}}
  end

  test "emits miss on get for non-existing key" do
    Cachetastic.get("nonexistent")

    assert_receive {:telemetry, [:cachetastic, :cache, :get, :result], _, %{result: :miss}}
  end

  test "emits delete telemetry event" do
    Cachetastic.put("tel_key", "value")
    Cachetastic.delete("tel_key")

    assert_receive {:telemetry, [:cachetastic, :cache, :delete], %{duration: _}, %{key: "tel_key"}}
  end

  test "emits clear telemetry event" do
    Cachetastic.clear()

    assert_receive {:telemetry, [:cachetastic, :cache, :clear], %{duration: _}, %{cache: :default}}
  end

  test "emits fetch telemetry with miss on first call" do
    Cachetastic.fetch("fetch_key", fn -> "computed" end)

    assert_receive {:telemetry, [:cachetastic, :cache, :fetch], %{duration: _}, %{key: "fetch_key"}}
    assert_receive {:telemetry, [:cachetastic, :cache, :fetch, :result], _, %{result: :miss}}
  end

  test "emits fetch telemetry with hit on second call" do
    Cachetastic.fetch("fetch_key2", fn -> "computed" end)
    Cachetastic.fetch("fetch_key2", fn -> "should not be called" end)

    # We should receive two fetch events - first miss, then hit
    assert_receive {:telemetry, [:cachetastic, :cache, :fetch, :result], _, %{result: :miss, key: "fetch_key2"}}
    assert_receive {:telemetry, [:cachetastic, :cache, :fetch, :result], _, %{result: :hit, key: "fetch_key2"}}
  end
end
