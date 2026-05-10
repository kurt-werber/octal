defmodule Octal.MongoHelpers do
  @moduledoc """
  Small helpers for working with MongoDB at the LiveView/form boundary.

  ObjectIds become hex strings on the way out (so they fit cleanly in URLs
  and hidden form fields) and are decoded back on the way in. Money values
  use BSON Decimal128 in storage and Elixir `Decimal` everywhere else.
  """

  alias BSON.ObjectId

  @doc "Coerce a hex string or ObjectId into a `BSON.ObjectId` for queries."
  def to_oid(%ObjectId{} = oid), do: oid
  def to_oid(<<hex::binary-size(24)>>), do: ObjectId.decode!(hex)

  @doc "Convert a `BSON.ObjectId` (or already-string id) to a hex string."
  def from_oid(%ObjectId{} = oid), do: ObjectId.encode!(oid)
  def from_oid(<<hex::binary-size(24)>>), do: hex
  def from_oid(nil), do: nil

  @doc """
  Convert a Mongo document into a plain Elixir map suitable for forms/views.

    * `_id` is renamed to `:id` and stringified
    * Decimal128 values become `Decimal`
    * date fields stay as `DateTime`
  """
  def document_to_map(nil), do: nil

  def document_to_map(%{} = doc) do
    doc
    |> Enum.map(&normalize_pair/1)
    |> Map.new()
  end

  defp normalize_pair({"_id", oid}), do: {:id, from_oid(oid)}
  defp normalize_pair({k, v}) when is_binary(k), do: {String.to_atom(k), normalize_value(v)}
  defp normalize_pair({k, v}), do: {k, normalize_value(v)}

  defp normalize_value(%Decimal{} = d), do: d
  defp normalize_value(%DateTime{} = dt), do: dt
  defp normalize_value(%{} = m) when not is_struct(m), do: document_to_map(m)
  defp normalize_value(list) when is_list(list), do: Enum.map(list, &normalize_value/1)
  defp normalize_value(other), do: other

  @doc """
  Coerce a value into an Elixir `Decimal` suitable for storage. The
  mongodb_driver BSON encoder serializes `%Decimal{}` natively as Decimal128.
  """
  def to_decimal(%Decimal{} = d), do: d
  def to_decimal(value) when is_integer(value), do: Decimal.new(value)
  def to_decimal(value) when is_float(value), do: value |> Float.to_string() |> Decimal.new()
  def to_decimal(value) when is_binary(value), do: Decimal.new(value)

  @doc """
  Convert any of the shapes Mongo might return for a money field into an
  Elixir `Decimal`. Tolerates `nil` and `%Decimal{}` (mongodb_driver decodes
  BSON Decimal128 straight to `%Decimal{}`).
  """
  def decimal_of(nil), do: nil
  def decimal_of(%Decimal{} = d), do: d
  def decimal_of(value) when is_integer(value), do: Decimal.new(value)
  def decimal_of(value) when is_float(value), do: value |> Float.to_string() |> Decimal.new()
  def decimal_of(value) when is_binary(value), do: Decimal.new(value)

  @doc "Build the year_month string (\"YYYY-MM\") from a Date or DateTime."
  def year_month(%Date{year: y, month: m}), do: pad_ym(y, m)
  def year_month(%DateTime{year: y, month: m}), do: pad_ym(y, m)
  def year_month(%NaiveDateTime{year: y, month: m}), do: pad_ym(y, m)

  def year_month(nil) do
    today = Date.utc_today()
    pad_ym(today.year, today.month)
  end

  defp pad_ym(y, m), do: :io_lib.format("~4..0B-~2..0B", [y, m]) |> IO.iodata_to_binary()

  @doc "Create idempotent indexes on the collections we read from."
  def ensure_indexes do
    create_index("transactions", [{"date", -1}])
    create_index("transactions", [{"vendor", 1}])
    create_index("transactions", [{"category", 1}, {"date", -1}])
    create_index("budgets", [{"category", 1}, {"year_month", 1}], unique: true)
    create_index("categories", [{"name", 1}], unique: true)
    :ok
  end

  defp create_index(coll, keys, opts \\ []) do
    spec = %{
      "key" => Map.new(keys, fn {k, v} -> {k, v} end),
      "name" => Enum.map_join(keys, "_", fn {k, v} -> "#{k}_#{v}" end)
    }

    spec = if opts[:unique], do: Map.put(spec, "unique", true), else: spec

    Mongo.command(:mongo, %{"createIndexes" => coll, "indexes" => [spec]})
  end
end
