defmodule Cachetastic.Behaviour do
  @callback start_link(any()) :: {:ok, pid()} | {:error, any()}
  @callback put(pid(), String.t(), any(), integer() | nil) :: :ok
  @callback get(pid(), String.t()) :: {:ok, any()} | :error
  @callback delete(pid(), String.t()) :: :ok
  @callback clear(pid()) :: :ok
end
