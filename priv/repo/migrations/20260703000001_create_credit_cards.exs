defmodule Octal.Repo.Migrations.CreateCreditCards do
  use Ecto.Migration

  def change do
    create table(:credit_cards, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false, size: 60

      timestamps(type: :utc_datetime)
    end
  end
end
