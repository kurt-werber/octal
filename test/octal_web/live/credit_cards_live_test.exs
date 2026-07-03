defmodule OctalWeb.CreditCardsLiveTest do
  use OctalWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Octal.CreditCards

  describe "index" do
    test "renders empty state with no cards", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/credit-cards")
      assert html =~ "Credit Cards"
    end

    test "lists a card with its computed annual value", %{conn: conn} do
      CreditCards.create_card(%{"name" => "Amex"}, "amex_gold")
      {:ok, _view, html} = live(conn, ~p"/credit-cards")

      assert html =~ "Amex"
      # 10*12 + 10*12 + 50*2 = 340
      assert html =~ "$340.00/yr"
    end
  end

  describe "new card" do
    test "shows the template picker with Custom and Amex Gold options", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/credit-cards/new")
      assert html =~ "Add credit card"
      assert html =~ "Custom"
      assert html =~ "American Express Gold"
    end

    test "picking the Amex Gold template and saving creates the card and its benefits", %{
      conn: conn
    } do
      {:ok, view, _html} = live(conn, ~p"/credit-cards/new")

      view
      |> element("select[name='template_key']")
      |> render_change(%{"template_key" => "amex_gold"})

      view
      |> form("form[phx-submit='save']", %{"credit_card" => %{"name" => "My Amex Gold"}})
      |> render_submit()

      assert_patch(view, ~p"/credit-cards")
      html = render(view)
      assert html =~ "My Amex Gold"
      assert html =~ "3 benefits"

      card = CreditCards.list_cards_with_benefits() |> Enum.find(&(&1.name == "My Amex Gold"))
      {:ok, _show_view, show_html} = live(conn, ~p"/credit-cards/#{card.id}")
      assert show_html =~ "Uber Cash"
      assert show_html =~ "Dining Credit"
      assert show_html =~ "Resy Credit"
    end

    test "picking Custom creates a card with no benefits", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/credit-cards/new")

      view
      |> form("form[phx-submit='save']", %{"credit_card" => %{"name" => "Blank Card"}})
      |> render_submit()

      assert_patch(view, ~p"/credit-cards")
      assert render(view) =~ "0 benefits"
    end

    test "shows validation error for empty name", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/credit-cards/new")

      html =
        view
        |> form("form[phx-submit='save']", %{"credit_card" => %{"name" => ""}})
        |> render_submit()

      assert html =~ "can&#39;t be blank"
    end
  end

  describe "edit card" do
    setup do
      {:ok, card} = CreditCards.create_card(%{"name" => "EditMe"})
      %{card: card}
    end

    test "opens the edit form pre-filled", %{conn: conn, card: card} do
      {:ok, _view, html} = live(conn, ~p"/credit-cards/#{card.id}/edit")
      assert html =~ "EditMe"
      assert html =~ "Edit credit card"
    end

    test "updates the card", %{conn: conn, card: card} do
      {:ok, view, _html} = live(conn, ~p"/credit-cards/#{card.id}/edit")

      view
      |> form("form[phx-submit='save']", %{"credit_card" => %{"name" => "Renamed"}})
      |> render_submit()

      assert_patch(view, ~p"/credit-cards")
      assert render(view) =~ "Renamed"
    end

    test "redirects to index for unknown id", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/credit-cards/#{Ecto.UUID.generate()}/edit")
      assert_redirect(view, ~p"/credit-cards")
    end
  end

  describe "delete card" do
    test "removes a card from the list", %{conn: conn} do
      {:ok, card} = CreditCards.create_card(%{"name" => "Temporary"})
      {:ok, view, html} = live(conn, ~p"/credit-cards")
      assert html =~ "Temporary"

      view
      |> element("button[phx-click='delete'][phx-value-id='#{card.id}']")
      |> render_click()

      refute render(view) =~ "Temporary"
    end
  end

  describe "show" do
    setup do
      {:ok, card} = CreditCards.create_card(%{"name" => "Amex"}, "amex_gold")
      benefits = CreditCards.list_benefits(card.id)
      %{card: card, benefits: benefits}
    end

    test "renders the card and its benefits", %{conn: conn, card: card} do
      {:ok, _view, html} = live(conn, ~p"/credit-cards/#{card.id}")
      assert html =~ "Amex"
      assert html =~ "Uber Cash"
      assert html =~ "Dining Credit"
      assert html =~ "Resy Credit"
      assert html =~ "Monthly"
      assert html =~ "Semi-annual"
    end

    test "benefit row defaults to not-used and toggling flips it", %{
      conn: conn,
      card: card,
      benefits: benefits
    } do
      [benefit | _] = benefits
      {:ok, view, html} = live(conn, ~p"/credit-cards/#{card.id}")

      assert html =~ "Mark used"

      html =
        view
        |> element("button[phx-click='toggle_usage'][phx-value-id='#{benefit.id}']")
        |> render_click()

      assert html =~ "Used this period"

      html =
        view
        |> element("button[phx-click='toggle_usage'][phx-value-id='#{benefit.id}']")
        |> render_click()

      assert html =~ "Mark used"
    end

    test "redirects to index for unknown card id", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/credit-cards/#{Ecto.UUID.generate()}")
      assert_redirect(view, ~p"/credit-cards")
    end

    test "adding a benefit shows validation error for zero amount", %{conn: conn, card: card} do
      {:ok, view, _html} = live(conn, ~p"/credit-cards/#{card.id}/benefits/new")

      html =
        view
        |> form("form[phx-submit='save']", %{
          "benefit" => %{"name" => "Bad", "amount" => "0", "frequency" => "monthly"}
        })
        |> render_submit()

      assert html =~ "must be greater than"
    end

    test "editing and deleting a benefit", %{conn: conn, card: card, benefits: benefits} do
      [benefit | _] = benefits
      {:ok, view, _html} = live(conn, ~p"/credit-cards/#{card.id}/benefits/#{benefit.id}/edit")

      view
      |> form("form[phx-submit='save']", %{
        "benefit" => %{"name" => "Renamed Benefit", "amount" => "15", "frequency" => "monthly"}
      })
      |> render_submit()

      assert_patch(view, ~p"/credit-cards/#{card.id}")
      html = render(view)
      assert html =~ "Renamed Benefit"

      view
      |> element("button[phx-click='delete_benefit'][phx-value-id='#{benefit.id}']")
      |> render_click()

      refute render(view) =~ "Renamed Benefit"
    end
  end
end
