defmodule Octal.Transactions do
  @moduledoc "Context for transaction CRUD and vendor history lookups."

  alias Octal.MongoHelpers
  alias Octal.Transactions.Transaction

  @collection "transactions"

  def list(opts \\ []) do
    limit = Keyword.get(opts, :limit, 200)
    query = build_query(opts)

    :mongo
    |> Mongo.find(@collection, query, sort: %{"date" => -1, "_id" => -1}, limit: limit)
    |> Enum.map(&doc_to_view/1)
  end

  defp build_query(opts) do
    %{}
    |> maybe_add_range(opts[:from], opts[:to])
    |> maybe_add(:category, opts[:category])
  end

  defp maybe_add_range(q, nil, nil), do: q

  defp maybe_add_range(q, from, to) do
    range = %{}
    range = if from, do: Map.put(range, "$gte", to_dt(from)), else: range
    range = if to, do: Map.put(range, "$lte", to_dt(to)), else: range
    Map.put(q, "date", range)
  end

  defp maybe_add(q, _k, nil), do: q
  defp maybe_add(q, k, v), do: Map.put(q, Atom.to_string(k), v)

  def get(id) do
    :mongo
    |> Mongo.find_one(@collection, %{"_id" => MongoHelpers.to_oid(id)})
    |> doc_to_view()
  end

  def change(txn \\ %Transaction{date: Date.utc_today()}, attrs \\ %{}) do
    Transaction.changeset(txn, attrs)
  end

  def create(attrs) do
    with {:ok, %Transaction{} = t} <- attrs |> change() |> Ecto.Changeset.apply_action(:insert) do
      doc = %{
        "date" => to_dt(t.date),
        "vendor" => t.vendor,
        "amount" => MongoHelpers.to_decimal(t.amount),
        "category" => t.category,
        "note" => t.note,
        "inserted_at" => DateTime.utc_now()
      }

      with {:ok, %{inserted_id: oid}} <- Mongo.insert_one(:mongo, @collection, doc) do
        {:ok, get(MongoHelpers.from_oid(oid))}
      end
    end
  end

  def update(%{id: id} = existing, attrs) do
    cs = change(struct(Transaction, Map.take(existing, ~w(id date vendor amount category note)a)), attrs)

    with {:ok, %Transaction{} = t} <- Ecto.Changeset.apply_action(cs, :update) do
      Mongo.update_one(:mongo, @collection, %{"_id" => MongoHelpers.to_oid(id)}, %{
        "$set" => %{
          "date" => to_dt(t.date),
          "vendor" => t.vendor,
          "amount" => MongoHelpers.to_decimal(t.amount),
          "category" => t.category,
          "note" => t.note
        }
      })

      {:ok, get(id)}
    end
  end

  def delete(id) do
    Mongo.delete_one(:mongo, @collection, %{"_id" => MongoHelpers.to_oid(id)})
    :ok
  end

  @doc """
  Returns the median amount the user has previously spent at `vendor`,
  using a case-insensitive match. Returns `nil` if there's no history.
  """
  def median_for_vendor(vendor) when is_binary(vendor) do
    pattern = "^#{Regex.escape(String.trim(vendor))}$"

    amounts =
      :mongo
      |> Mongo.find(@collection, %{"vendor" => %{"$regex" => pattern, "$options" => "i"}})
      |> Enum.map(fn doc -> MongoHelpers.decimal_of(doc["amount"]) end)
      |> Enum.reject(&is_nil/1)

    case amounts do
      [] -> nil
      list -> median(list)
    end
  end

  def median_for_vendor(_), do: nil

  defp median(list) do
    sorted = Enum.sort(list, &(Decimal.compare(&1, &2) != :gt))
    len = length(sorted)
    mid = div(len, 2)

    if rem(len, 2) == 1 do
      Enum.at(sorted, mid)
    else
      a = Enum.at(sorted, mid - 1)
      b = Enum.at(sorted, mid)
      Decimal.div(Decimal.add(a, b), Decimal.new(2))
    end
  end

  defp doc_to_view(nil), do: nil

  defp doc_to_view(%{} = doc) do
    %{
      id: MongoHelpers.from_oid(doc["_id"]),
      date: doc["date"] |> dt_to_date(),
      vendor: doc["vendor"],
      amount: MongoHelpers.decimal_of(doc["amount"]),
      category: doc["category"],
      note: doc["note"]
    }
  end

  defp dt_to_date(nil), do: nil
  defp dt_to_date(%DateTime{} = dt), do: DateTime.to_date(dt)
  defp dt_to_date(%Date{} = d), do: d

  defp to_dt(%Date{} = d), do: DateTime.new!(d, ~T[00:00:00], "Etc/UTC")
  defp to_dt(%DateTime{} = d), do: d
  defp to_dt(s) when is_binary(s), do: s |> Date.from_iso8601!() |> to_dt()
end
