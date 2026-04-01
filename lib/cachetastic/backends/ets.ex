defmodule Cachetastic.Backend.ETS do
  @moduledoc """
  ETS backend for Cachetastic.

  A GenServer that owns an ETS table and provides cache operations with
  TTL support (both lazy expiration on reads and active sweep).

  ## Options

    * `:table_name` - The name of the ETS table (default: `:cachetastic`)
    * `:ttl` - Default time-to-live in seconds (default: 600)
    * `:sweep_interval` - Interval in ms for active expiration sweep (default: 60_000)
    * `:name` - GenServer name registration (optional)
  """

  use GenServer
  @behaviour Cachetastic.Behaviour

  @default_ttl 600
  @default_sweep_interval 60_000

  # --- Public API ---

  @impl Cachetastic.Behaviour
  def start_link(opts) do
    {name, opts} = Keyword.pop(opts, :name)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @impl Cachetastic.Behaviour
  def put(server, key, value, ttl \\ nil) do
    GenServer.call(server, {:put, key, value, ttl})
  end

  @impl Cachetastic.Behaviour
  def get(server, key) do
    GenServer.call(server, {:get, key})
  end

  @impl Cachetastic.Behaviour
  def delete(server, key) do
    GenServer.call(server, {:delete, key})
  end

  @impl Cachetastic.Behaviour
  def clear(server) do
    GenServer.call(server, :clear)
  end

  # --- GenServer callbacks ---

  @impl GenServer
  def init(opts) do
    table_name = Keyword.get(opts, :table_name, :cachetastic)
    ttl = Keyword.get(opts, :ttl, @default_ttl)
    sweep_interval = Keyword.get(opts, :sweep_interval, @default_sweep_interval)

    table = :ets.new(table_name, [:set, :private])
    schedule_sweep(sweep_interval)

    {:ok, %{table: table, ttl: ttl, sweep_interval: sweep_interval}}
  end

  @impl GenServer
  def handle_call({:put, key, value, ttl}, _from, state) do
    entry_ttl = ttl || state.ttl
    expires_at = System.monotonic_time(:second) + entry_ttl
    :ets.insert(state.table, {key, value, expires_at})
    {:reply, :ok, state}
  end

  def handle_call({:get, key}, _from, state) do
    result =
      case :ets.lookup(state.table, key) do
        [{^key, value, expires_at}] ->
          if System.monotonic_time(:second) < expires_at do
            {:ok, value}
          else
            :ets.delete(state.table, key)
            {:error, :not_found}
          end

        _ ->
          {:error, :not_found}
      end

    {:reply, result, state}
  end

  def handle_call({:delete, key}, _from, state) do
    :ets.delete(state.table, key)
    {:reply, :ok, state}
  end

  def handle_call(:clear, _from, state) do
    :ets.delete_all_objects(state.table)
    {:reply, :ok, state}
  end

  @impl GenServer
  def handle_info(:sweep, state) do
    now = System.monotonic_time(:second)
    :ets.select_delete(state.table, [{{:_, :_, :"$1"}, [{:<, :"$1", now}], [true]}])
    schedule_sweep(state.sweep_interval)
    {:noreply, state}
  end

  defp schedule_sweep(interval) do
    Process.send_after(self(), :sweep, interval)
  end
end
