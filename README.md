# Cachetastic

## Overview

**Cachetastic** is a powerful and user-friendly caching library for Elixir. The goal is to provide a unified interface for various caching mechanisms like ETS and Redis, with built-in fault tolerance.

## Features

- **Unified Interface**: Interact with different caching backends through a consistent API.
- **Hybrid Caching**: Combine in-memory caching with persistent storage.
- **Fault Tolerance**: Automatically handle failures in the primary backend.
- **Ecto Integration**: Cache and retrieve Ecto query results seamlessly.

## Installation

Add `cachetastic` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:cachetastic, "~> 0.1.0"},
    {:redix, "~> 1.0"},
  ]
end
```

Run `mix deps.get` to fetch the dependencies.

## Usage

### Configuration

Define the backends and fault tolerance configuration in `config/config.exs`:

```elixir
use Mix.Config

config :cachetastic,
  backends: [
    ets: [ttl: 600],
    redis: [host: "localhost", port: 6379, ttl: 3600]
  ],
  fault_tolerance: [primary: :redis, backup: :ets]
```

### Basic Operations

Initialize the cache and perform basic operations:

```elixir
# Start the cache
{:ok, _pid} = Cachetastic.start_link()

# Cache operations
Cachetastic.put("key", "value")
{:ok, value} = Cachetastic.get("key")
Cachetastic.delete("key")
Cachetastic.clear()
```

### Ecto Integration

You can use Cachetastic to cache and retrieve Ecto query results.

#### Step 1: Add Cachetastic to Your Dependencies

Update your `mix.exs` file to include Cachetastic as a dependency:

```elixir
defp deps do
  [
    {:cachetastic, "~> 0.1.0"}
  ]
end
```

Run `mix deps.get` to fetch the dependencies.

#### Step 2: Configure Cachetastic

Add the configuration for Cachetastic in your `config/config.exs` file:

```elixir
use Mix.Config

config :cachetastic,
  backends: [
    ets: [ttl: 600],
    redis: [host: "localhost", port: 6379, ttl: 3600]
  ],
  fault_tolerance: [primary: :redis, backup: :ets]
```

#### Step 3: Implement Cachetastic in Your Ecto Repo

Add the Cachetastic plugin to your Ecto repo:

```elixir
defmodule MyApp.Repo do
  use Ecto.Repo,
    otp_app: :my_app,
    adapter: Ecto.Adapters.Postgres

  use Cachetastic.Ecto, repo: MyApp.Repo
end
```

#### Step 4: Use Cachetastic in Your Application

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

### Example Implementation

Here's an example of how you can integrate Cachetastic into your own Elixir application:

#### Step 1: Add Cachetastic to Your Dependencies

Update your `mix.exs` file to include Cachetastic as a dependency:

```elixir
defp deps do
  [
    {:cachetastic, "~> 0.1.0"}
  ]
end
```

Run `mix deps.get` to fetch the dependencies.

#### Step 2: Configure Cachetastic

Add the configuration for Cachetastic in your `config/config.exs` file:

```elixir
use Mix.Config

config :cachetastic,
  backends: [
    ets: [ttl: 600],
    redis: [host: "localhost", port: 6379, ttl: 3600]
  ],
  fault_tolerance: [primary: :redis, backup: :ets]
```

#### Step 3: Use Cachetastic in Your Application

In your application module, start Cachetastic and use it to perform caching operations:

```elixir
defmodule MyApp.Application do
  use Application

  def start(_type, _args) do
    children = [
      # Start the Cachetastic cache
      {Cachetastic, []}
    ]

    opts = [strategy: :one_for_one, name: MyApp.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
```

Now you can use Cachetastic to perform caching operations anywhere in your application:

```elixir
defmodule MyApp.SomeModule do
  def some_function do
    # Put a value in the cache
    Cachetastic.put("my_key", "my_value")

    # Get a value from the cache
    case Cachetastic.get("my_key") do
      {:ok, value} -> IO.puts("Got value: #{value}")
      :error -> IO.puts("Key not found")
    end

    # Delete a value from the cache
    Cachetastic.delete("my_key")

    # Clear the entire cache
    Cachetastic.clear()
  end
end
```

### Contribution

Feel free to open issues and pull requests. We appreciate your contributions!

## License

This project is licensed under the MIT License.
