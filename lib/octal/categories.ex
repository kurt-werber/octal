defmodule Octal.Categories do
  @moduledoc "Context for managing spending categories."

  import Ecto.Query
  alias Octal.Categories.Category
  alias Octal.Repo

  @defaults [
    {"Dining", "#ef4444"},
    {"Groceries", "#22c55e"},
    {"Entertainment", "#a855f7"},
    {"Travel", "#0ea5e9"},
    {"Transport", "#f97316"},
    {"Utilities", "#eab308"},
    {"Rent", "#6366f1"},
    {"Shopping", "#ec4899"},
    {"Health", "#14b8a6"},
    {"Other", "#64748b"}
  ]

  @doc "Idempotently insert the built-in categories on first boot."
  def ensure_defaults do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    rows =
      Enum.map(@defaults, fn {name, color} ->
        %{
          id: Ecto.UUID.generate(),
          name: name,
          color: color,
          is_default: true,
          inserted_at: now,
          updated_at: now
        }
      end)

    Repo.insert_all(Category, rows, on_conflict: :nothing, conflict_target: :name)
    :ok
  end

  def list do
    Repo.all(from c in Category, order_by: c.name)
  end

  def names, do: Enum.map(list(), & &1.name)

  def get(id), do: Repo.get(Category, id)

  def get_by_name(name), do: Repo.get_by(Category, name: name)

  def change(category \\ %Category{}, attrs \\ %{}) do
    Category.changeset(category, attrs)
  end

  def create(attrs) do
    %Category{}
    |> Category.changeset(attrs)
    |> Repo.insert()
  end

  def update(%Category{name: old_name} = category, attrs) do
    result =
      category
      |> Category.changeset(attrs)
      |> Repo.update()

    with {:ok, %Category{name: new_name}} <- result do
      if new_name != old_name do
        # Cascade rename so reports stay consistent.
        from(t in Octal.Transactions.Transaction, where: t.category == ^old_name)
        |> Repo.update_all(set: [category: new_name])

        from(b in Octal.Budgets.Budget, where: b.category == ^old_name)
        |> Repo.update_all(set: [category: new_name])
      end
    end

    result
  end

  def delete(%Category{is_default: true}), do: {:error, :is_default}

  def delete(%Category{name: name} = category) do
    in_use? =
      Repo.exists?(
        from t in Octal.Transactions.Transaction, where: t.category == ^name
      )

    if in_use? do
      {:error, :in_use}
    else
      case Repo.delete(category) do
        {:ok, _} -> :ok
        other -> other
      end
    end
  end
end
