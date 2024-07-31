defmodule Cachetastic.TestRepo.Migrations.CreateTestTable do
  use Ecto.Migration

  def change do
    create table(:test_table) do
      add(:name, :string)
      add(:age, :integer)
    end
  end
end
