defmodule Cachetastic.Lock do
  @moduledoc """
  Per-key lock server for thundering herd protection.

  When multiple processes call `fetch` for the same missing key simultaneously,
  only one computes the fallback. The rest wait for the result.
  """

  use GenServer

  @timeout 30_000

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Executes `fun` under a per-key lock. If another process is already computing
  for the same key, this call waits for the result instead of running `fun` again.

  ## Options

    * `:timeout` - Max time to wait for a lock in ms (default: 30_000)
  """
  def run(key, fun, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, @timeout)
    GenServer.call(__MODULE__, {:acquire, key, fun}, timeout)
  end

  # --- GenServer ---

  @impl true
  def init(_opts) do
    {:ok, %{locks: %{}, waiters: %{}}}
  end

  @impl true
  def handle_call({:acquire, key, fun}, from, state) do
    case Map.get(state.locks, key) do
      nil ->
        # No one is computing this key — we win the lock
        state = put_in(state.locks[key], from)
        state = put_in(state.waiters[key], [])

        # Run the computation asynchronously to avoid blocking the GenServer
        self_pid = self()

        Task.start(fn ->
          result =
            try do
              {:ok, fun.()}
            rescue
              e -> {:error, e}
            end

          GenServer.cast(self_pid, {:completed, key, result})
        end)

        {:noreply, state}

      _owner ->
        # Someone else is computing — add ourselves as a waiter
        waiters = Map.get(state.waiters, key, [])
        state = put_in(state.waiters[key], [from | waiters])
        {:noreply, state}
    end
  end

  @impl true
  def handle_cast({:completed, key, result}, state) do
    # Reply to the owner
    case Map.get(state.locks, key) do
      nil -> :ok
      owner -> GenServer.reply(owner, result)
    end

    # Reply to all waiters
    waiters = Map.get(state.waiters, key, [])

    for waiter <- waiters do
      GenServer.reply(waiter, result)
    end

    state = %{state | locks: Map.delete(state.locks, key), waiters: Map.delete(state.waiters, key)}
    {:noreply, state}
  end
end
