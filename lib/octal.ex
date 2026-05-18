defmodule Octal do
  @moduledoc """
  Octal — a personal finance tracker backed by Postgres and Claude.

  Top-level contexts:

    * `Octal.Categories` — manage spending categories
    * `Octal.Transactions` — record and query transactions
    * `Octal.Budgets` — monthly per-category limits
    * `Octal.Analytics` — Ecto aggregations powering charts
    * `Octal.AI` — Anthropic Claude integration
  """
end
