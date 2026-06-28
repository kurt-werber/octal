defmodule OctalWeb.TransactionsLiveTest do
  use OctalWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  setup do
    Octal.Categories.ensure_defaults()
    :ok
  end

  describe "index" do
    test "renders the transactions page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")
      assert html =~ "Transactions"
    end

    test "shows empty-state row when no transactions exist", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")
      assert html =~ "No transactions yet"
    end

    test "lists existing transactions", %{conn: conn} do
      {:ok, _} =
        Octal.Transactions.create(%{
          date: ~D[2026-06-15],
          vendor: "Starbucks",
          amount: "5.75",
          category: "Dining"
        })

      {:ok, _view, html} = live(conn, ~p"/")
      assert html =~ "Starbucks"
    end
  end

  describe "new transaction" do
    test "opens the new-transaction form", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/transactions/new")
      assert html =~ "New transaction"
    end

    test "saves a valid transaction and shows it in the list", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/transactions/new")

      view
      |> form("#transaction-form", %{
        "transaction" => %{
          "date" => "2026-06-15",
          "vendor" => "Whole Foods",
          "amount" => "45.00",
          "category" => "Groceries",
          "note" => ""
        }
      })
      |> render_submit()

      assert_patch(view, ~p"/")
      assert render(view) =~ "Whole Foods"
    end

    test "shows validation errors on invalid submission", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/transactions/new")

      html =
        view
        |> form("#transaction-form", %{
          "transaction" => %{
            "date" => "",
            "vendor" => "",
            "amount" => "",
            "category" => "Dining"
          }
        })
        |> render_submit()

      assert html =~ "can&#39;t be blank"
    end

    test "shows error for non-positive amount", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/transactions/new")

      html =
        view
        |> form("#transaction-form", %{
          "transaction" => %{
            "date" => "2026-06-01",
            "vendor" => "Vendor",
            "amount" => "0",
            "category" => "Dining"
          }
        })
        |> render_submit()

      assert html =~ "must be greater than"
    end
  end

  describe "edit transaction" do
    setup do
      {:ok, txn} =
        Octal.Transactions.create(%{
          date: ~D[2026-06-15],
          vendor: "OldVendor",
          amount: "20.00",
          category: "Dining"
        })

      %{txn: txn}
    end

    test "renders form pre-filled with existing values", %{conn: conn, txn: txn} do
      {:ok, _view, html} = live(conn, ~p"/transactions/#{txn.id}/edit")
      assert html =~ "OldVendor"
    end

    test "updates the transaction", %{conn: conn, txn: txn} do
      {:ok, view, _html} = live(conn, ~p"/transactions/#{txn.id}/edit")

      view
      |> form("#transaction-form", %{
        "transaction" => %{
          "date" => "2026-06-15",
          "vendor" => "NewVendor",
          "amount" => "25.00",
          "category" => "Dining",
          "note" => ""
        }
      })
      |> render_submit()

      assert_patch(view, ~p"/")
      assert render(view) =~ "NewVendor"
    end

    test "redirects to index for unknown id", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/transactions/#{Ecto.UUID.generate()}/edit")
      assert_redirect(view, ~p"/")
    end
  end

  describe "delete transaction" do
    test "removes the transaction from the list", %{conn: conn} do
      {:ok, txn} =
        Octal.Transactions.create(%{
          date: ~D[2026-06-15],
          vendor: "DeleteMe",
          amount: "10.00",
          category: "Dining"
        })

      {:ok, view, html} = live(conn, ~p"/")
      assert html =~ "DeleteMe"

      view
      |> element("button[phx-click='delete'][phx-value-id='#{txn.id}']")
      |> render_click()

      refute render(view) =~ "DeleteMe"
    end
  end
end
