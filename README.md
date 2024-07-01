# Cachetastic

## Overview

**Cachetastic** is a powerful and user-friendly caching library for Elixir. The goal is to provide a unified interface for various caching mechanisms like ETS and Redis, with built-in fault tolerance.

## Features

- **Unified Interface**: Interact with different caching backends through a consistent API.
- **Hybrid Caching**: Combine in-memory caching with persistent storage.
- **Fault Tolerance**: Automatically handle failures in the primary backend.

## Installation

Add `cachetastic` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:cachetastic, "~> 0.1.0"},
    {:redix, "~> 1.0"},
    {:patch, "~> 0.12.0", only: :test},
    {:ex_doc, "~> 0.23", only: :dev, runtime: false}
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
