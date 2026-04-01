defmodule Cachetastic.Behaviour do
  @moduledoc """
  Behaviour for Cachetastic backends.

  Each backend is a GenServer that registers itself in `Cachetastic.Registry`.
  The public API functions accept the GenServer name/pid as the first argument.
  """

  @callback start_link(keyword()) :: GenServer.on_start()
  @callback put(GenServer.server(), String.t(), any(), integer() | nil) ::
              :ok | {:error, any()}
  @callback get(GenServer.server(), String.t()) ::
              {:ok, any()} | {:error, :not_found} | {:error, any()}
  @callback delete(GenServer.server(), String.t()) :: :ok | {:error, any()}
  @callback clear(GenServer.server()) :: :ok | {:error, any()}
end
