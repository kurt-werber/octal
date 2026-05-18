defmodule Octal.Repo.Migrations.CreateCategories do
  use Ecto.Migration

  def change do
    create table(:categories, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false, size: 40
      add :color, :string, null: false, default: "#64748b"
      add :is_default, :boolean, null: false, default: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:categories, [:name])
  end
end
