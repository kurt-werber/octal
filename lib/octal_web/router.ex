defmodule OctalWeb.Router do
  use OctalWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {OctalWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  scope "/", OctalWeb do
    pipe_through :browser

    live "/", TransactionsLive.Index, :index
    live "/transactions/new", TransactionsLive.Index, :new
    live "/transactions/:id/edit", TransactionsLive.Index, :edit

    live "/budgets", BudgetsLive.Index, :index

    live "/categories", CategoriesLive.Index, :index
    live "/categories/new", CategoriesLive.Index, :new
    live "/categories/:id/edit", CategoriesLive.Index, :edit

    live "/credit-cards", CreditCardsLive.Index, :index
    live "/credit-cards/new", CreditCardsLive.Index, :new
    live "/credit-cards/:id/edit", CreditCardsLive.Index, :edit

    live "/credit-cards/:id", CreditCardsLive.Show, :show
    live "/credit-cards/:id/benefits/new", CreditCardsLive.Show, :new_benefit
    live "/credit-cards/:id/benefits/:benefit_id/edit", CreditCardsLive.Show, :edit_benefit

    live "/visualize", VisualizationsLive.Index, :index
    live "/insights", AiAnalyticsLive.Index, :index
  end
end
