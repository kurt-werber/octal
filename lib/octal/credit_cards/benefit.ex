defmodule Octal.CreditCards.Benefit do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "benefits" do
    field :name, :string
    field :amount, :decimal
    field :frequency, Ecto.Enum, values: [:monthly, :quarterly, :semi_annual, :annual]

    belongs_to :credit_card, Octal.CreditCards.CreditCard
    has_many :benefit_usages, Octal.CreditCards.BenefitUsage

    timestamps(type: :utc_datetime)
  end

  def changeset(benefit, attrs) do
    benefit
    |> cast(attrs, [:name, :amount, :frequency, :credit_card_id])
    |> update_change(:name, &maybe_trim/1)
    |> validate_required([:name, :amount, :frequency, :credit_card_id])
    |> validate_length(:name, min: 1, max: 60)
    |> validate_number(:amount, greater_than: Decimal.new(0))
    |> foreign_key_constraint(:credit_card_id)
  end

  defp maybe_trim(nil), do: nil
  defp maybe_trim(s) when is_binary(s), do: String.trim(s)
end
