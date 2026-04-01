defmodule Cachetastic do
  @moduledoc """
  Cachetastic — a unified caching library for Elixir.

  Provides a simple API for cache operations backed by ETS or Redis,
  with built-in fault tolerance, telemetry, and automatic fallback.

  ## Configuration

      config :cachetastic, :backends,
        primary: :redis_pool,
        redis_pool: [host: "localhost", port: 6379, pool_size: 10, ttl: 3600],
        ets: [ttl: 600],
        fault_tolerance: [primary: :redis_pool, backup: :ets]

  ## Key Namespacing

      config :cachetastic, key_prefix: "myapp"

  All keys will be automatically prefixed: `"myapp:your_key"`.

  ## Named Caches

      Cachetastic.put(:sessions, "user:123", session_data, nil)
      Cachetastic.get(:sessions, "user:123")

  ## Fetch with Thundering Herd Protection

      {:ok, value} = Cachetastic.fetch("key", fn -> expensive_computation() end)

  Only one process computes the fallback; concurrent callers wait for the result.
  """

  alias Cachetastic.Config
  alias Cachetastic.FaultTolerance
  alias Cachetastic.Telemetry

  @type cache_name :: atom()
  @type key :: String.t()
  @type ttl :: pos_integer() | nil

  @doc """
  Ensures the primary (and optionally backup) backend is started for the given cache.
  """
  @spec ensure_backends_started(cache_name()) :: :ok
  def ensure_backends_started(cache_name \\ :default) do
    primary = Config.primary_backend()
    ensure_backend_started(primary, cache_name)

    if backup = Config.backup_backend() do
      ensure_backend_started(backup, cache_name)
    end

    :ok
  end

  @doc """
  Puts a value in the cache with the specified key and optional TTL (in seconds).
  """
  @spec put(key(), term()) :: :ok | {:error, term()}
  @spec put(key(), term(), ttl()) :: :ok | {:error, term()}
  @spec put(cache_name(), key(), term(), ttl()) :: :ok | {:error, term()}
  def put(key, value) when is_binary(key), do: do_put(:default, key, value, nil)
  def put(key, value, ttl) when is_binary(key), do: do_put(:default, key, value, ttl)

  def put(cache_name, key, value, ttl) when is_atom(cache_name) do
    do_put(cache_name, key, value, ttl)
  end

  @doc """
  Gets a value from the cache by key.
  """
  @spec get(key()) :: {:ok, term()} | {:error, :not_found} | {:error, term()}
  @spec get(cache_name(), key()) :: {:ok, term()} | {:error, :not_found} | {:error, term()}
  def get(key) when is_binary(key), do: get(:default, key)

  def get(cache_name, key) when is_atom(cache_name) do
    ensure_backends_started(cache_name)
    primary = Config.primary_backend()
    prefixed_key = prefixed(key)

    result =
      Telemetry.span(
        [:cachetastic, :cache, :get],
        %{key: key, cache: cache_name, backend: primary},
        fn -> execute_with_fallback(cache_name, fn mod, srv -> mod.get(srv, prefixed_key) end) end
      )

    emit_get_result(key, cache_name, result)
    result
  end

  @doc """
  Fetches a value from cache. On miss, calls `fallback_fn`, caches the result, and returns it.

  Uses per-key locking to prevent thundering herd — only one process computes the
  fallback for a given key, and concurrent callers wait for the result.

  ## Options

    * `:ttl` - TTL in seconds for the cached value (uses backend default if not set)

  ## Examples

      {:ok, users} = Cachetastic.fetch("active_users", fn ->
        Repo.all(from u in User, where: u.active == true)
      end)
  """
  @spec fetch(key(), (-> term())) :: {:ok, term()} | {:error, term()}
  @spec fetch(key(), (-> term()), keyword()) :: {:ok, term()} | {:error, term()}
  @spec fetch(cache_name(), key(), (-> term())) :: {:ok, term()} | {:error, term()}
  @spec fetch(cache_name(), key(), (-> term()), keyword()) :: {:ok, term()} | {:error, term()}
  def fetch(key, fallback_fn) when is_binary(key) and is_function(fallback_fn, 0) do
    do_fetch(:default, key, fallback_fn, [])
  end

  def fetch(key, fallback_fn, opts) when is_binary(key) and is_function(fallback_fn, 0) and is_list(opts) do
    do_fetch(:default, key, fallback_fn, opts)
  end

  def fetch(cache_name, key, fallback_fn) when is_atom(cache_name) and is_binary(key) and is_function(fallback_fn, 0) do
    do_fetch(cache_name, key, fallback_fn, [])
  end

  def fetch(cache_name, key, fallback_fn, opts)
      when is_atom(cache_name) and is_binary(key) and is_function(fallback_fn, 0) do
    do_fetch(cache_name, key, fallback_fn, opts)
  end

  @doc """
  Deletes a value from the cache by key.
  """
  @spec delete(key()) :: :ok | {:error, term()}
  @spec delete(cache_name(), key()) :: :ok | {:error, term()}
  def delete(key) when is_binary(key), do: delete(:default, key)

  def delete(cache_name, key) when is_atom(cache_name) do
    ensure_backends_started(cache_name)
    primary = Config.primary_backend()
    prefixed_key = prefixed(key)

    Telemetry.span(
      [:cachetastic, :cache, :delete],
      %{key: key, cache: cache_name, backend: primary},
      fn -> execute_with_fallback(cache_name, fn mod, srv -> mod.delete(srv, prefixed_key) end) end
    )
  end

  @doc """
  Deletes all keys matching a pattern. Only supported on Redis/RedisPool backends.

  Uses Redis `SCAN` to avoid blocking.

  ## Examples

      Cachetastic.delete_pattern("user:*")
      Cachetastic.delete_pattern(:api_cache, "endpoint:/v1/*")
  """
  @spec delete_pattern(String.t()) :: :ok | {:error, term()}
  @spec delete_pattern(cache_name(), String.t()) :: :ok | {:error, term()}
  def delete_pattern(pattern) when is_binary(pattern), do: delete_pattern(:default, pattern)

  def delete_pattern(cache_name, pattern) when is_atom(cache_name) do
    ensure_backends_started(cache_name)
    primary = Config.primary_backend()
    prefixed_pattern = prefixed(pattern)

    Telemetry.span(
      [:cachetastic, :cache, :delete_pattern],
      %{pattern: pattern, cache: cache_name, backend: primary},
      fn ->
        server = backend_server(primary, cache_name)

        mod = Config.module_for(primary)
        do_delete_pattern(mod, server, prefixed_pattern)
      end
    )
  end

  @doc """
  Clears all values from the cache.
  """
  @spec clear() :: :ok | {:error, term()}
  @spec clear(cache_name()) :: :ok | {:error, term()}
  def clear(cache_name \\ :default) do
    ensure_backends_started(cache_name)
    primary = Config.primary_backend()

    Telemetry.span(
      [:cachetastic, :cache, :clear],
      %{cache: cache_name, backend: primary},
      fn -> execute_with_fallback(cache_name, fn mod, srv -> mod.clear(srv) end) end
    )
  end

  # --- Private helpers ---

  defp do_put(cache_name, key, value, ttl) do
    ensure_backends_started(cache_name)
    primary = Config.primary_backend()
    prefixed_key = prefixed(key)

    Telemetry.span(
      [:cachetastic, :cache, :put],
      %{key: key, cache: cache_name, backend: primary},
      fn ->
        execute_with_fallback(cache_name, fn mod, srv -> mod.put(srv, prefixed_key, value, ttl) end)
      end
    )
  end

  defp do_fetch(cache_name, key, fallback_fn, opts) do
    ttl = Keyword.get(opts, :ttl)

    Telemetry.span([:cachetastic, :cache, :fetch], %{key: key, cache: cache_name}, fn ->
      case get(cache_name, key) do
        {:ok, value} ->
          Telemetry.emit([:cachetastic, :cache, :fetch, :result], %{}, %{
            key: key, cache: cache_name, result: :hit
          })

          {:ok, value}

        {:error, :not_found} ->
          fetch_with_lock(cache_name, key, fallback_fn, ttl)

        {:error, _} = error ->
          error
      end
    end)
  end

  defp fetch_with_lock(cache_name, key, fallback_fn, ttl) do
    lock_key = {cache_name, key}

    result =
      Cachetastic.Lock.run(lock_key, fn ->
        # Double-check after acquiring lock — another process may have populated it
        case get(cache_name, key) do
          {:ok, value} -> value
          _miss ->
            value = fallback_fn.()
            put(cache_name, key, value, ttl)
            value
        end
      end)

    case result do
      {:ok, value} ->
        Telemetry.emit([:cachetastic, :cache, :fetch, :result], %{}, %{
          key: key, cache: cache_name, result: :miss
        })

        {:ok, value}

      {:error, _} = error ->
        error
    end
  end

  defp execute_with_fallback(cache_name, operation) do
    primary = Config.primary_backend()
    primary_server = backend_server(primary, cache_name)

    case Config.backup_backend() do
      nil ->
        operation.(Config.module_for(primary), primary_server)

      backup ->
        backup_server = backend_server(backup, cache_name)

        FaultTolerance.with_fallback(
          fn -> operation.(Config.module_for(primary), primary_server) end,
          fn ->
            Telemetry.emit([:cachetastic, :cache, :fallback], %{cache: cache_name, from: primary, to: backup})
            operation.(Config.module_for(backup), backup_server)
          end
        )
    end
  end

  defp emit_get_result(key, cache_name, result) do
    telemetry_result =
      case result do
        {:ok, _} -> :hit
        {:error, :not_found} -> :miss
        _ -> :error
      end

    Telemetry.emit([:cachetastic, :cache, :get, :result], %{}, %{
      key: key,
      cache: cache_name,
      result: telemetry_result
    })
  end

  defp prefixed(key) do
    case Application.get_env(:cachetastic, :key_prefix) do
      nil -> key
      prefix -> "#{prefix}:#{key}"
    end
  end

  defp ensure_backend_started(backend, cache_name) do
    registry_key = {Cachetastic.Config, backend, cache_name}

    case Registry.lookup(Cachetastic.Registry, registry_key) do
      [{_pid, _}] ->
        :ok

      [] ->
        name = {:via, Registry, {Cachetastic.Registry, registry_key}}

        opts =
          Config.backend_config(backend)
          |> Keyword.put(:name, name)
          |> Keyword.put(:table_name, :"cachetastic_#{cache_name}_#{backend}")

        DynamicSupervisor.start_child(
          Cachetastic.BackendSupervisor,
          {Config.module_for(backend), opts}
        )
    end
  end

  defp backend_server(backend, cache_name) do
    {:via, Registry, {Cachetastic.Registry, {Cachetastic.Config, backend, cache_name}}}
  end

  alias Cachetastic.Backend.RedisPool, as: PoolBackend

  defp do_delete_pattern(PoolBackend, server, pattern) do
    PoolBackend.delete_pattern(server, pattern)
  end

  defp do_delete_pattern(_mod, _server, _pattern) do
    {:error, :pattern_delete_not_supported}
  end
end
