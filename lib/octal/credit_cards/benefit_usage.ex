defmodule Octal.CreditCards.BenefitUsage do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "benefit_usages" do
    field :period, :string
    field :used_at, :utc_datetime

    belongs_to :benefit, Octal.CreditCards.Benefit

    timestamps(type: :utc_datetime)
  end

  def changeset(usage, attrs) do
    usage
    |> cast(attrs, [:period, :used_at, :benefit_id])
    |> validate_required([:period, :used_at, :benefit_id])
    |> validate_format(:period, ~r/^\d{4}(-(Q[1-4]|H[1-2]|\d{2}))?$/,
      message: "must be YYYY, YYYY-MM, YYYY-Q#, or YYYY-H#"
    )
    |> foreign_key_constraint(:benefit_id)
    |> unique_constraint([:benefit_id, :period])
  end
end
