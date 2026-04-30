defmodule Octal.Categories.Category do
  @moduledoc """
  Embedded schema (no Ecto.Repo) used purely for `Phoenix.HTML.Form` interop
  and `Ecto.Changeset` validation. The persisted form is a plain Mongo doc:

      %{"_id" => oid, "name" => "Dining", "color" => "#f87171", "is_default" => true}
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :string, autogenerate: false}
  embedded_schema do
    field :name, :string
    field :color, :string, default: "#64748b"
    field :is_default, :boolean, default: false
  end

  def changeset(category, attrs) do
    category
    |> cast(attrs, [:id, :name, :color, :is_default])
    |> update_change(:name, &maybe_trim/1)
    |> validate_required([:name])
    |> validate_length(:name, min: 1, max: 40)
    |> validate_format(:color, ~r/^#[0-9a-fA-F]{6}$/, message: "must be a hex like #rrggbb")
  end

  defp maybe_trim(nil), do: nil
  defp maybe_trim(s) when is_binary(s), do: String.trim(s)
end
