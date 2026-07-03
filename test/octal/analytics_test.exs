defmodule Octal.AnalyticsTest do
  use Octal.DataCase, async: true

  alias Octal.Analytics
  alias Octal.{Budgets, Categories, Transactions}

  setup do
    Categories.ensure_defaults()
    :ok
  end

  describe "spend_by_category/1" do
    test "returns an entry for every category even with no transactions" do
      result = Analytics.spend_by_category("2020-01")
      assert length(result) == 10
      assert Enum.all?(result, &Decimal.equal?(&1.total, Decimal.new(0)))
    end

    test "sums amounts correctly for the given month" do
      Transactions.create(%{date: ~D[2026-06-10], vendor: "A", amount: "30.00", category: "Dining"})
      Transactions.create(%{date: ~D[2026-06-20], vendor: "B", amount: "20.00", category: "Dining"})

      result = Analytics.spend_by_category("2026-06")
      dining = Enum.find(result, &(&1.category == "Dining"))
      assert Decimal.equal?(dining.total, Decimal.new("50.00"))
    end

    test "excludes transactions outside the month" do
      Transactions.create(%{date: ~D[2026-05-31], vendor: "A", amount: "99.00", category: "Dining"})
      Transactions.create(%{date: ~D[2026-07-01], vendor: "B", amount: "88.00", category: "Dining"})

      result = Analytics.spend_by_category("2026-06")
      dining = Enum.find(result, &(&1.category == "Dining"))
      assert Decimal.equal?(dining.total, Decimal.new(0))
    end

    test "returns results in descending total order" do
      Transactions.create(%{date: ~D[2026-06-01], vendor: "A", amount: "10.00", category: "Dining"})
      Transactions.create(%{date: ~D[2026-06-01], vendor: "B", amount: "50.00", category: "Groceries"})

      result = Analytics.spend_by_category("2026-06")
      totals = Enum.map(result, & &1.total)
      assert totals == Enum.sort(totals, fn a, b -> Decimal.compare(a, b) != :lt end)
    end
  end

  describe "spend_vs_budget/1" do
    test "marks category as over when spend exceeds limit" do
      Budgets.set_limit(%{category: "Dining", year_month: "2026-06", limit: "50.00"})
      Transactions.create(%{date: ~D[2026-06-15], vendor: "R", amount: "75.00", category: "Dining"})

      result = Analytics.spend_vs_budget("2026-06")
      dining = Enum.find(result, &(&1.category == "Dining"))
      assert dining.over == true
    end

    test "does not mark category as over when within limit" do
      Budgets.set_limit(%{category: "Dining", year_month: "2026-06", limit: "200.00"})
      Transactions.create(%{date: ~D[2026-06-15], vendor: "R", amount: "50.00", category: "Dining"})

      result = Analytics.spend_vs_budget("2026-06")
      dining = Enum.find(result, &(&1.category == "Dining"))
      assert dining.over == false
    end

    test "does not mark over when no budget is set (zero limit)" do
      Transactions.create(%{date: ~D[2026-06-15], vendor: "R", amount: "999.00", category: "Dining"})

      result = Analytics.spend_vs_budget("2026-06")
      dining = Enum.find(result, &(&1.category == "Dining"))
      assert dining.over == false
    end

    test "includes every category regardless of spend or budget" do
      result = Analytics.spend_vs_budget("2020-01")
      assert length(result) == 10
    end
  end

  describe "daily_spend/1" do
    test "returns 30 entries by default" do
      assert length(Analytics.daily_spend()) == 30
    end

    test "returns N entries when N is specified" do
      assert length(Analytics.daily_spend(7)) == 7
      assert length(Analytics.daily_spend(90)) == 90
    end

    test "entries are in chronological order" do
      result = Analytics.daily_spend()
      dates = Enum.map(result, & &1.date)
      assert dates == Enum.sort(dates, Date)
    end

    test "includes today's spend" do
      today = Date.utc_today()

      Transactions.create(%{
        date: today,
        vendor: "Today",
        amount: "42.00",
        category: "Dining"
      })

      result = Analytics.daily_spend()
      today_entry = Enum.find(result, &(&1.date == today))
      assert Decimal.equal?(today_entry.total, Decimal.new("42.00"))
    end

    test "zeroes are filled in for days with no transactions" do
      result = Analytics.daily_spend(7)
      assert Enum.all?(result, fn e -> is_struct(e.total, Decimal) end)
    end
  end

  describe "current_year_month/0" do
    test "returns a YYYY-MM formatted string" do
      ym = Analytics.current_year_month()
      assert ym =~ ~r/^\d{4}-\d{2}$/
    end

    test "matches today's year and month" do
      today = Date.utc_today()
      expected = :io_lib.format("~4..0B-~2..0B", [today.year, today.month]) |> IO.iodata_to_binary()
      assert Analytics.current_year_month() == expected
    end
  end
end
