defmodule Octal.Budgets do
  @moduledoc "Per-category, per-month budget context."

  import Ecto.Query
  alias Octal.Budgets.Budget
  alias Octal.Repo

  def list_for_month(year_month) when is_binary(year_month) do
    Repo.all(from b in Budget, where: b.year_month == ^year_month)
  end

  def get_for(category, year_month) do
    Repo.get_by(Budget, category: category, year_month: year_month)
  end

  @doc """
  Upsert a single category's limit for a month.
  """
  def set_limit(attrs) do
    %Budget{}
    |> Budget.changeset(attrs)
    |> Repo.insert(
      on_conflict: {:replace, [:limit, :updated_at]},
      conflict_target: [:category, :year_month]
    )
  end

  def change(budget \\ %Budget{}, attrs \\ %{}), do: Budget.changeset(budget, attrs)
end
