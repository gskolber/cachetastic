defmodule Cachetastic.Backend.MultiLayer do
  @moduledoc """
  Multi-layer cache backend (L1 local + L2 remote).

  Uses a local ETS cache as L1 for fast reads and a remote backend (e.g. Redis)
  as L2 for persistence and cross-node consistency.

  ## Strategy

    * `get` — check L1, on miss check L2 and populate L1
    * `put` — write to L2 (source of truth) then L1
    * `delete` / `clear` — remove from both layers

  ## Options

    * `:l1` - Keyword options for the L1 backend (ETS). Default: `[ttl: 60]`
    * `:l2` - Keyword options for the L2 backend (Redis). Must include `:host` and `:port`
    * `:name` - GenServer name registration (optional)
  """

  use GenServer

  alias Cachetastic.Backend.{ETS, Redis}

  def start_link(opts) do
    {name, opts} = Keyword.pop(opts, :name)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  def put(server, key, value, ttl \\ nil) do
    GenServer.call(server, {:put, key, value, ttl})
  end

  def get(server, key) do
    GenServer.call(server, {:get, key})
  end

  def delete(server, key) do
    GenServer.call(server, {:delete, key})
  end

  def clear(server) do
    GenServer.call(server, :clear)
  end

  # --- GenServer ---

  @impl true
  def init(opts) do
    l1_opts = Keyword.get(opts, :l1, [ttl: 60])
    l2_opts = Keyword.get(opts, :l2, [])

    {:ok, l1} = ETS.start_link(l1_opts)
    {:ok, l2} = Redis.start_link(l2_opts)

    {:ok, %{l1: l1, l2: l2}}
  end

  @impl true
  def handle_call({:put, key, value, ttl}, _from, %{l1: l1, l2: l2} = state) do
    # Write to L2 first (source of truth), then L1
    result = Redis.put(l2, key, value, ttl)

    if result == :ok do
      ETS.put(l1, key, value, ttl)
    end

    {:reply, result, state}
  end

  def handle_call({:get, key}, _from, %{l1: l1, l2: l2} = state) do
    result =
      case ETS.get(l1, key) do
        {:ok, _value} = hit ->
          hit

        {:error, :not_found} ->
          # L1 miss, check L2
          case Redis.get(l2, key) do
            {:ok, value} = hit ->
              # Populate L1
              ETS.put(l1, key, value)
              hit

            other ->
              other
          end
      end

    {:reply, result, state}
  end

  def handle_call({:delete, key}, _from, %{l1: l1, l2: l2} = state) do
    ETS.delete(l1, key)
    result = Redis.delete(l2, key)
    {:reply, result, state}
  end

  def handle_call(:clear, _from, %{l1: l1, l2: l2} = state) do
    ETS.clear(l1)
    result = Redis.clear(l2)
    {:reply, result, state}
  end
end
