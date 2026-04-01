defmodule Cachetastic.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Registry, keys: :unique, name: Cachetastic.Registry},
      {DynamicSupervisor, name: Cachetastic.BackendSupervisor, strategy: :one_for_one},
      Cachetastic.Stats
    ]

    opts = [strategy: :one_for_one, name: Cachetastic.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
