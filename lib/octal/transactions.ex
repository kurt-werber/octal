defmodule Octal.Transactions do
  @moduledoc "Context for transaction CRUD and vendor history lookups."

  import Ecto.Query
  alias Octal.Repo
  alias Octal.Transactions.Transaction

  def list(opts \\ []) do
    limit = Keyword.get(opts, :limit, 200)

    Transaction
    |> filter_by_range(opts[:from], opts[:to])
    |> filter_by_category(opts[:category])
    |> order_by([t], desc: t.date, desc: t.id)
    |> limit(^limit)
    |> Repo.all()
  end

  defp filter_by_range(q, nil, nil), do: q
  defp filter_by_range(q, from, nil), do: from(t in q, where: t.date >= ^from)
  defp filter_by_range(q, nil, to), do: from(t in q, where: t.date <= ^to)
  defp filter_by_range(q, from, to), do: from(t in q, where: t.date >= ^from and t.date <= ^to)

  defp filter_by_category(q, nil), do: q
  defp filter_by_category(q, cat), do: from(t in q, where: t.category == ^cat)

  def get(id) do
    Repo.get(Transaction, id)
  rescue
    Ecto.Query.CastError -> nil
  end

  def change(txn \\ %Transaction{date: Date.utc_today()}, attrs \\ %{}) do
    Transaction.changeset(txn, attrs)
  end

  def create(attrs) do
    %Transaction{}
    |> Transaction.changeset(attrs)
    |> Repo.insert()
  end

  def update(%Transaction{} = txn, attrs) do
    txn
    |> Transaction.changeset(attrs)
    |> Repo.update()
  end

  def delete(id) when is_binary(id) do
    case get(id) do
      nil -> :ok
      txn -> Repo.delete(txn) && :ok
    end
  end

  def delete(%Transaction{} = txn) do
    Repo.delete(txn)
    :ok
  end

  @doc """
  Returns the median amount spent at `vendor` (case-insensitive). Uses
  Postgres's `percentile_cont` aggregate so it stays correct and fast as the
  table grows. Returns `nil` if there's no history.
  """
  def median_for_vendor(vendor) when is_binary(vendor) do
    pattern = String.trim(vendor)

    Repo.one(
      from t in Transaction,
        where: fragment("lower(?) = lower(?)", t.vendor, ^pattern),
        select:
          fragment(
            "percentile_cont(0.5) within group (order by ?)",
            t.amount
          )
    )
    |> case do
      nil -> nil
      %Decimal{} = d -> d
      n when is_float(n) -> n |> Float.to_string() |> Decimal.new()
      n when is_integer(n) -> Decimal.new(n)
    end
  end

  def median_for_vendor(_), do: nil
end
