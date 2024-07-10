defmodule Cachetastic.TestSchema do
  @moduledoc """
  Defines the schema for the test_table table.
  """
  use Ecto.Schema

  schema "test_table" do
    field(:name, :string)
    field(:age, :integer)
  end
end
