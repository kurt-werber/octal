defmodule Octal.AI do
  @moduledoc """
  Anthropic Claude integration.

  Two entry points:

    * `suggest_amount/1` — returns a sensible default amount for a vendor.
      Uses the user's own transaction history first; on a miss, asks Haiku
      for an estimate. Always cheap and non-blocking from the user's POV.

    * `analyze/2` — Sonnet-backed insights over recent transactions and
      current-month budgets, used by the AI Analytics tab.
  """

  require Logger

  @endpoint "https://api.anthropic.com/v1/messages"
  @anthropic_version "2023-06-01"
  @haiku "claude-haiku-4-5"
  @sonnet "claude-sonnet-4-6"

  @typedoc "Why a suggested amount was chosen — useful for UI badges."
  @type source :: :history | :ai

  @doc """
  Suggest a default amount for `vendor`. Returns:

    * `{:ok, %Decimal{}, :history}` — median of past transactions
    * `{:ok, %Decimal{}, :ai}` — AI estimate based on vendor name
    * `{:error, term}` — no history and AI unavailable / errored
  """
  @spec suggest_amount(String.t()) :: {:ok, Decimal.t(), source} | {:error, term()}
  def suggest_amount(vendor) when is_binary(vendor) do
    case Octal.Transactions.median_for_vendor(vendor) do
      %Decimal{} = d -> {:ok, d, :history}
      _ -> ai_estimate_amount(vendor)
    end
  end

  def suggest_amount(_), do: {:error, :invalid_vendor}

  defp ai_estimate_amount(vendor) do
    prompt = """
    Estimate a typical USD amount for a single personal transaction at the
    vendor: "#{vendor}". Consider the vendor type (coffee shops are smaller,
    airlines and rent are larger, etc). Respond with ONLY a JSON object on a
    single line, no other text:

      {"amount": <number>}
    """

    case call(@haiku, [%{role: "user", content: prompt}], 64) do
      {:ok, text} -> parse_amount(text)
      {:error, _} = err -> err
    end
  end

  defp parse_amount(text) do
    with {:ok, json} <- find_json(text),
         {:ok, %{"amount" => n}} <- Jason.decode(json),
         {:ok, dec} <- to_decimal(n) do
      {:ok, dec, :ai}
    else
      _ -> {:error, :unparseable}
    end
  end

  defp find_json(text) do
    case Regex.run(~r/\{[^{}]*\}/, text) do
      [match] -> {:ok, match}
      _ -> :error
    end
  end

  defp to_decimal(n) when is_number(n), do: {:ok, n |> to_string() |> Decimal.new()}
  defp to_decimal(n) when is_binary(n), do: {:ok, Decimal.new(n)}
  defp to_decimal(_), do: :error

  @doc """
  Generate insight bullets for the supplied `transactions` (last ~90 days)
  and `budgets` (current month). Returns `{:ok, markdown}` or `{:error, _}`.
  """
  @spec analyze([map()], [map()]) :: {:ok, String.t()} | {:error, term()}
  def analyze(transactions, budgets) do
    prompt = analyze_prompt(transactions, budgets)
    call(@sonnet, [%{role: "user", content: prompt}], 1024)
  end

  defp analyze_prompt(transactions, budgets) do
    txn_lines =
      transactions
      |> Enum.take(200)
      |> Enum.map_join("\n", fn t ->
        "#{t.date} | #{t.category} | $#{t.amount} | #{t.vendor}"
      end)

    budget_lines =
      Enum.map_join(budgets, "\n", fn b -> "#{b.category}: $#{b.limit}" end)

    """
    You are a friendly personal finance coach. Review the following recent
    transactions and the user's current monthly budgets, then return 3-6
    concise, actionable insights as Markdown bullet points. Highlight any
    categories where they are likely to overspend this month, surprising
    vendor concentrations, and one or two suggestions for adjusting their
    plan. No preamble, just the bullets.

    ## Budgets (this month)
    #{budget_lines}

    ## Transactions (most recent first)
    #{txn_lines}
    """
  end

  defp call(model, messages, max_tokens) do
    case api_key() do
      nil ->
        {:error, :missing_api_key}

      key ->
        body = %{model: model, max_tokens: max_tokens, messages: messages}

        try do
          resp =
            Req.post!(@endpoint,
              json: body,
              headers: [
                {"x-api-key", key},
                {"anthropic-version", @anthropic_version},
                {"content-type", "application/json"}
              ],
              receive_timeout: 30_000,
              retry: :transient
            )

          extract_text(resp)
        rescue
          e ->
            Logger.warning("Anthropic call failed: #{inspect(e)}")
            {:error, e}
        end
    end
  end

  defp extract_text(%Req.Response{status: 200, body: %{"content" => [%{"text" => t} | _]}}),
    do: {:ok, t}

  defp extract_text(%Req.Response{status: status, body: body}),
    do: {:error, {:http_status, status, body}}

  defp api_key, do: Application.get_env(:octal, :anthropic_api_key)
end
