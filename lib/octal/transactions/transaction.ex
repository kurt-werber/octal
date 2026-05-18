defmodule Octal.Transactions.Transaction do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "transactions" do
    field :date, :date
    field :vendor, :string
    field :amount, :decimal
    field :category, :string
    field :note, :string

    timestamps(type: :utc_datetime)
  end

  def changeset(txn, attrs) do
    txn
    |> cast(attrs, [:date, :vendor, :amount, :category, :note])
    |> update_change(:vendor, &maybe_trim/1)
    |> validate_required([:date, :vendor, :amount, :category])
    |> validate_length(:vendor, min: 1, max: 100)
    |> validate_number(:amount, greater_than: Decimal.new(0))
  end

  defp maybe_trim(nil), do: nil
  defp maybe_trim(s) when is_binary(s), do: String.trim(s)
end
