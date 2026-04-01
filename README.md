# Cachetastic

## Overview

**Cachetastic** is a powerful and user-friendly caching library for Elixir. It provides a unified interface for various caching mechanisms like ETS and Redis, with built-in fault tolerance, telemetry, and more.

## Features

- **Unified Interface**: Interact with different caching backends through a consistent API.
- **OTP Supervision**: Backends run as supervised processes — no connection leaks.
- **Redis Connection Pool**: Pooled Redis connections via NimblePool for high concurrency.
- **Fault Tolerance**: Automatic retries and fallback to a backup backend.
- **ETS TTL**: Entries expire via lazy checks and periodic sweeps.
- **Named Caches**: Run multiple isolated cache instances side by side.
- **Fetch with Thundering Herd Protection**: Compute and cache on miss — only one process computes per key.
- **Key Namespacing**: Automatic key prefixes to avoid collisions in shared Redis instances.
- **Pattern-Based Invalidation**: Delete groups of keys by pattern (e.g. `"user:*"`).
- **Telemetry**: Built-in events for all cache operations.
- **Stats**: Track hits, misses, hit rate, and more.
- **Configurable Serialization**: Pluggable serializers (JSON, Erlang term, or custom).
- **Multi-Layer Caching**: L1 (ETS) + L2 (Redis) for fast local reads with remote persistence.
- **Distributed Invalidation**: Pub/sub via Erlang `:pg` or Redis Pub/Sub for cross-node cache invalidation.
- **Ecto Integration**: Cache and retrieve Ecto query results seamlessly.

## Installation

Add `cachetastic` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:cachetastic, "~> 1.0"}
  ]
end
```

Run `mix deps.get` to fetch the dependencies.

## Usage

### Configuration

Define the backends and fault tolerance configuration in `config/config.exs`:

```elixir
import Config

# Use the pooled Redis backend for production workloads
config :cachetastic, :backends,
  primary: :redis_pool,
  redis_pool: [host: "localhost", port: 6379, pool_size: 10, ttl: 3600],
  ets: [ttl: 600],
  fault_tolerance: [primary: :redis_pool, backup: :ets]

# Optional: prefix all keys (useful when sharing a Redis instance)
config :cachetastic, key_prefix: "myapp"
```

Cachetastic starts automatically as an OTP application — no manual setup needed.

### Basic Operations

```elixir
# Put a value in the cache
Cachetastic.put("key", "value")

# Put with a custom TTL (in seconds)
Cachetastic.put("key", "value", 120)

# Get a value
{:ok, value} = Cachetastic.get("key")

# Delete a value
Cachetastic.delete("key")

# Clear the entire cache
Cachetastic.clear()
```

### Fetch with Fallback

Compute and cache a value on miss. Includes thundering herd protection — only one
process computes the fallback for a given key, concurrent callers wait for the result:

```elixir
{:ok, users} = Cachetastic.fetch("active_users", fn ->
  Repo.all(from u in User, where: u.active == true)
end)

# With custom TTL
{:ok, data} = Cachetastic.fetch("expensive_query", fn ->
  compute_expensive_data()
end, ttl: 300)
```

### Named Caches

Run multiple isolated caches:

```elixir
Cachetastic.put(:sessions, "user:123", session_data, 1800)
{:ok, session} = Cachetastic.get(:sessions, "user:123")

Cachetastic.put(:api_cache, "endpoint:/users", response, 60)
{:ok, cached} = Cachetastic.get(:api_cache, "endpoint:/users")

# Each cache is independent
Cachetastic.clear(:sessions)  # does not affect :api_cache
```

### Pattern-Based Invalidation

Delete groups of keys by pattern (requires Redis/RedisPool backend):

```elixir
# Delete all user-related cache entries
Cachetastic.delete_pattern("user:*")

# Scoped to a named cache
Cachetastic.delete_pattern(:api_cache, "v1:*")
```

### Key Namespacing

Avoid key collisions when sharing a Redis instance between multiple apps:

```elixir
config :cachetastic, key_prefix: "myapp"

# All keys are automatically prefixed: "myapp:user:123"
Cachetastic.put("user:123", data)
```

### Telemetry Events

Cachetastic emits telemetry events for all operations:

```elixir
:telemetry.attach("my-handler", [:cachetastic, :cache, :get], fn event, measurements, metadata, _config ->
  Logger.info("Cache #{metadata.result}: #{metadata.key} (#{measurements.duration}ns)")
end, nil)
```

Events emitted:
- `[:cachetastic, :cache, :get]` — with `%{duration: ns}`
- `[:cachetastic, :cache, :get, :result]` — with `%{result: :hit | :miss | :error}`
- `[:cachetastic, :cache, :put]`
- `[:cachetastic, :cache, :delete]`
- `[:cachetastic, :cache, :delete_pattern]`
- `[:cachetastic, :cache, :clear]`
- `[:cachetastic, :cache, :fetch]`
- `[:cachetastic, :cache, :fallback]`

### Stats

```elixir
Cachetastic.Stats.get()
# => %{hits: 42, misses: 5, puts: 20, deletes: 3, clears: 1, errors: 0, fallbacks: 0, hit_rate: 0.894}

Cachetastic.Stats.get(:sessions)
Cachetastic.Stats.reset()
```

### Configurable Serialization

By default, Redis values are serialized with JSON. You can change it:

```elixir
# Use Erlang term format (supports any Elixir term)
config :cachetastic, serializer: Cachetastic.Serializers.ErlangTerm

# Or implement your own
defmodule MyApp.MsgpackSerializer do
  @behaviour Cachetastic.Serializer

  @impl true
  def encode(term), do: Msgpax.pack(term)

  @impl true
  def decode(binary), do: Msgpax.unpack(binary)
end

config :cachetastic, serializer: MyApp.MsgpackSerializer
```

### Distributed Cache Invalidation

#### Via Erlang `:pg` (BEAM clusters)

```elixir
config :cachetastic, pubsub: [adapter: Cachetastic.PubSub.PG]
```

#### Via Redis Pub/Sub (non-BEAM deployments)

```elixir
config :cachetastic, pubsub: [
  adapter: Cachetastic.PubSub.RedisPubSub,
  redis: [host: "localhost", port: 6379]
]
```

### Ecto Integration

Cache Ecto query results automatically:

```elixir
defmodule MyApp.Repo do
  use Ecto.Repo,
    otp_app: :my_app,
    adapter: Ecto.Adapters.Postgres

  use Cachetastic.Ecto, repo: MyApp.Repo
end
```

```elixir
query = from u in User, where: u.active == true

# First call hits the DB and caches the result
{:ok, users} = Repo.get_with_cache(query)

# Subsequent calls return from cache
{:ok, users} = Repo.get_with_cache(query)

# Invalidate when data changes
Repo.invalidate_cache(query)
```

See [Ecto Integration Guide](docs/ecto.md) for more details.

## Contribution

Feel free to open issues and pull requests. We appreciate your contributions!

## License

This project is licensed under the MIT License.
