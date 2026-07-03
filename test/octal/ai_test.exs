defmodule Octal.AITest do
  use Octal.DataCase, async: true

  alias Octal.AI
  alias Octal.Transactions

  describe "suggest_amount/1" do
    test "returns history-based amount when vendor has past transactions" do
      Transactions.create(%{
        date: ~D[2026-06-01],
        vendor: "TestCafe",
        amount: "12.50",
        category: "Dining"
      })

      assert {:ok, amount, :history} = AI.suggest_amount("TestCafe")
      assert Decimal.equal?(amount, Decimal.new("12.50"))
    end

    test "uses the median, not just the last amount" do
      for amt <- ["5.00", "10.00", "15.00"] do
        Transactions.create(%{date: ~D[2026-06-01], vendor: "MedianShop", amount: amt, category: "Shopping"})
      end

      assert {:ok, amount, :history} = AI.suggest_amount("MedianShop")
      assert Decimal.equal?(amount, Decimal.new("10.00"))
    end

    test "falls through to AI (missing API key) when no history exists" do
      # In test env, ANTHROPIC_API_KEY is not configured.
      assert {:error, :missing_api_key} = AI.suggest_amount("BrandNewVendor")
    end

    test "returns error for nil vendor" do
      assert {:error, :invalid_vendor} = AI.suggest_amount(nil)
    end

    test "returns error for non-binary vendor" do
      assert {:error, :invalid_vendor} = AI.suggest_amount(42)
    end
  end

  describe "analyze/2" do
    test "returns error when API key is not configured" do
      assert {:error, :missing_api_key} = AI.analyze([], [])
    end

    test "accepts transaction and budget lists without crashing" do
      txns = [%{date: ~D[2026-06-01], category: "Dining", amount: "25.00", vendor: "Cafe"}]
      budgets = [%{category: "Dining", limit: "200"}]
      # No API key in test env
      assert {:error, :missing_api_key} = AI.analyze(txns, budgets)
    end
  end
end
