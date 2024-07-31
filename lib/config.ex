defmodule Cachetastic.Config do
  @moduledoc """
  Handles configuration and backend initialization for Cachetastic.

  This module provides functions to start the backends and retrieve the primary
  and backup backend configurations from the application environment.

  ## Examples

      # Start the primary backend
      {:ok, pid} = Cachetastic.Config.start_backend(:redis)

      # Get the primary backend
      primary_backend = Cachetastic.Config.primary_backend()

      # Get the backup backend
      backup_backend = Cachetastic.Config.backup_backend()
  """

  @doc """
  Starts the specified backend and returns its state.
  """

  alias Cachetastic.Backend.ETS
  alias Cachetastic.Backend.Redis

  def start_backend(:redis) do
    config = Application.get_env(:cachetastic, :backends)[:redis]
    Redis.start_link(config)
  end

  def start_backend(:ets) do
    config = Application.get_env(:cachetastic, :backends)[:ets]
    ETS.start_link(config)
  end

  def start_backend(_), do: {:error, "Unsupported backend"}

  @doc """
  Returns the primary backend configuration.
  """
  def primary_backend do
    Application.get_env(:cachetastic, :backends)
    |> Keyword.get(:fault_tolerance)
    |> Keyword.fetch!(:primary)
  end

  @doc """
  Returns the backup backend configuration.
  """
  def backup_backend do
    Application.get_env(:cachetastic, :backends)
    |> Keyword.get(:fault_tolerance)
    |> Keyword.fetch(:backup)
    |> elem(1)
  end
end
