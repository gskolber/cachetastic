defmodule Cachetastic.Config do
  @moduledoc """
  Handles configuration and backend initialization for Cachetastic.
  """

  @spec start_backend(atom()) :: {:ok, pid()} | {:error, any()}
  def start_backend(:redis) do
    config = Application.get_env(:cachetastic, :backends)[:redis]
    Cachetastic.Backend.Redis.start_link(config)
  end

  def start_backend(:ets) do
    config = Application.get_env(:cachetastic, :backends)[:ets]
    Cachetastic.Backend.ETS.start_link(config)
  end

  def start_backend(:primary_mock), do: Cachetastic.PrimaryMock.start_link([])
  def start_backend(:backup_mock), do: Cachetastic.BackupMock.start_link([])

  @spec primary_backend() :: atom()
  def primary_backend do
    Application.get_env(:cachetastic, :fault_tolerance)[:primary]
  end

  @spec backup_backend() :: atom()
  def backup_backend do
    Application.get_env(:cachetastic, :fault_tolerance)[:backup]
  end
end
