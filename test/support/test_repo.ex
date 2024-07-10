defmodule Cachetastic.TestRepo do
  @moduledoc """
  Test repository for Cachetastic.
  """
  use Ecto.Repo,
    otp_app: :cachetastic,
    adapter: Ecto.Adapters.Postgres

  use Cachetastic.Ecto,
    repo: __MODULE__
end
