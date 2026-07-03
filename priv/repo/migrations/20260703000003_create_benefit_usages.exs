defmodule Octal.Repo.Migrations.CreateBenefitUsages do
  use Ecto.Migration

  def change do
    create table(:benefit_usages, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :benefit_id, references(:benefits, type: :binary_id, on_delete: :delete_all), null: false
      add :period, :string, null: false, size: 10
      add :used_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:benefit_usages, [:benefit_id, :period])
  end
end
