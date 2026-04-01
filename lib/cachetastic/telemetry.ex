defmodule Cachetastic.Telemetry do
  @moduledoc """
  Telemetry integration for Cachetastic.

  Emits the following events:

    * `[:cachetastic, :cache, :get]` — on cache get
      * Measurements: `%{duration: integer}` (native time units)
      * Metadata: `%{key: key, result: :hit | :miss | :error, cache: name, backend: backend}`

    * `[:cachetastic, :cache, :put]` — on cache put
      * Measurements: `%{duration: integer}`
      * Metadata: `%{key: key, cache: name, backend: backend}`

    * `[:cachetastic, :cache, :delete]` — on cache delete
      * Measurements: `%{duration: integer}`
      * Metadata: `%{key: key, cache: name, backend: backend}`

    * `[:cachetastic, :cache, :clear]` — on cache clear
      * Measurements: `%{duration: integer}`
      * Metadata: `%{cache: name, backend: backend}`

    * `[:cachetastic, :cache, :fallback]` — when fallback is triggered
      * Measurements: `%{}`
      * Metadata: `%{cache: name, from: primary, to: backup}`

    * `[:cachetastic, :cache, :fetch]` — on fetch with fallback function
      * Measurements: `%{duration: integer}`
      * Metadata: `%{key: key, cache: name, result: :hit | :miss}`
  """

  @doc """
  Executes a function and emits telemetry with duration.
  """
  def span(event, metadata, fun) do
    start_time = System.monotonic_time()

    result = fun.()

    duration = System.monotonic_time() - start_time
    :telemetry.execute(event, %{duration: duration}, metadata)

    result
  end

  @doc """
  Emits a telemetry event without duration measurement.
  """
  def emit(event, measurements \\ %{}, metadata) do
    :telemetry.execute(event, measurements, metadata)
  end
end
