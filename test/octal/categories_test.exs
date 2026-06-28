defmodule Octal.CategoriesTest do
  use Octal.DataCase, async: true

  alias Octal.Categories
  alias Octal.Categories.Category

  describe "ensure_defaults/0" do
    test "inserts 10 built-in categories" do
      :ok = Categories.ensure_defaults()
      assert length(Categories.list()) == 10
    end

    test "is idempotent — calling twice does not duplicate rows" do
      Categories.ensure_defaults()
      Categories.ensure_defaults()
      assert length(Categories.list()) == 10
    end

    test "all defaults have is_default: true" do
      Categories.ensure_defaults()
      assert Enum.all?(Categories.list(), & &1.is_default)
    end
  end

  describe "create/1" do
    test "creates a category with valid attrs" do
      assert {:ok, %Category{name: "Pets"}} = Categories.create(%{name: "Pets", color: "#ff00ff"})
    end

    test "trims whitespace from name" do
      assert {:ok, %Category{name: "Pets"}} =
               Categories.create(%{name: "  Pets  ", color: "#ff00ff"})
    end

    test "defaults color when omitted" do
      assert {:ok, %Category{color: "#" <> _}} = Categories.create(%{name: "NoColor"})
    end

    test "returns error changeset for missing name" do
      assert {:error, cs} = Categories.create(%{color: "#ff00ff"})
      assert %{name: [_ | _]} = errors_on(cs)
    end

    test "returns error changeset for duplicate name" do
      Categories.create(%{name: "Pets", color: "#ff00ff"})
      assert {:error, cs} = Categories.create(%{name: "Pets", color: "#00ff00"})
      assert %{name: [_ | _]} = errors_on(cs)
    end

    test "returns error changeset for invalid color format" do
      assert {:error, cs} = Categories.create(%{name: "Pets", color: "red"})
      assert %{color: [_ | _]} = errors_on(cs)
    end
  end

  describe "update/2" do
    setup do
      {:ok, cat} = Categories.create(%{name: "CustomCat", color: "#123456"})
      %{category: cat}
    end

    test "updates name and color", %{category: cat} do
      assert {:ok, updated} = Categories.update(cat, %{name: "UpdatedCat", color: "#abcdef"})
      assert updated.name == "UpdatedCat"
      assert updated.color == "#abcdef"
    end

    test "cascades rename to transactions", %{category: cat} do
      {:ok, _} =
        Octal.Transactions.create(%{
          date: ~D[2026-06-01],
          vendor: "Shop",
          amount: "50.00",
          category: "CustomCat"
        })

      Categories.update(cat, %{name: "RenamedCat"})
      txns = Octal.Transactions.list()
      assert Enum.all?(txns, &(&1.category == "RenamedCat"))
    end

    test "cascades rename to budgets", %{category: cat} do
      Octal.Budgets.set_limit(%{category: "CustomCat", year_month: "2026-06", limit: "100.00"})
      Categories.update(cat, %{name: "RenamedCat"})

      assert Octal.Budgets.get_for("RenamedCat", "2026-06") != nil
      assert Octal.Budgets.get_for("CustomCat", "2026-06") == nil
    end

    test "no-op cascade when name is unchanged", %{category: cat} do
      Octal.Transactions.create(%{
        date: ~D[2026-06-01],
        vendor: "Shop",
        amount: "10.00",
        category: "CustomCat"
      })

      assert {:ok, _} = Categories.update(cat, %{color: "#654321"})
      assert Enum.all?(Octal.Transactions.list(), &(&1.category == "CustomCat"))
    end

    test "returns error changeset for empty name", %{category: cat} do
      assert {:error, cs} = Categories.update(cat, %{name: ""})
      assert %{name: [_ | _]} = errors_on(cs)
    end
  end

  describe "delete/1" do
    test "refuses to delete a default category" do
      Categories.ensure_defaults()
      dining = Categories.get_by_name("Dining")
      assert {:error, :is_default} = Categories.delete(dining)
    end

    test "refuses to delete a category that has transactions" do
      {:ok, cat} = Categories.create(%{name: "Temp"})

      Octal.Transactions.create(%{
        date: ~D[2026-06-01],
        vendor: "Shop",
        amount: "10.00",
        category: "Temp"
      })

      assert {:error, :in_use} = Categories.delete(cat)
    end

    test "deletes an unused custom category" do
      {:ok, cat} = Categories.create(%{name: "Unused"})
      assert :ok = Categories.delete(cat)
      assert Categories.get(cat.id) == nil
    end
  end

  describe "get/1" do
    test "returns category by id" do
      {:ok, cat} = Categories.create(%{name: "LookupCat", color: "#aabbcc"})
      assert %Category{name: "LookupCat"} = Categories.get(cat.id)
    end

    test "returns nil for unknown id" do
      assert nil == Categories.get(Ecto.UUID.generate())
    end
  end

  describe "get_by_name/1" do
    test "returns category by name" do
      {:ok, _} = Categories.create(%{name: "NameLookup", color: "#aabbcc"})
      assert %Category{name: "NameLookup"} = Categories.get_by_name("NameLookup")
    end

    test "returns nil for unknown name" do
      assert nil == Categories.get_by_name("NoSuchCategory")
    end
  end

  describe "names/0" do
    test "returns a list of category name strings" do
      Categories.ensure_defaults()
      names = Categories.names()
      assert is_list(names)
      assert Enum.all?(names, &is_binary/1)
      assert "Dining" in names
    end
  end
end
