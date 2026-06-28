defmodule OctalWeb.CategoriesLiveTest do
  use OctalWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  describe "index" do
    test "renders the categories page", %{conn: conn} do
      Octal.Categories.ensure_defaults()
      {:ok, _view, html} = live(conn, ~p"/categories")
      assert html =~ "Categories"
      assert html =~ "Dining"
    end

    test "shows default badge on built-in categories", %{conn: conn} do
      Octal.Categories.ensure_defaults()
      {:ok, _view, html} = live(conn, ~p"/categories")
      assert html =~ "default"
    end
  end

  describe "new category" do
    test "opens the new-category form", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/categories/new")
      assert html =~ "Add category"
    end

    test "creates a category and returns to the list", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/categories/new")

      view
      |> form("form[phx-submit='save']", %{
        "category" => %{"name" => "Pets", "color" => "#ff0000"}
      })
      |> render_submit()

      assert_patch(view, ~p"/categories")
      assert render(view) =~ "Pets"
    end

    test "shows validation error for empty name", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/categories/new")

      html =
        view
        |> form("form[phx-submit='save']", %{
          "category" => %{"name" => "", "color" => "#ffffff"}
        })
        |> render_submit()

      assert html =~ "can&#39;t be blank"
    end

    test "shows error for duplicate name", %{conn: conn} do
      Octal.Categories.create(%{name: "Duplicate", color: "#000000"})
      {:ok, view, _html} = live(conn, ~p"/categories/new")

      html =
        view
        |> form("form[phx-submit='save']", %{
          "category" => %{"name" => "Duplicate", "color" => "#ffffff"}
        })
        |> render_submit()

      assert html =~ "has already been taken"
    end
  end

  describe "edit category" do
    setup do
      {:ok, cat} = Octal.Categories.create(%{name: "EditMe", color: "#112233"})
      %{category: cat}
    end

    test "opens the edit form pre-filled", %{conn: conn, category: cat} do
      {:ok, _view, html} = live(conn, ~p"/categories/#{cat.id}/edit")
      assert html =~ "EditMe"
      assert html =~ "Edit category"
    end

    test "updates the category", %{conn: conn, category: cat} do
      {:ok, view, _html} = live(conn, ~p"/categories/#{cat.id}/edit")

      view
      |> form("form[phx-submit='save']", %{
        "category" => %{"name" => "Renamed", "color" => "#aabbcc"}
      })
      |> render_submit()

      assert_patch(view, ~p"/categories")
      assert render(view) =~ "Renamed"
    end

    test "redirects to index for unknown id", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/categories/#{Ecto.UUID.generate()}/edit")
      assert_redirect(view, ~p"/categories")
    end
  end

  describe "delete category" do
    test "removes a custom category from the list", %{conn: conn} do
      {:ok, cat} = Octal.Categories.create(%{name: "Temporary", color: "#999999"})
      {:ok, view, html} = live(conn, ~p"/categories")
      assert html =~ "Temporary"

      view
      |> element("button[phx-click='delete'][phx-value-id='#{cat.id}']")
      |> render_click()

      refute render(view) =~ "Temporary"
    end

    test "shows flash error when trying to delete a default category", %{conn: conn} do
      Octal.Categories.ensure_defaults()
      dining = Octal.Categories.get_by_name("Dining")

      {:ok, view, _html} = live(conn, ~p"/categories")

      # Default categories don't show a delete button; trigger the event directly
      # to verify the server-side guard works.
      html = render_click(view, "delete", %{"id" => dining.id})
      assert html =~ "Default categories can&#39;t be deleted"
    end
  end
end
