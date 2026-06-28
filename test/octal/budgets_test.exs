defmodule Octal.BudgetsTest do
  use Octal.DataCase, async: true

  alias Octal.Budgets
  alias Octal.Budgets.Budget

  @valid_attrs %{category: "Dining", year_month: "2026-06", limit: "500.00"}

  describe "set_limit/1" do
    test "creates a budget" do
      assert {:ok, %Budget{category: "Dining"}} = Budgets.set_limit(@valid_attrs)
    end

    test "upserts on second call — stores the latest limit" do
      Budgets.set_limit(@valid_attrs)
      {:ok, updated} = Budgets.set_limit(Map.put(@valid_attrs, :limit, "750.00"))
      assert Decimal.equal?(updated.limit, Decimal.new("750.00"))

      stored = Budgets.get_for("Dining", "2026-06")
      assert Decimal.equal?(stored.limit, Decimal.new("750.00"))
    end

    test "returns error changeset for missing category" do
      assert {:error, cs} = Budgets.set_limit(%{year_month: "2026-06", limit: "100"})
      assert %{category: [_ | _]} = errors_on(cs)
    end

    test "returns error changeset for missing year_month" do
      assert {:error, cs} = Budgets.set_limit(%{category: "Dining", limit: "100"})
      assert %{year_month: [_ | _]} = errors_on(cs)
    end

    test "returns error changeset for invalid year_month format" do
      attrs = Map.put(@valid_attrs, :year_month, "06-2026")
      assert {:error, cs} = Budgets.set_limit(attrs)
      assert %{year_month: [_ | _]} = errors_on(cs)
    end

    test "returns error changeset for negative limit" do
      assert {:error, cs} = Budgets.set_limit(Map.put(@valid_attrs, :limit, "-1"))
      assert %{limit: [_ | _]} = errors_on(cs)
    end

    test "allows zero limit" do
      assert {:ok, %Budget{}} = Budgets.set_limit(Map.put(@valid_attrs, :limit, "0"))
    end

    test "different categories in the same month are independent" do
      Budgets.set_limit(%{category: "Dining", year_month: "2026-06", limit: "300"})
      Budgets.set_limit(%{category: "Travel", year_month: "2026-06", limit: "500"})

      dining = Budgets.get_for("Dining", "2026-06")
      travel = Budgets.get_for("Travel", "2026-06")
      assert Decimal.equal?(dining.limit, Decimal.new("300"))
      assert Decimal.equal?(travel.limit, Decimal.new("500"))
    end
  end

  describe "list_for_month/1" do
    test "returns all budgets for the given month" do
      Budgets.set_limit(%{category: "Dining", year_month: "2026-06", limit: "300"})
      Budgets.set_limit(%{category: "Travel", year_month: "2026-06", limit: "500"})
      Budgets.set_limit(%{category: "Dining", year_month: "2026-07", limit: "200"})

      june = Budgets.list_for_month("2026-06")
      assert length(june) == 2
      assert Enum.all?(june, &(&1.year_month == "2026-06"))
    end

    test "returns empty list when no budgets for month" do
      assert [] = Budgets.list_for_month("2000-01")
    end
  end

  describe "get_for/2" do
    test "returns the budget for a category and month" do
      Budgets.set_limit(@valid_attrs)
      assert %Budget{category: "Dining", year_month: "2026-06"} =
               Budgets.get_for("Dining", "2026-06")
    end

    test "returns nil when budget does not exist" do
      assert nil == Budgets.get_for("NoSuch", "2099-01")
    end

    test "returns nil for different month" do
      Budgets.set_limit(@valid_attrs)
      assert nil == Budgets.get_for("Dining", "2026-07")
    end
  end

  describe "change/2" do
    test "returns a valid changeset for valid attrs" do
      cs = Budgets.change(%Budget{}, @valid_attrs)
      assert cs.valid?
    end

    test "returns an invalid changeset for missing required fields" do
      cs = Budgets.change(%Budget{}, %{})
      refute cs.valid?
    end
  end
end
