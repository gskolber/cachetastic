defmodule Cachetastic.FaultTolerance do
  @moduledoc """
  Fault tolerance utilities for Cachetastic.
  """
  @retry_attempts 3
  @retry_delay 100

  def with_fallback(primary_fun, backup_fun) do
    case with_retries(primary_fun) do
      result = :ok -> result
      result = {:ok, _} -> result
      result = {:error, :not_found} -> result
      _error -> with_retries(backup_fun)
    end
  end

  defp with_retries(fun) do
    with_retries(fun, @retry_attempts)
  end

  defp with_retries(fun, attempts) when attempts > 0 do
    case fun.() do
      result = :ok ->
        result

      result = {:ok, _} ->
        result

      result = {:error, :not_found} ->
        result

      _error ->
        Process.sleep(@retry_delay)
        with_retries(fun, attempts - 1)
    end
  end

  defp with_retries(_fun, 0), do: {:error, "Operation failed after #{@retry_attempts} attempts"}
end
