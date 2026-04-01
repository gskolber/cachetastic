defmodule Cachetastic.PubSub.RedisPubSub do
  @moduledoc """
  Distributed cache invalidation using Redis Pub/Sub.

  Useful for deployments where nodes are not connected via BEAM distribution
  but share a Redis instance.

  ## Configuration

      config :cachetastic, pubsub: [
        adapter: Cachetastic.PubSub.RedisPubSub,
        redis: [host: "localhost", port: 6379]
      ]

  ## Events

  Publishes JSON-encoded invalidation messages to the `cachetastic:invalidate` channel.
  """

  use GenServer
  @behaviour Cachetastic.PubSub

  @channel "cachetastic:invalidate"

  @impl Cachetastic.PubSub
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl Cachetastic.PubSub
  def broadcast(event) do
    GenServer.cast(__MODULE__, {:broadcast, event})
  end

  # --- GenServer ---

  @impl true
  def init(opts) do
    redis_opts = Keyword.get(opts, :redis, [host: "localhost", port: 6379])
    host = Keyword.get(redis_opts, :host, "localhost")
    port = Keyword.get(redis_opts, :port, 6379)

    # Publisher connection
    {:ok, pub_conn} = Redix.start_link(host: host, port: port)

    # Subscriber connection
    {:ok, sub_conn} = Redix.PubSub.start_link(host: host, port: port)
    {:ok, _ref} = Redix.PubSub.subscribe(sub_conn, @channel, self())

    {:ok, %{pub_conn: pub_conn, sub_conn: sub_conn, node_id: generate_node_id()}}
  end

  @impl true
  def handle_cast({:broadcast, event}, state) do
    message = Jason.encode!(%{event: serialize_event(event), node_id: state.node_id})
    Redix.command(state.pub_conn, ["PUBLISH", @channel, message])
    {:noreply, state}
  end

  @impl true
  def handle_info({:redix_pubsub, _sub_conn, _ref, :message, %{payload: payload}}, state) do
    case Jason.decode(payload) do
      {:ok, %{"event" => event, "node_id" => node_id}} when node_id != state.node_id ->
        handle_remote_event(event)

      _ ->
        :ok
    end

    {:noreply, state}
  end

  def handle_info({:redix_pubsub, _sub_conn, _ref, :subscribed, _}, state) do
    {:noreply, state}
  end

  def handle_info(_msg, state), do: {:noreply, state}

  # --- Private ---

  defp handle_remote_event(%{"action" => "delete", "cache" => cache, "key" => key}) do
    cache_atom = String.to_existing_atom(cache)

    try do
      Cachetastic.delete(cache_atom, key)
    rescue
      _ -> :ok
    end
  end

  defp handle_remote_event(%{"action" => "clear", "cache" => cache}) do
    cache_atom = String.to_existing_atom(cache)

    try do
      Cachetastic.clear(cache_atom)
    rescue
      _ -> :ok
    end
  end

  defp handle_remote_event(_), do: :ok

  defp serialize_event({:delete, cache_name, key}) do
    %{"action" => "delete", "cache" => Atom.to_string(cache_name), "key" => key}
  end

  defp serialize_event({:clear, cache_name}) do
    %{"action" => "clear", "cache" => Atom.to_string(cache_name)}
  end

  defp generate_node_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end
end
