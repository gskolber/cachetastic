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
    {:mox, "~> 1.0", only: :test}
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

### Contribution

Feel free to open issues and pull requests. We appreciate your contributions!

## License

This project is licensed under the MIT License.
