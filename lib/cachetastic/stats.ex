defmodule Cachetastic.Stats do
  @moduledoc """
  Tracks cache statistics by attaching to Cachetastic telemetry events.

  Started automatically as part of the Cachetastic supervision tree.

  ## Usage

      Cachetastic.Stats.get()
      # => %{hits: 42, misses: 5, puts: 20, deletes: 3, clears: 1, errors: 0}

      Cachetastic.Stats.get(:sessions)
      # => %{hits: 10, misses: 2, ...}

      Cachetastic.Stats.reset()
  """

  use GenServer

  @counters [:hits, :misses, :puts, :deletes, :clears, :errors, :fallbacks]

  # --- Public API ---

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Returns stats for the given cache (defaults to `:default`).
  """
  def get(cache_name \\ :default) do
    GenServer.call(__MODULE__, {:get, cache_name})
  end

  @doc """
  Resets all stats.
  """
  def reset do
    GenServer.call(__MODULE__, :reset)
  end

  # --- GenServer callbacks ---

  @impl true
  def init(_opts) do
    attach_telemetry()
    {:ok, %{}}
  end

  @impl true
  def handle_call({:get, cache_name}, _from, state) do
    stats = Map.get(state, cache_name, default_stats())
    total = stats.hits + stats.misses
    hit_rate = if total > 0, do: Float.round(stats.hits / total, 3), else: 0.0

    {:reply, Map.put(stats, :hit_rate, hit_rate), state}
  end

  def handle_call(:reset, _from, _state) do
    {:reply, :ok, %{}}
  end

  @impl true
  def handle_info({:telemetry_event, event, metadata}, state) do
    state = handle_event(event, metadata, state)
    {:noreply, state}
  end

  # --- Telemetry handlers ---

  defp attach_telemetry do
    pid = self()

    :telemetry.attach_many(
      "cachetastic-stats",
      [
        [:cachetastic, :cache, :put],
        [:cachetastic, :cache, :delete],
        [:cachetastic, :cache, :clear],
        [:cachetastic, :cache, :get, :result],
        [:cachetastic, :cache, :fallback]
      ],
      fn event, _measurements, metadata, _config ->
        send(pid, {:telemetry_event, event, metadata})
      end,
      nil
    )
  end

  defp handle_event([:cachetastic, :cache, :put], metadata, state) do
    increment(state, metadata[:cache] || :default, :puts)
  end

  defp handle_event([:cachetastic, :cache, :delete], metadata, state) do
    increment(state, metadata[:cache] || :default, :deletes)
  end

  defp handle_event([:cachetastic, :cache, :clear], metadata, state) do
    increment(state, metadata[:cache] || :default, :clears)
  end

  defp handle_event([:cachetastic, :cache, :get, :result], metadata, state) do
    case metadata[:result] do
      :hit -> increment(state, metadata[:cache] || :default, :hits)
      :miss -> increment(state, metadata[:cache] || :default, :misses)
      :error -> increment(state, metadata[:cache] || :default, :errors)
      _ -> state
    end
  end

  defp handle_event([:cachetastic, :cache, :fallback], metadata, state) do
    increment(state, metadata[:cache] || :default, :fallbacks)
  end

  defp handle_event(_event, _metadata, state), do: state

  defp increment(state, cache_name, counter) do
    stats = Map.get(state, cache_name, default_stats())
    stats = Map.update!(stats, counter, &(&1 + 1))
    Map.put(state, cache_name, stats)
  end

  defp default_stats do
    Map.new(@counters, fn c -> {c, 0} end)
  end
end
