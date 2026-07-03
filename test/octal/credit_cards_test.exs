defmodule Octal.CreditCardsTest do
  use Octal.DataCase, async: true

  alias Octal.CreditCards
  alias Octal.CreditCards.{Benefit, BenefitUsage, CreditCard}
  alias Octal.Repo

  describe "current_period_key/2" do
    test "monthly" do
      assert CreditCards.current_period_key(:monthly, ~D[2026-01-15]) == "2026-01"
      assert CreditCards.current_period_key(:monthly, ~D[2026-12-31]) == "2026-12"
    end

    test "quarterly, including year rollover" do
      assert CreditCards.current_period_key(:quarterly, ~D[2026-03-31]) == "2026-Q1"
      assert CreditCards.current_period_key(:quarterly, ~D[2026-04-01]) == "2026-Q2"
      assert CreditCards.current_period_key(:quarterly, ~D[2026-12-31]) == "2026-Q4"
      assert CreditCards.current_period_key(:quarterly, ~D[2027-01-01]) == "2027-Q1"
    end

    test "semi_annual, including year rollover" do
      assert CreditCards.current_period_key(:semi_annual, ~D[2026-06-30]) == "2026-H1"
      assert CreditCards.current_period_key(:semi_annual, ~D[2026-07-01]) == "2026-H2"
      assert CreditCards.current_period_key(:semi_annual, ~D[2026-12-31]) == "2026-H2"
      assert CreditCards.current_period_key(:semi_annual, ~D[2027-01-01]) == "2027-H1"
    end

    test "annual" do
      assert CreditCards.current_period_key(:annual, ~D[2026-12-31]) == "2026"
      assert CreditCards.current_period_key(:annual, ~D[2027-01-01]) == "2027"
    end

    test "defaults to today's date" do
      today = Date.utc_today()
      assert CreditCards.current_period_key(:annual) == Integer.to_string(today.year)
    end
  end

  describe "create_card/2" do
    test "\"custom\" template creates a card with zero benefits" do
      assert {:ok, card} = CreditCards.create_card(%{"name" => "Custom Card"}, "custom")
      assert Repo.all(from b in Benefit, where: b.credit_card_id == ^card.id) == []
    end

    test "nil template creates a card with zero benefits" do
      assert {:ok, card} = CreditCards.create_card(%{"name" => "No Template"})
      assert Repo.all(from b in Benefit, where: b.credit_card_id == ^card.id) == []
    end

    test "\"amex_gold\" template creates the card and its three benefits" do
      assert {:ok, card} = CreditCards.create_card(%{"name" => "Amex"}, "amex_gold")

      benefits =
        Repo.all(from b in Benefit, where: b.credit_card_id == ^card.id, order_by: b.name)

      assert Enum.map(benefits, & &1.name) == ["Dining Credit", "Resy Credit", "Uber Cash"]

      dining = Enum.find(benefits, &(&1.name == "Dining Credit"))
      assert Decimal.equal?(dining.amount, Decimal.new("10.00"))
      assert dining.frequency == :monthly

      resy = Enum.find(benefits, &(&1.name == "Resy Credit"))
      assert Decimal.equal?(resy.amount, Decimal.new("50.00"))
      assert resy.frequency == :semi_annual

      uber = Enum.find(benefits, &(&1.name == "Uber Cash"))
      assert Decimal.equal?(uber.amount, Decimal.new("10.00"))
      assert uber.frequency == :monthly
    end

    test "unknown template key behaves like \"custom\"" do
      assert {:ok, card} = CreditCards.create_card(%{"name" => "Mystery"}, "not_a_template")
      assert Repo.all(from b in Benefit, where: b.credit_card_id == ^card.id) == []
    end

    test "rolls back and inserts no card or benefits for an invalid changeset" do
      assert {:error, cs} = CreditCards.create_card(%{"name" => ""}, "amex_gold")
      assert %{name: [_ | _]} = errors_on(cs)
      assert Repo.all(CreditCard) == []
      assert Repo.all(Benefit) == []
    end
  end

  describe "update_card/2 and delete_card/1" do
    test "update_card/2 renames a card" do
      {:ok, card} = CreditCards.create_card(%{"name" => "Old Name"})
      assert {:ok, updated} = CreditCards.update_card(card, %{"name" => "New Name"})
      assert updated.name == "New Name"
    end

    test "delete_card/1 cascades to benefits and benefit_usages" do
      {:ok, card} = CreditCards.create_card(%{"name" => "Cascade Card"}, "amex_gold")
      [benefit | _] = CreditCards.list_benefits(card.id)

      assert {:ok, :used} = CreditCards.toggle_usage(benefit)

      assert {:ok, _} = CreditCards.delete_card(card)

      assert Repo.all(from b in Benefit, where: b.credit_card_id == ^card.id) == []
      assert Repo.all(from u in BenefitUsage, where: u.benefit_id == ^benefit.id) == []
    end
  end

  describe "benefit CRUD validations" do
    setup do
      {:ok, card} = CreditCards.create_card(%{"name" => "Validation Card"})
      %{card: card}
    end

    test "amount must be greater than 0", %{card: card} do
      attrs = %{"name" => "Bad", "amount" => "0", "frequency" => "monthly"}
      assert {:error, cs} = CreditCards.create_benefit(card.id, attrs)
      assert %{amount: [_ | _]} = errors_on(cs)

      attrs = %{"name" => "Bad", "amount" => "-5", "frequency" => "monthly"}
      assert {:error, cs} = CreditCards.create_benefit(card.id, attrs)
      assert %{amount: [_ | _]} = errors_on(cs)
    end

    test "frequency must be a known value", %{card: card} do
      attrs = %{"name" => "Bad", "amount" => "10", "frequency" => "biweekly"}
      assert {:error, cs} = CreditCards.create_benefit(card.id, attrs)
      assert %{frequency: [_ | _]} = errors_on(cs)
    end

    test "rejects a bogus credit_card_id via the FK constraint" do
      attrs = %{"name" => "Orphan", "amount" => "10", "frequency" => "monthly"}
      assert {:error, cs} = CreditCards.create_benefit(Ecto.UUID.generate(), attrs)
      assert %{credit_card_id: [_ | _]} = errors_on(cs)
    end

    test "update_benefit/2 and delete_benefit/1 work", %{card: card} do
      {:ok, benefit} =
        CreditCards.create_benefit(card.id, %{
          "name" => "Original",
          "amount" => "10",
          "frequency" => "monthly"
        })

      assert {:ok, updated} = CreditCards.update_benefit(benefit, %{"name" => "Renamed"})
      assert updated.name == "Renamed"

      assert {:ok, _} = CreditCards.delete_benefit(updated)
      assert CreditCards.get_benefit(benefit.id) == nil
    end
  end

  describe "used_this_period?/1, toggle_usage/1, last_used_period/1" do
    setup do
      {:ok, card} = CreditCards.create_card(%{"name" => "Usage Card"})

      {:ok, benefit} =
        CreditCards.create_benefit(card.id, %{
          "name" => "Monthly Thing",
          "amount" => "10",
          "frequency" => "monthly"
        })

      %{benefit: benefit}
    end

    test "toggling flips used status and back", %{benefit: benefit} do
      refute CreditCards.used_this_period?(benefit)

      assert {:ok, :used} = CreditCards.toggle_usage(benefit)
      assert CreditCards.used_this_period?(benefit)

      assert {:ok, :unused} = CreditCards.toggle_usage(benefit)
      refute CreditCards.used_this_period?(benefit)
    end

    test "last_used_period/1 returns nil with no usages, and the max period otherwise", %{
      benefit: benefit
    } do
      assert CreditCards.last_used_period(benefit) == nil

      now = DateTime.utc_now() |> DateTime.truncate(:second)

      Repo.insert!(%BenefitUsage{benefit_id: benefit.id, period: "2025-01", used_at: now})
      Repo.insert!(%BenefitUsage{benefit_id: benefit.id, period: "2025-11", used_at: now})

      assert CreditCards.last_used_period(benefit) == "2025-11"
    end

    test "the unique index rejects a duplicate {benefit_id, period} row", %{benefit: benefit} do
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      attrs = %{"benefit_id" => benefit.id, "period" => "2025-01", "used_at" => now}

      assert {:ok, _} = %BenefitUsage{} |> BenefitUsage.changeset(attrs) |> Repo.insert()
      assert {:error, cs} = %BenefitUsage{} |> BenefitUsage.changeset(attrs) |> Repo.insert()
      assert %{benefit_id: [_ | _]} = errors_on(cs)
    end
  end

  describe "annual_value/1" do
    test "sums each frequency at its yearly-occurrence count" do
      {:ok, card} = CreditCards.create_card(%{"name" => "Value Card"})

      CreditCards.create_benefit(card.id, %{
        "name" => "M",
        "amount" => "10",
        "frequency" => "monthly"
      })

      CreditCards.create_benefit(card.id, %{
        "name" => "Q",
        "amount" => "20",
        "frequency" => "quarterly"
      })

      CreditCards.create_benefit(card.id, %{
        "name" => "H",
        "amount" => "50",
        "frequency" => "semi_annual"
      })

      CreditCards.create_benefit(card.id, %{
        "name" => "A",
        "amount" => "100",
        "frequency" => "annual"
      })

      card = CreditCards.get_card_with_benefits(card.id)
      # 10*12 + 20*4 + 50*2 + 100*1 = 120 + 80 + 100 + 100 = 400
      assert Decimal.equal?(CreditCards.annual_value(card), Decimal.new("400"))
    end

    test "returns zero for a card with no benefits" do
      {:ok, card} = CreditCards.create_card(%{"name" => "Empty Card"})
      card = CreditCards.get_card_with_benefits(card.id)
      assert Decimal.equal?(CreditCards.annual_value(card), Decimal.new(0))
    end
  end
end
