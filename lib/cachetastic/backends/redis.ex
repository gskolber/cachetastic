defmodule Cachetastic.Backend.Redis do
  @moduledoc """
  Redis backend for Cachetastic.

  A GenServer that owns a Redix connection and provides cache operations.
  Values are serialized using the configured `Cachetastic.Serializer` before
  storage in Redis.

  ## Options

    * `:host` - The Redis host (required)
    * `:port` - The Redis port (required)
    * `:ttl` - Default time-to-live in seconds (default: 3600)
    * `:name` - GenServer name registration (optional)
  """

  use GenServer
  @behaviour Cachetastic.Behaviour

  require Logger

  @default_ttl 3600

  # --- Public API ---

  @impl Cachetastic.Behaviour
  def start_link(opts) do
    {name, opts} = Keyword.pop(opts, :name)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @impl Cachetastic.Behaviour
  def put(server, key, value, ttl \\ nil) do
    GenServer.call(server, {:put, key, value, ttl})
  end

  @impl Cachetastic.Behaviour
  def get(server, key) do
    GenServer.call(server, {:get, key})
  end

  @impl Cachetastic.Behaviour
  def delete(server, key) do
    GenServer.call(server, {:delete, key})
  end

  @impl Cachetastic.Behaviour
  def clear(server) do
    GenServer.call(server, :clear)
  end

  # --- GenServer callbacks ---

  @impl GenServer
  def init(opts) do
    with {:ok, host} <- Keyword.fetch(opts, :host),
         {:ok, port} <- Keyword.fetch(opts, :port) do
      ttl = Keyword.get(opts, :ttl, @default_ttl)

      case Redix.start_link(host: host, port: port) do
        {:ok, conn} ->
          {:ok, %{conn: conn, ttl: ttl}}

        {:error, reason} ->
          {:stop, reason}
      end
    else
      :error -> {:stop, {:missing_config, "Both :host and :port must be provided"}}
    end
  end

  @impl GenServer
  def handle_call({:put, key, value, ttl}, _from, state) do
    ttl = ttl || state.ttl
    serializer = Cachetastic.Serializer.configured()

    result =
      case serializer.encode(value) do
        {:ok, encoded} ->
          case Redix.command(state.conn, ["SET", key, encoded, "EX", ttl]) do
            {:ok, "OK"} -> :ok
            {:error, _} = error -> error
          end

        {:error, _} = error ->
          error
      end

    {:reply, result, state}
  end

  def handle_call({:get, key}, _from, state) do
    serializer = Cachetastic.Serializer.configured()

    result =
      case Redix.command(state.conn, ["GET", key]) do
        {:ok, nil} ->
          {:error, :not_found}

        {:ok, encoded} ->
          case serializer.decode(encoded) do
            {:ok, value} -> {:ok, value}
            {:error, _} = error -> error
          end

        {:error, _} = error ->
          error
      end

    {:reply, result, state}
  end

  def handle_call({:delete, key}, _from, state) do
    result =
      case Redix.command(state.conn, ["DEL", key]) do
        {:ok, _} -> :ok
        {:error, _} = error -> error
      end

    {:reply, result, state}
  end

  def handle_call(:clear, _from, state) do
    result =
      case Redix.command(state.conn, ["FLUSHDB"]) do
        {:ok, _} -> :ok
        {:error, _} = error -> error
      end

    {:reply, result, state}
  end
end
