defmodule Cachetastic.PubSub do
  @moduledoc """
  Behaviour for distributed cache invalidation.

  When a node invalidates cache entries, it can broadcast the event so that
  other nodes invalidate their local (L1) caches.

  ## Built-in adapters

    * `Cachetastic.PubSub.PG` — uses Erlang `:pg` process groups (no external deps)
    * `Cachetastic.PubSub.RedisPubSub` — uses Redis Pub/Sub via Redix

  ## Configuration

      config :cachetastic, pubsub: [adapter: Cachetastic.PubSub.PG]
  """

  @callback start_link(keyword()) :: GenServer.on_start()
  @callback broadcast(event :: term()) :: :ok
end
