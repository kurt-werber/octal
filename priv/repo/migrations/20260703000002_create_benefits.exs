defmodule Octal.Repo.Migrations.CreateBenefits do
  use Ecto.Migration

  def change do
    create table(:benefits, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :credit_card_id, references(:credit_cards, type: :binary_id, on_delete: :delete_all), null: false
      add :name, :string, null: false, size: 60
      add :amount, :decimal, precision: 14, scale: 2, null: false
      add :frequency, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:benefits, [:credit_card_id])
  end
end
