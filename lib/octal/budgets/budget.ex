defmodule Octal.Budgets.Budget do
  @moduledoc "Form schema for monthly per-category budgets."
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :string, autogenerate: false}
  embedded_schema do
    field :category, :string
    field :year_month, :string
    field :limit, :decimal
  end

  def changeset(budget, attrs) do
    budget
    |> cast(attrs, [:id, :category, :year_month, :limit])
    |> validate_required([:category, :year_month, :limit])
    |> validate_format(:year_month, ~r/^\d{4}-\d{2}$/, message: "must be YYYY-MM")
    |> validate_number(:limit, greater_than_or_equal_to: Decimal.new(0))
  end
end
