defmodule Cachetastic.PubSub.PG do
  @moduledoc """
  Distributed cache invalidation using Erlang `:pg` process groups.

  Works in any BEAM cluster without external dependencies. Nodes must be
  connected via `Node.connect/1` or libcluster.

  ## Events

  Broadcasts `{:cachetastic_invalidate, action, key_or_nil, cache_name}` to all
  members of the `:cachetastic_pubsub` group.
  """

  use GenServer
  @behaviour Cachetastic.PubSub

  @group :cachetastic_pubsub

  @impl Cachetastic.PubSub
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl Cachetastic.PubSub
  def broadcast(event) do
    members = :pg.get_members(@group) -- [self()]

    for pid <- members do
      send(pid, {:cachetastic_invalidate, event})
    end

    :ok
  end

  # --- GenServer ---

  @impl true
  def init(_opts) do
    :pg.start_link()
    :pg.join(@group, self())
    {:ok, %{}}
  end

  @impl true
  def handle_info({:cachetastic_invalidate, {:delete, cache_name, key}}, state) do
    # Invalidate only the local ETS (L1) cache
    try do
      Cachetastic.delete(cache_name, key)
    rescue
      _ -> :ok
    end

    {:noreply, state}
  end

  def handle_info({:cachetastic_invalidate, {:clear, cache_name}}, state) do
    try do
      Cachetastic.clear(cache_name)
    rescue
      _ -> :ok
    end

    {:noreply, state}
  end

  def handle_info(_msg, state), do: {:noreply, state}
end
