defmodule Octal.CreditCards.CreditCard do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "credit_cards" do
    field :name, :string

    has_many :benefits, Octal.CreditCards.Benefit

    timestamps(type: :utc_datetime)
  end

  def changeset(card, attrs) do
    card
    |> cast(attrs, [:name])
    |> update_change(:name, &maybe_trim/1)
    |> validate_required([:name])
    |> validate_length(:name, min: 1, max: 60)
  end

  defp maybe_trim(nil), do: nil
  defp maybe_trim(s) when is_binary(s), do: String.trim(s)
end
