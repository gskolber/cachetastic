defmodule Cachetastic.Behaviour do
  @callback start_link(keyword()) :: {:ok, pid()} | {:error, any()}
  @callback put(pid(), String.t(), any(), integer() | nil) :: :ok | {:error, any()}
  @callback get(pid(), String.t()) :: {:ok, any()} | :error | {:error, any()}
  @callback delete(pid(), String.t()) :: :ok | {:error, any()}
  @callback clear(pid()) :: :ok | {:error, any()}
end
