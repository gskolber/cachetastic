defmodule Cachetastic.Backend.RedisPool do
  @moduledoc """
  Pooled Redis backend for Cachetastic using NimblePool.

  Maintains a pool of Redix connections for concurrent access. Under load,
  this avoids bottlenecking on a single connection.

  ## Options

    * `:host` - The Redis host (required)
    * `:port` - The Redis port (required)
    * `:ttl` - Default time-to-live in seconds (default: 3600)
    * `:pool_size` - Number of connections in the pool (default: 5)
    * `:name` - GenServer name registration (optional)
  """

  @behaviour Cachetastic.Behaviour

  require Logger

  @default_ttl 3600
  @default_pool_size 5

  def child_spec(opts) do
    %{
      id: {__MODULE__, Keyword.get(opts, :name, __MODULE__)},
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent
    }
  end

  # --- Public API ---

  @impl Cachetastic.Behaviour
  def start_link(opts) do
    {name, opts} = Keyword.pop(opts, :name)
    host = Keyword.fetch!(opts, :host)
    port = Keyword.fetch!(opts, :port)
    ttl = Keyword.get(opts, :ttl, @default_ttl)
    pool_size = Keyword.get(opts, :pool_size, @default_pool_size)

    pool_opts = [
      worker: {__MODULE__.Worker, {host, port}},
      pool_size: pool_size,
      name: name
    ]

    case NimblePool.start_link(pool_opts) do
      {:ok, pid} ->
        # Store TTL in the process dictionary via a companion Agent
        ttl_name = ttl_agent_name(name)
        Agent.start_link(fn -> ttl end, name: ttl_name)
        {:ok, pid}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl Cachetastic.Behaviour
  def put(pool, key, value, ttl \\ nil) do
    ttl = ttl || get_ttl(pool)

    with {:ok, encoded} <- Cachetastic.Serializer.encode(value) do
      checkout_and_run(pool, &redis_set(&1, key, encoded, ttl))
    end
  end

  @impl Cachetastic.Behaviour
  def get(pool, key) do
    checkout_and_run(pool, fn conn ->
      case Redix.command(conn, ["GET", key]) do
        {:ok, nil} -> {:error, :not_found}
        {:ok, encoded} -> Cachetastic.Serializer.decode(encoded)
        {:error, _} = error -> error
      end
    end)
  end

  @impl Cachetastic.Behaviour
  def delete(pool, key) do
    checkout_and_run(pool, fn conn ->
      case Redix.command(conn, ["DEL", key]) do
        {:ok, _} -> :ok
        {:error, _} = error -> error
      end
    end)
  end

  @impl Cachetastic.Behaviour
  def clear(pool) do
    checkout_and_run(pool, fn conn ->
      case Redix.command(conn, ["FLUSHDB"]) do
        {:ok, _} -> :ok
        {:error, _} = error -> error
      end
    end)
  end

  @doc """
  Scans for keys matching a pattern and deletes them.

  Uses `SCAN` to avoid blocking Redis with `KEYS`.
  """
  def delete_pattern(pool, pattern) do
    checkout_and_run(pool, fn conn ->
      scan_and_delete(conn, pattern, "0")
    end)
  end

  # --- Private ---

  defp redis_set(conn, key, encoded, ttl) do
    case Redix.command(conn, ["SET", key, encoded, "EX", ttl]) do
      {:ok, "OK"} -> :ok
      {:error, _} = error -> error
    end
  end

  defp checkout_and_run(pool, fun) do
    NimblePool.checkout!(pool, :checkout, fn _from, conn ->
      {fun.(conn), conn}
    end)
  catch
    :exit, reason -> {:error, {:pool_error, reason}}
  end

  defp scan_and_delete(conn, pattern, cursor) do
    case Redix.command(conn, ["SCAN", cursor, "MATCH", pattern, "COUNT", "100"]) do
      {:ok, ["0", []]} ->
        :ok

      {:ok, ["0", keys]} ->
        delete_keys(conn, keys)

      {:ok, [next_cursor, []]} ->
        scan_and_delete(conn, pattern, next_cursor)

      {:ok, [next_cursor, keys]} ->
        delete_keys(conn, keys)
        scan_and_delete(conn, pattern, next_cursor)

      {:error, _} = error ->
        error
    end
  end

  defp delete_keys(conn, keys) do
    Redix.command(conn, ["DEL" | keys])
    :ok
  end

  defp get_ttl(pool) do
    ttl_name = ttl_agent_name(pool)
    Agent.get(ttl_name, & &1)
  catch
    :exit, _ -> @default_ttl
  end

  defp ttl_agent_name(pool) when is_pid(pool), do: :"#{inspect(pool)}_ttl"

  defp ttl_agent_name({:via, Registry, {registry, key}}) do
    {:via, Registry, {registry, {key, :ttl}}}
  end

  defp ttl_agent_name(name), do: :"#{name}_ttl"

  # --- NimblePool Worker ---

  defmodule Worker do
    @moduledoc false
    @behaviour NimblePool

    @impl NimblePool
    def init_worker({host, port}) do
      {:ok, conn} = Redix.start_link(host: host, port: port)
      {:ok, conn, {host, port}}
    end

    @impl NimblePool
    def handle_checkout(:checkout, _from, conn, pool_state) do
      {:ok, conn, conn, pool_state}
    end

    @impl NimblePool
    def handle_checkin(conn, _from, _old_conn, pool_state) do
      {:ok, conn, pool_state}
    end

    @impl NimblePool
    def terminate_worker(_reason, conn, pool_state) do
      Redix.stop(conn)
      {:ok, pool_state}
    end
  end
end
