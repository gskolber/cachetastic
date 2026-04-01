# Ecto Integration

Cachetastic provides caching functionality for Ecto queries, allowing you to cache and retrieve query results efficiently.

## Setup

### Step 1: Add Dependencies

Update your `mix.exs` file:

```elixir
defp deps do
  [
    {:cachetastic, "~> 1.0"},
    {:ecto, "~> 3.6"},
    {:ecto_sql, "~> 3.6"},
    {:postgrex, ">= 0.0.0"}
  ]
end
```

Run `mix deps.get` to fetch the dependencies.

### Step 2: Configure Cachetastic

Add the configuration in your `config/config.exs` file:

```elixir
import Config

config :cachetastic, :backends,
  primary: :redis,
  redis: [host: "localhost", port: 6379, ttl: 3600],
  ets: [ttl: 600],
  fault_tolerance: [primary: :redis, backup: :ets]
```

### Step 3: Add Cachetastic to Your Repo

```elixir
defmodule MyApp.Repo do
  use Ecto.Repo,
    otp_app: :my_app,
    adapter: Ecto.Adapters.Postgres

  use Cachetastic.Ecto, repo: MyApp.Repo
end
```

### Step 4: Use It

```elixir
defmodule MyApp.SomeModule do
  alias MyApp.Repo
  alias MyApp.User
  import Ecto.Query

  def list_active_users do
    query = from u in User, where: u.active == true

    # First call executes the query and caches the result
    {:ok, users} = Repo.get_with_cache(query)
    users
  end

  def update_user(user, attrs) do
    query = from u in User, where: u.active == true

    # Invalidate cache after data changes
    Repo.invalidate_cache(query)

    Repo.update(Ecto.Changeset.change(user, attrs))
  end
end
```

## How It Works

- `Repo.get_with_cache(query)` — checks the cache first. On miss, runs the query, serializes the results using the configured `Cachetastic.Serializer`, stores them, and returns.
- `Repo.invalidate_cache(query)` — deletes the cached entry for that query.
- Cache keys are derived from the query inspection, so different queries get different cache entries.

## Serialization

The Ecto integration uses whichever serializer is configured for Cachetastic. The default is JSON (`Cachetastic.Serializers.JSON`). Ecto struct metadata (`__meta__`, `__struct__`) is preserved during serialization/deserialization.

If you need to cache structs with non-JSON-serializable fields, switch to the Erlang term serializer:

```elixir
config :cachetastic, serializer: Cachetastic.Serializers.ErlangTerm
```
