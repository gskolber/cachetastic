defmodule Cachetastic do
  @moduledoc """
  Cachetastic — a unified caching library for Elixir.

  Provides a simple API for cache operations backed by ETS or Redis,
  with built-in fault tolerance, telemetry, and automatic fallback.

  ## Configuration

      config :cachetastic, :backends,
        primary: :redis,
        redis: [host: "localhost", port: 6379, ttl: 3600],
        ets: [ttl: 600],
        fault_tolerance: [primary: :redis, backup: :ets]

  ## Named Caches

  You can create multiple independent cache instances:

      Cachetastic.put(:sessions, "user:123", session_data, nil)
      Cachetastic.get(:sessions, "user:123")

  The `:default` cache is used when no name is provided.

  ## Usage

      Cachetastic.put("key", "value")
      {:ok, value} = Cachetastic.get("key")
      Cachetastic.delete("key")
      Cachetastic.clear()

      # Fetch with fallback computation
      {:ok, value} = Cachetastic.fetch("key", fn -> expensive_computation() end)
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

    result =
      Telemetry.span(
        [:cachetastic, :cache, :get],
        %{key: key, cache: cache_name, backend: primary},
        fn -> execute_with_fallback(cache_name, fn mod, srv -> mod.get(srv, key) end) end
      )

    emit_get_result(key, cache_name, result)
    result
  end

  @doc """
  Fetches a value from cache. On miss, calls `fallback_fn`, caches the result, and returns it.

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

    Telemetry.span(
      [:cachetastic, :cache, :delete],
      %{key: key, cache: cache_name, backend: primary},
      fn -> execute_with_fallback(cache_name, fn mod, srv -> mod.delete(srv, key) end) end
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

    Telemetry.span(
      [:cachetastic, :cache, :put],
      %{key: key, cache: cache_name, backend: primary},
      fn -> execute_with_fallback(cache_name, fn mod, srv -> mod.put(srv, key, value, ttl) end) end
    )
  end

  defp do_fetch(cache_name, key, fallback_fn, opts) do
    ttl = Keyword.get(opts, :ttl)

    Telemetry.span([:cachetastic, :cache, :fetch], %{key: key, cache: cache_name}, fn ->
      case get(cache_name, key) do
        {:ok, value} ->
          Telemetry.emit([:cachetastic, :cache, :fetch, :result], %{}, %{key: key, cache: cache_name, result: :hit})
          {:ok, value}

        {:error, :not_found} ->
          value = fallback_fn.()
          put(cache_name, key, value, ttl)
          Telemetry.emit([:cachetastic, :cache, :fetch, :result], %{}, %{key: key, cache: cache_name, result: :miss})
          {:ok, value}

        {:error, _} = error ->
          error
      end
    end)
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
end
