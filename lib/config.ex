defmodule Cachetastic.Config do
  @moduledoc """
  Handles configuration and backend initialization for Cachetastic.
  """

  def start_backend(:redis) do
    config = Application.get_env(:cachetastic, :backends)[:redis]
    Cachetastic.Backend.Redis.start_link(config)
  end

  def start_backend(:ets) do
    config = Application.get_env(:cachetastic, :backends)[:ets]
    Cachetastic.Backend.ETS.start_link(config)
  end

  def start_backend(_), do: {:error, "Unsupported backend"}

  def primary_backend do
    Application.get_env(:cachetastic, :fault_tolerance)[:primary]
  end

  def backup_backend do
    Application.get_env(:cachetastic, :fault_tolerance)[:backup]
  end
end
