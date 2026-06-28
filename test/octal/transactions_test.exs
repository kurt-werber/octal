defmodule Octal.TransactionsTest do
  use Octal.DataCase, async: true

  alias Octal.Transactions
  alias Octal.Transactions.Transaction

  @valid_attrs %{
    date: ~D[2026-06-15],
    vendor: "Starbucks",
    amount: "5.75",
    category: "Dining"
  }

  describe "create/1" do
    test "creates a transaction with valid attrs" do
      assert {:ok, %Transaction{vendor: "Starbucks"}} = Transactions.create(@valid_attrs)
    end

    test "persists amount as decimal" do
      {:ok, txn} = Transactions.create(@valid_attrs)
      assert %Decimal{} = txn.amount
      assert Decimal.equal?(txn.amount, Decimal.new("5.75"))
    end

    test "trims whitespace from vendor" do
      attrs = Map.put(@valid_attrs, :vendor, "  Starbucks  ")
      assert {:ok, %Transaction{vendor: "Starbucks"}} = Transactions.create(attrs)
    end

    test "allows a note" do
      attrs = Map.put(@valid_attrs, :note, "work expense")
      assert {:ok, %Transaction{note: "work expense"}} = Transactions.create(attrs)
    end

    test "returns error changeset for missing required fields" do
      assert {:error, cs} = Transactions.create(%{})
      errors = errors_on(cs)
      assert Map.has_key?(errors, :date)
      assert Map.has_key?(errors, :vendor)
      assert Map.has_key?(errors, :amount)
      assert Map.has_key?(errors, :category)
    end

    test "returns error for zero amount" do
      assert {:error, cs} = Transactions.create(Map.put(@valid_attrs, :amount, "0"))
      assert %{amount: [_ | _]} = errors_on(cs)
    end

    test "returns error for negative amount" do
      assert {:error, cs} = Transactions.create(Map.put(@valid_attrs, :amount, "-1.00"))
      assert %{amount: [_ | _]} = errors_on(cs)
    end

    test "returns error for vendor exceeding max length" do
      long_vendor = String.duplicate("x", 101)
      assert {:error, cs} = Transactions.create(Map.put(@valid_attrs, :vendor, long_vendor))
      assert %{vendor: [_ | _]} = errors_on(cs)
    end
  end

  describe "list/1" do
    setup do
      {:ok, t1} =
        Transactions.create(%{date: ~D[2026-06-10], vendor: "A", amount: "10", category: "Dining"})

      {:ok, t2} =
        Transactions.create(%{date: ~D[2026-06-20], vendor: "B", amount: "20", category: "Travel"})

      {:ok, t3} =
        Transactions.create(%{date: ~D[2026-05-15], vendor: "C", amount: "30", category: "Dining"})

      %{t1: t1, t2: t2, t3: t3}
    end

    test "returns all transactions ordered by date desc" do
      results = Transactions.list()
      dates = Enum.map(results, & &1.date)
      assert dates == Enum.sort(dates, {:desc, Date})
    end

    test ":limit caps the number of results" do
      assert length(Transactions.list(limit: 2)) == 2
    end

    test ":from excludes transactions before the date", %{t3: t3} do
      results = Transactions.list(from: ~D[2026-06-01])
      refute Enum.any?(results, &(&1.id == t3.id))
    end

    test ":to excludes transactions after the date", %{t2: t2} do
      results = Transactions.list(to: ~D[2026-06-15])
      refute Enum.any?(results, &(&1.id == t2.id))
    end

    test ":from and :to together narrow the range", %{t1: t1, t2: t2, t3: t3} do
      results = Transactions.list(from: ~D[2026-06-10], to: ~D[2026-06-10])
      ids = Enum.map(results, & &1.id)
      assert t1.id in ids
      refute t2.id in ids
      refute t3.id in ids
    end

    test ":category filters by category" do
      results = Transactions.list(category: "Dining")
      assert Enum.all?(results, &(&1.category == "Dining"))
      assert length(results) == 2
    end
  end

  describe "get/1" do
    test "returns transaction by valid UUID" do
      {:ok, txn} = Transactions.create(@valid_attrs)
      assert %Transaction{vendor: "Starbucks"} = Transactions.get(txn.id)
    end

    test "returns nil for unknown UUID" do
      assert nil == Transactions.get(Ecto.UUID.generate())
    end

    test "returns nil for malformed id" do
      assert nil == Transactions.get("not-a-uuid")
    end

    test "returns nil for nil" do
      assert nil == Transactions.get(nil)
    end
  end

  describe "update/2" do
    test "updates amount and category" do
      {:ok, txn} = Transactions.create(@valid_attrs)
      assert {:ok, updated} = Transactions.update(txn, %{amount: "9.99", category: "Shopping"})
      assert Decimal.equal?(updated.amount, Decimal.new("9.99"))
      assert updated.category == "Shopping"
    end

    test "returns error changeset for invalid update" do
      {:ok, txn} = Transactions.create(@valid_attrs)
      assert {:error, cs} = Transactions.update(txn, %{amount: "-5"})
      assert %{amount: [_ | _]} = errors_on(cs)
    end
  end

  describe "delete/1" do
    test "deletes by struct" do
      {:ok, txn} = Transactions.create(@valid_attrs)
      :ok = Transactions.delete(txn)
      assert nil == Transactions.get(txn.id)
    end

    test "deletes by id string" do
      {:ok, txn} = Transactions.create(@valid_attrs)
      :ok = Transactions.delete(txn.id)
      assert nil == Transactions.get(txn.id)
    end

    test "returns :ok for missing id — idempotent" do
      assert :ok = Transactions.delete(Ecto.UUID.generate())
    end
  end

  describe "median_for_vendor/1" do
    test "returns nil when vendor has no history" do
      assert nil == Transactions.median_for_vendor("UnknownVendor")
    end

    test "returns the amount when only one transaction" do
      Transactions.create(%{date: ~D[2026-06-01], vendor: "OneTxn", amount: "8.50", category: "Dining"})
      result = Transactions.median_for_vendor("OneTxn")
      assert %Decimal{} = result
      assert Decimal.equal?(result, Decimal.new("8.50"))
    end

    test "returns median of multiple amounts" do
      for amount <- ["4.00", "8.00", "12.00"] do
        Transactions.create(%{
          date: ~D[2026-06-01],
          vendor: "MedianCafe",
          amount: amount,
          category: "Dining"
        })
      end

      result = Transactions.median_for_vendor("MedianCafe")
      assert %Decimal{} = result
      assert Decimal.equal?(result, Decimal.new("8.00"))
    end

    test "is case-insensitive" do
      Transactions.create(%{date: ~D[2026-06-01], vendor: "CafeCase", amount: "7.00", category: "Dining"})
      assert %Decimal{} = Transactions.median_for_vendor("cafeCASE")
      assert %Decimal{} = Transactions.median_for_vendor("CAFECASE")
    end

    test "returns nil for nil input" do
      assert nil == Transactions.median_for_vendor(nil)
    end

    test "returns nil for non-binary input" do
      assert nil == Transactions.median_for_vendor(123)
    end
  end

  describe "change/2" do
    test "returns a valid changeset for valid attrs" do
      cs = Transactions.change(%Transaction{date: Date.utc_today()}, @valid_attrs)
      assert cs.valid?
    end

    test "returns an invalid changeset for empty attrs" do
      cs = Transactions.change(%Transaction{}, %{})
      refute cs.valid?
    end
  end
end
