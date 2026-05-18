defmodule Octal.Analytics do
  @moduledoc "Aggregations powering the Visualizations tab."

  import Ecto.Query
  alias Octal.{Budgets, Categories, Repo}
  alias Octal.Transactions.Transaction

  @doc """
  Total spend per category for the given `year_month` (\"YYYY-MM\").
  Returns `%{category: String, total: Decimal}` ordered by total desc,
  with zero-spend categories included so the axis is stable.
  """
  def spend_by_category(year_month) do
    {start_d, end_d} = month_bounds(year_month)

    spent =
      Repo.all(
        from t in Transaction,
          where: t.date >= ^start_d and t.date < ^end_d,
          group_by: t.category,
          select: {t.category, sum(t.amount)}
      )
      |> Map.new(fn {cat, total} -> {cat, total || Decimal.new(0)} end)

    Categories.names()
    |> Enum.map(fn cat ->
      %{category: cat, total: Map.get(spent, cat, Decimal.new(0))}
    end)
    |> Enum.sort_by(& &1.total, fn a, b -> Decimal.compare(a, b) != :lt end)
  end

  @doc "Spend + budget for each category in `year_month`, with overage flag."
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

  @doc "Daily spend totals for the trailing `days` (default 30) ending today."
  def daily_spend(days \\ 30) do
    today = Date.utc_today()
    from_d = Date.add(today, -(days - 1))

    by_day =
      Repo.all(
        from t in Transaction,
          where: t.date >= ^from_d,
          group_by: t.date,
          select: {t.date, sum(t.amount)}
      )
      |> Map.new()

    Enum.map(0..(days - 1), fn offset ->
      d = Date.add(from_d, offset)
      %{date: d, total: Map.get(by_day, d, Decimal.new(0))}
    end)
  end

  defp month_bounds(<<y::binary-size(4), "-", m::binary-size(2)>>) do
    year = String.to_integer(y)
    month = String.to_integer(m)
    {:ok, start_d} = Date.new(year, month, 1)
    end_d = start_d |> Date.end_of_month() |> Date.add(1)
    {start_d, end_d}
  end

  @doc "Convenience: the current month as a YYYY-MM string."
  def current_year_month do
    today = Date.utc_today()
    :io_lib.format("~4..0B-~2..0B", [today.year, today.month]) |> IO.iodata_to_binary()
  end
end
