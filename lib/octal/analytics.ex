defmodule Octal.Analytics do
  @moduledoc """
  Aggregations powering the Visualizations tab.

  Everything returns plain maps/lists so views can render without further
  transformation.
  """

  alias Octal.{Budgets, Categories, MongoHelpers}

  @collection "transactions"

  @doc """
  Total spend per category for the given `year_month` (\"YYYY-MM\").

  Returns a list of `%{category: String, total: Decimal}` ordered by total desc,
  including categories with zero spend so the chart axis is stable.
  """
  def spend_by_category(year_month) do
    {start_dt, end_dt} = month_bounds(year_month)

    pipeline = [
      %{"$match" => %{"date" => %{"$gte" => start_dt, "$lt" => end_dt}}},
      %{"$group" => %{"_id" => "$category", "total" => %{"$sum" => "$amount"}}}
    ]

    spent =
      :mongo
      |> Mongo.aggregate(@collection, pipeline)
      |> Enum.map(fn %{"_id" => cat, "total" => total} ->
        {cat, decimal_or_zero(total)}
      end)
      |> Map.new()

    Categories.names()
    |> Enum.map(fn cat ->
      %{category: cat, total: Map.get(spent, cat, Decimal.new(0))}
    end)
    |> Enum.sort_by(& &1.total, fn a, b -> Decimal.compare(a, b) != :lt end)
  end

  @doc """
  For each category in `year_month`, return spent + budget so the view can
  render a bar pair (spent vs limit) with overage flagged.
  """
  def spend_vs_budget(year_month) do
    spent = spend_by_category(year_month) |> Map.new(&{&1.category, &1.total})
    budgets = Budgets.list_for_month(year_month) |> Map.new(&{&1.category, &1.limit})

    Categories.names()
    |> Enum.map(fn cat ->
      total = Map.get(spent, cat, Decimal.new(0))
      limit = Map.get(budgets, cat, Decimal.new(0))

      over? =
        Decimal.compare(limit, Decimal.new(0)) == :gt and
          Decimal.compare(total, limit) == :gt

      %{category: cat, spent: total, limit: limit, over: over?}
    end)
  end

  @doc """
  Daily spend totals for the trailing `days` (default 30) ending today,
  filling missing days with zero.
  """
  def daily_spend(days \\ 30) do
    today = Date.utc_today()
    from = Date.add(today, -(days - 1))

    pipeline = [
      %{"$match" => %{"date" => %{"$gte" => to_dt(from)}}},
      %{
        "$group" => %{
          "_id" => %{
            "$dateToString" => %{"format" => "%Y-%m-%d", "date" => "$date"}
          },
          "total" => %{"$sum" => "$amount"}
        }
      }
    ]

    by_day =
      :mongo
      |> Mongo.aggregate(@collection, pipeline)
      |> Enum.map(fn %{"_id" => k, "total" => t} -> {k, decimal_or_zero(t)} end)
      |> Map.new()

    Enum.map(0..(days - 1), fn offset ->
      d = Date.add(from, offset)
      key = Date.to_iso8601(d)
      %{date: d, total: Map.get(by_day, key, Decimal.new(0))}
    end)
  end

  defp month_bounds(<<y::binary-size(4), "-", m::binary-size(2)>>) do
    year = String.to_integer(y)
    month = String.to_integer(m)
    {:ok, start_d} = Date.new(year, month, 1)
    next_month_d = start_d |> Date.end_of_month() |> Date.add(1)
    {to_dt(start_d), to_dt(next_month_d)}
  end

  defp to_dt(%Date{} = d), do: DateTime.new!(d, ~T[00:00:00], "Etc/UTC")

  defp decimal_or_zero(value), do: MongoHelpers.decimal_of(value) || Decimal.new(0)

  @doc "Convenience: the current month as a YYYY-MM string."
  def current_year_month, do: MongoHelpers.year_month(Date.utc_today())
end
