defmodule Octal.Transactions.Transaction do
  @moduledoc "Form-side schema for a transaction."
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :string, autogenerate: false}
  embedded_schema do
    field :date, :date
    field :vendor, :string
    field :amount, :decimal
    field :category, :string
    field :note, :string
  end

  def changeset(txn, attrs) do
    txn
    |> cast(attrs, [:id, :date, :vendor, :amount, :category, :note])
    |> update_change(:vendor, &maybe_trim/1)
    |> validate_required([:date, :vendor, :amount, :category])
    |> validate_length(:vendor, min: 1, max: 100)
    |> validate_number(:amount, greater_than: Decimal.new(0))
  end

  defp maybe_trim(nil), do: nil
  defp maybe_trim(s) when is_binary(s), do: String.trim(s)
end
