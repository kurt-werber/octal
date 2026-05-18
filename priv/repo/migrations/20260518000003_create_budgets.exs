defmodule Octal.Repo.Migrations.CreateBudgets do
  use Ecto.Migration

  def change do
    create table(:budgets, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :category, :string, null: false
      add :year_month, :string, null: false, size: 7
      add :limit, :decimal, precision: 14, scale: 2, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:budgets, [:category, :year_month])
  end
end
