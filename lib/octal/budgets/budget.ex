defmodule Octal.Budgets.Budget do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "budgets" do
    field :category, :string
    field :year_month, :string
    field :limit, :decimal

    timestamps(type: :utc_datetime)
  end

  def changeset(budget, attrs) do
    budget
    |> cast(attrs, [:category, :year_month, :limit])
    |> validate_required([:category, :year_month, :limit])
    |> validate_format(:year_month, ~r/^\d{4}-\d{2}$/, message: "must be YYYY-MM")
    |> validate_number(:limit, greater_than_or_equal_to: Decimal.new(0))
    |> unique_constraint([:category, :year_month])
  end
end
