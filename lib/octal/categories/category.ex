defmodule Octal.Categories.Category do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "categories" do
    field :name, :string
    field :color, :string, default: "#64748b"
    field :is_default, :boolean, default: false

    timestamps(type: :utc_datetime)
  end

  def changeset(category, attrs) do
    category
    |> cast(attrs, [:name, :color, :is_default])
    |> update_change(:name, &maybe_trim/1)
    |> validate_required([:name])
    |> validate_length(:name, min: 1, max: 40)
    |> validate_format(:color, ~r/^#[0-9a-fA-F]{6}$/, message: "must be a hex like #rrggbb")
    |> unique_constraint(:name)
  end

  defp maybe_trim(nil), do: nil
  defp maybe_trim(s) when is_binary(s), do: String.trim(s)
end
