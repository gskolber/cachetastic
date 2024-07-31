# Ecto Integration

Cachetastic provides caching functionality for Ecto queries, allowing you to cache and retrieve query results efficiently.

## Usage

### Step 1: Add Cachetastic to Your Dependencies

Update your `mix.exs` file to include Cachetastic as a dependency:

```elixir
defp deps do
  [
    {:cachetastic, "~> 0.1.0"},
    {:ecto, "~> 3.6"},
    {:ecto_sql, "~> 3.6"},
    {:postgrex, ">= 0.0.0"}
  ]
end
```

Run `mix deps.get` to fetch the dependencies.

### Step 2: Configure Cachetastic

Add the configuration for Cachetastic in your `config/config.exs` file:

```elixir
use Mix.Config

config :cachetastic,
  backends: [
    ets: [ttl: 600],
    redis: [host: "localhost", port: 6379, ttl: 3600]
  ],
  fault_tolerance: [primary: :redis, backup: :ets]

config :cachetastic, Cachetastic.TestRepo,
  username: "postgres",
  password: "postgres",
  database: "my_app_test",
  hostname: "localhost"

config :cachetastic, ecto_repos: [Cachetastic.TestRepo]
```

### Step 3: Implement Cachetastic in Your Ecto Repo

Add the Cachetastic plugin to your Ecto repo:

```elixir
defmodule MyApp.Repo do
  use Ecto.Repo,
    otp_app: :my_app,
    adapter: Ecto.Adapters.Postgres

  use Cachetastic.Ecto, repo: MyApp.Repo
end
```

### Step 4: Use Cachetastic in Your Application

Now you can use Cachetastic to cache and retrieve Ecto query results:

```elixir
defmodule MyApp.SomeModule do
  alias MyApp.Repo
  alias MyApp.User

  def some_function do
    query = from u in User, where: u.active == true

    # Fetch with cache
    {:ok, users} = Repo.get_with_cache(query)

    # Invalidate cache
    Repo.invalidate_cache(query)
  end
end
```
