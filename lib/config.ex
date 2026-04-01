defmodule Cachetastic.Config do
  @moduledoc """
  Handles configuration for Cachetastic.

  Reads backend configuration from the application environment and provides
  helper functions to resolve backend modules and settings.
  """

  @doc """
  Returns the backend configuration keyword list.
  """
  def backends_config do
    Application.get_env(:cachetastic, :backends, [])
  end

  @doc """
  Returns the primary backend atom (:redis or :ets).
  """
  def primary_backend do
    config = backends_config()

    case Keyword.get(config, :fault_tolerance) do
      nil -> Keyword.get(config, :primary, :ets)
      ft -> Keyword.fetch!(ft, :primary)
    end
  end

  @doc """
  Returns the backup backend atom, or nil if not configured.
  """
  def backup_backend do
    config = backends_config()

    case Keyword.get(config, :fault_tolerance) do
      nil -> nil
      ft -> Keyword.get(ft, :backup)
    end
  end

  @doc """
  Returns the configuration for a specific backend.
  """
  def backend_config(backend) do
    Keyword.get(backends_config(), backend, [])
  end

  @doc """
  Returns the module for a backend atom.
  """
  def module_for(:redis), do: Cachetastic.Backend.Redis
  def module_for(:ets), do: Cachetastic.Backend.ETS
end
