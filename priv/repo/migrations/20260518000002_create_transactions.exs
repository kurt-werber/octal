defmodule Octal.Repo.Migrations.CreateTransactions do
  use Ecto.Migration

  def change do
    create table(:transactions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :date, :date, null: false
      add :vendor, :string, null: false, size: 100
      add :amount, :decimal, precision: 14, scale: 2, null: false
      add :category, :string, null: false
      add :note, :string

      timestamps(type: :utc_datetime)
    end

    create index(:transactions, [:date])
    create index(:transactions, [:vendor])
    create index(:transactions, [:category, :date])
  end
end
