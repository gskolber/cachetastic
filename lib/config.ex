defmodule Cachetastic.Config do
  @moduledoc """
  Handles configuration and backend initialization for Cachetastic.
  """

  @spec start_backend() :: {:ok, pid()} | {:error, any()}
  def start_backend do
    config = Application.get_env(:cachetastic, :backends)

    case config[:primary] do
      :redis -> Cachetastic.Backend.Redis.start_link(config[:redis])
      :ets -> Cachetastic.Backend.ETS.start_link(config[:ets])
      _ -> {:error, "Invalid backend configuration"}
    end
  end

  @spec backend_module() :: module()
  def backend_module do
    config = Application.get_env(:cachetastic, :backends)

    case config[:primary] do
      :redis -> Cachetastic.Backend.Redis
      :ets -> Cachetastic.Backend.ETS
      _ -> raise "Invalid backend configuration"
    end
  end
end
