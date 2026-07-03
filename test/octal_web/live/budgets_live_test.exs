defmodule OctalWeb.BudgetsLiveTest do
  use OctalWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  setup do
    Octal.Categories.ensure_defaults()
    :ok
  end

  describe "index" do
    test "renders the budgets page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/budgets")
      assert html =~ "Budgets"
    end

    test "lists all default categories", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/budgets")
      assert html =~ "Dining"
      assert html =~ "Groceries"
      assert html =~ "Travel"
    end

    test "shows current month by default", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/budgets")
      ym = Octal.Analytics.current_year_month()
      assert html =~ ym
    end

    test "shows existing budget limits", %{conn: conn} do
      ym = Octal.Analytics.current_year_month()
      Octal.Budgets.set_limit(%{category: "Dining", year_month: ym, limit: "350.00"})

      {:ok, _view, html} = live(conn, ~p"/budgets")
      assert html =~ "350"
    end
  end

  describe "saving a budget" do
    test "saves a budget limit via the row form", %{conn: conn} do
      ym = Octal.Analytics.current_year_month()
      {:ok, view, _html} = live(conn, ~p"/budgets")

      view
      |> element("form[phx-submit='save_row']")
      |> render_submit(%{"category" => "Dining", "limit" => "400.00"})

      assert render(view) =~ "400"
      assert Octal.Budgets.get_for("Dining", ym) != nil
    end

    test "shows flash error for invalid limit", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/budgets")

      html =
        view
        |> element("form[phx-submit='save_row']")
        |> render_submit(%{"category" => "Dining", "limit" => "-100"})

      assert html =~ "Couldn&#39;t save" or html =~ "Couldn't save"
    end
  end

  describe "changing month" do
    test "re-renders with the new month's data", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/budgets")

      render_change(view, "change_month", %{"year_month" => "2025-01"})
      assert render(view) =~ "2025-01"
    end

    test "ignores invalid month format", %{conn: conn} do
      {:ok, view, html_before} = live(conn, ~p"/budgets")
      render_change(view, "change_month", %{"year_month" => "not-a-month"})
      # Page stays stable — same categories visible
      assert render(view) =~ "Dining"
    end
  end
end
