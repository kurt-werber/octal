defmodule Octal.Budgets do
  @moduledoc "Per-category, per-month budget context."

  alias Octal.Budgets.Budget
  alias Octal.MongoHelpers

  @collection "budgets"

  def list_for_month(year_month) when is_binary(year_month) do
    :mongo
    |> Mongo.find(@collection, %{"year_month" => year_month})
    |> Enum.map(&doc_to_view/1)
  end

  def get_for(category, year_month) do
    :mongo
    |> Mongo.find_one(@collection, %{"category" => category, "year_month" => year_month})
    |> doc_to_view()
  end

  @doc """
  Upsert a single category's limit for a month. `attrs` keys: `:category`,
  `:year_month`, `:limit`. Returns `{:ok, view_map}` or `{:error, changeset}`.
  """
  def set_limit(attrs) do
    cs = Budget.changeset(%Budget{}, attrs)

    with {:ok, %Budget{} = b} <- Ecto.Changeset.apply_action(cs, :insert) do
      Mongo.update_one(
        :mongo,
        @collection,
        %{"category" => b.category, "year_month" => b.year_month},
        %{
          "$set" => %{
            "category" => b.category,
            "year_month" => b.year_month,
            "limit" => MongoHelpers.to_decimal(b.limit)
          }
        },
        upsert: true
      )

      {:ok, get_for(b.category, b.year_month)}
    end
  end

  def change(budget \\ %Budget{}, attrs \\ %{}), do: Budget.changeset(budget, attrs)

  defp doc_to_view(nil), do: nil

  defp doc_to_view(%{} = doc) do
    %{
      id: MongoHelpers.from_oid(doc["_id"]),
      category: doc["category"],
      year_month: doc["year_month"],
      limit: MongoHelpers.decimal_of(doc["limit"]) || Decimal.new(0)
    }
  end
end
