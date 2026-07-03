defmodule Octal.CreditCards do
  @moduledoc "Context for credit cards, their recurring benefits, and per-period usage tracking."

  import Ecto.Query
  alias Octal.CreditCards.{Benefit, BenefitUsage, CreditCard}
  alias Octal.Repo

  @templates %{
    "amex_gold" => %{
      label: "American Express Gold",
      card_name: "American Express Gold",
      benefits: [
        %{name: "Uber Cash", amount: Decimal.new("10.00"), frequency: :monthly},
        %{name: "Dining Credit", amount: Decimal.new("10.00"), frequency: :monthly},
        %{name: "Resy Credit", amount: Decimal.new("50.00"), frequency: :semi_annual}
      ]
    }
  }

  @doc "List available templates for the picker as {key, label} pairs."
  def templates, do: Enum.map(@templates, fn {key, t} -> {key, t.label} end)

  @doc "Suggested card name for a template key, or nil for \"custom\"/unknown keys."
  def template_card_name(key), do: get_in(@templates, [key, :card_name])

  # ---- Credit card CRUD ----

  def list_cards_with_benefits do
    Repo.all(from c in CreditCard, order_by: c.name) |> Repo.preload(:benefits)
  end

  def get_card(id), do: Repo.get(CreditCard, id)

  def get_card_with_benefits(id) do
    CreditCard |> Repo.get(id) |> Repo.preload(benefits: :benefit_usages)
  end

  def change_card(card \\ %CreditCard{}, attrs \\ %{}), do: CreditCard.changeset(card, attrs)

  @doc """
  Create a card, optionally applying a template's benefit rows in the same transaction.
  `template_key` is nil/"custom" (no benefits inserted) or a key from templates/0.
  """
  def create_card(attrs, template_key \\ nil) do
    Repo.transaction(fn ->
      case %CreditCard{} |> CreditCard.changeset(attrs) |> Repo.insert() do
        {:ok, card} ->
          apply_template(card, template_key)
          card

        {:error, changeset} ->
          Repo.rollback(changeset)
      end
    end)
  end

  @doc "Insert the named template's benefit rows for an existing card. No-op for nil/unknown keys."
  def apply_template(%CreditCard{} = card, template_key) do
    case Map.get(@templates, template_key) do
      nil ->
        :ok

      %{benefits: benefit_defs} ->
        now = DateTime.utc_now() |> DateTime.truncate(:second)

        rows =
          Enum.map(benefit_defs, fn b ->
            %{
              id: Ecto.UUID.generate(),
              credit_card_id: card.id,
              name: b.name,
              amount: b.amount,
              frequency: Atom.to_string(b.frequency),
              inserted_at: now,
              updated_at: now
            }
          end)

        Repo.insert_all(Benefit, rows)
        :ok
    end
  end

  def update_card(%CreditCard{} = card, attrs) do
    card |> CreditCard.changeset(attrs) |> Repo.update()
  end

  def delete_card(%CreditCard{} = card), do: Repo.delete(card)

  # ---- Benefit CRUD (scoped to a card) ----

  def list_benefits(card_id) do
    Repo.all(from b in Benefit, where: b.credit_card_id == ^card_id, order_by: b.name)
    |> Repo.preload(:benefit_usages)
  end

  def get_benefit(id), do: Benefit |> Repo.get(id) |> Repo.preload(:benefit_usages)

  def change_benefit(benefit \\ %Benefit{}, attrs \\ %{}), do: Benefit.changeset(benefit, attrs)

  def create_benefit(card_id, attrs) do
    %Benefit{}
    |> Benefit.changeset(Map.put(attrs, "credit_card_id", card_id))
    |> Repo.insert()
  end

  def update_benefit(%Benefit{} = benefit, attrs) do
    benefit |> Benefit.changeset(attrs) |> Repo.update()
  end

  def delete_benefit(%Benefit{} = benefit), do: Repo.delete(benefit)

  @doc "Sum of a card's benefits' amounts normalized to an annual value, for display."
  def annual_value(%CreditCard{benefits: benefits}) when is_list(benefits) do
    Enum.reduce(benefits, Decimal.new(0), fn b, acc ->
      Decimal.add(acc, Decimal.mult(b.amount, occurrences_per_year(b.frequency)))
    end)
  end

  defp occurrences_per_year(:monthly), do: Decimal.new(12)
  defp occurrences_per_year(:quarterly), do: Decimal.new(4)
  defp occurrences_per_year(:semi_annual), do: Decimal.new(2)
  defp occurrences_per_year(:annual), do: Decimal.new(1)

  # ---- Period calculation ----

  @doc "Compute the current period key for a frequency, as of `date` (default today)."
  def current_period_key(frequency, date \\ Date.utc_today())

  def current_period_key(:monthly, date) do
    "#{date.year}-#{pad2(date.month)}"
  end

  def current_period_key(:quarterly, date) do
    quarter = div(date.month - 1, 3) + 1
    "#{date.year}-Q#{quarter}"
  end

  def current_period_key(:semi_annual, date) do
    half = if date.month <= 6, do: 1, else: 2
    "#{date.year}-H#{half}"
  end

  def current_period_key(:annual, date) do
    Integer.to_string(date.year)
  end

  defp pad2(n), do: n |> Integer.to_string() |> String.pad_leading(2, "0")

  # ---- Usage lookup / toggle ----

  @doc "Is this benefit used in its current period?"
  def used_this_period?(%Benefit{} = benefit) do
    period = current_period_key(benefit.frequency)
    Repo.exists?(from u in BenefitUsage, where: u.benefit_id == ^benefit.id and u.period == ^period)
  end

  @doc "Most recent period (by period string) with a usage row, or nil."
  def last_used_period(%Benefit{} = benefit) do
    Repo.one(
      from u in BenefitUsage,
        where: u.benefit_id == ^benefit.id,
        order_by: [desc: u.period],
        limit: 1,
        select: u.period
    )
  end

  @doc """
  Toggle usage for the benefit's current period: insert a usage row if absent,
  delete it if present. Returns {:ok, :used} | {:ok, :unused} | {:error, changeset}.
  """
  def toggle_usage(%Benefit{} = benefit) do
    period = current_period_key(benefit.frequency)

    case Repo.get_by(BenefitUsage, benefit_id: benefit.id, period: period) do
      nil ->
        attrs = %{
          "benefit_id" => benefit.id,
          "period" => period,
          "used_at" => DateTime.utc_now() |> DateTime.truncate(:second)
        }

        case %BenefitUsage{} |> BenefitUsage.changeset(attrs) |> Repo.insert() do
          {:ok, _} -> {:ok, :used}
          {:error, cs} -> {:error, cs}
        end

      %BenefitUsage{} = usage ->
        Repo.delete!(usage)
        {:ok, :unused}
    end
  end
end
