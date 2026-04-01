defmodule Cachetastic.FaultTolerance do
  @moduledoc """
  Fault tolerance utilities for Cachetastic.

  Provides retry logic with configurable attempts and delay, plus automatic
  fallback to a backup function when the primary fails.

  Results are classified as:
    - `:success` — `:ok` or `{:ok, _}` — returned immediately, no retry
    - `:not_found` — `{:error, :not_found}` — returned immediately, no retry or fallback
    - `:error` — anything else — triggers retry, then fallback
  """

  require Logger

  @default_retry_attempts 3
  @default_retry_delay 100

  @doc """
  Executes `primary_fun`. On failure (after retries), executes `backup_fun`.

  `{:error, :not_found}` is NOT treated as a failure — it is returned as-is
  without triggering fallback.

  ## Options

    * `:retry_attempts` - Number of retry attempts (default: 3)
    * `:retry_delay` - Delay in ms between retries (default: 100)
  """
  def with_fallback(primary_fun, backup_fun, opts \\ []) do
    case with_retries(primary_fun, opts) do
      :ok = result -> result
      {:ok, _} = result -> result
      {:error, :not_found} = result -> result
      _error ->
        Logger.warning("[Cachetastic] Primary backend failed, falling back to backup")
        with_retries(backup_fun, opts)
    end
  end

  @doc """
  Executes `fun` with retries on failure.

  `{:error, :not_found}` is returned immediately without retrying.

  ## Options

    * `:retry_attempts` - Number of retry attempts (default: 3)
    * `:retry_delay` - Delay in ms between retries (default: 100)
  """
  def with_retries(fun, opts \\ []) do
    attempts = Keyword.get(opts, :retry_attempts, @default_retry_attempts)
    delay = Keyword.get(opts, :retry_delay, @default_retry_delay)
    do_retries(fun, attempts, delay)
  end

  defp do_retries(fun, attempts, delay) when attempts > 0 do
    case fun.() do
      :ok = result ->
        result

      {:ok, _} = result ->
        result

      {:error, :not_found} = result ->
        result

      error ->
        Logger.debug(
          "[Cachetastic] Operation failed (#{attempts - 1} retries left): #{inspect(error)}"
        )

        Process.sleep(delay)
        do_retries(fun, attempts - 1, delay)
    end
  end

  defp do_retries(_fun, 0, _delay) do
    {:error, :operation_failed}
  end
end
