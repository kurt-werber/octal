defmodule Octal.Categories do
  @moduledoc "Context for managing spending categories."

  alias Octal.Categories.Category
  alias Octal.MongoHelpers

  @collection "categories"

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
    for {name, color} <- @defaults do
      Mongo.update_one(
        :mongo,
        @collection,
        %{"name" => name},
        %{"$setOnInsert" => %{"name" => name, "color" => color, "is_default" => true}},
        upsert: true
      )
    end

    :ok
  end

  def list do
    :mongo
    |> Mongo.find(@collection, %{}, sort: %{"name" => 1})
    |> Enum.map(&MongoHelpers.document_to_map/1)
  end

  def names do
    Enum.map(list(), & &1.name)
  end

  def get(id) do
    :mongo
    |> Mongo.find_one(@collection, %{"_id" => MongoHelpers.to_oid(id)})
    |> MongoHelpers.document_to_map()
  end

  def get_by_name(name) do
    :mongo
    |> Mongo.find_one(@collection, %{"name" => name})
    |> MongoHelpers.document_to_map()
  end

  def change(category \\ %Category{}, attrs \\ %{}) do
    Category.changeset(category, attrs)
  end

  def create(attrs) do
    with {:ok, %Category{} = cat} <- attrs |> change() |> Ecto.Changeset.apply_action(:insert),
         doc = %{"name" => cat.name, "color" => cat.color, "is_default" => false},
         {:ok, %{inserted_id: oid}} <- Mongo.insert_one(:mongo, @collection, doc) do
      {:ok,
       %{
         id: MongoHelpers.from_oid(oid),
         name: cat.name,
         color: cat.color,
         is_default: false
       }}
    end
  end

  def update(%{id: id, name: old_name}, attrs) do
    cs = change(%Category{id: id, name: old_name}, attrs)

    with {:ok, %Category{} = cat} <- Ecto.Changeset.apply_action(cs, :update) do
      Mongo.update_one(
        :mongo,
        @collection,
        %{"_id" => MongoHelpers.to_oid(id)},
        %{"$set" => %{"name" => cat.name, "color" => cat.color}}
      )

      if old_name && old_name != cat.name do
        # Cascade rename to transactions and budgets so reports stay consistent.
        Mongo.update_many(:mongo, "transactions", %{"category" => old_name}, %{
          "$set" => %{"category" => cat.name}
        })

        Mongo.update_many(:mongo, "budgets", %{"category" => old_name}, %{
          "$set" => %{"category" => cat.name}
        })
      end

      {:ok, get(id)}
    end
  end

  def delete(%{id: id, name: name, is_default: is_default}) do
    cond do
      is_default ->
        {:error, :is_default}

      Mongo.count_documents!(:mongo, "transactions", %{"category" => name}) > 0 ->
        {:error, :in_use}

      true ->
        Mongo.delete_one(:mongo, @collection, %{"_id" => MongoHelpers.to_oid(id)})
        :ok
    end
  end
end
