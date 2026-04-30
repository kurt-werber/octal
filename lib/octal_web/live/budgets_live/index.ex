defmodule OctalWeb.BudgetsLive.Index do
  use OctalWeb, :live_view

  alias Octal.{Analytics, Budgets, Categories}

  @impl true
  def mount(_params, _session, socket) do
    ym = Analytics.current_year_month()

    {:ok,
     socket
     |> assign(:current_tab, :budgets)
     |> assign(:page_title, "Budgets")
     |> assign(:year_month, ym)
     |> load_rows()}
  end

  defp load_rows(socket) do
    ym = socket.assigns.year_month
    cats = Categories.list()
    by_cat = Budgets.list_for_month(ym) |> Map.new(&{&1.category, &1})

    rows =
      Enum.map(cats, fn c ->
        b = Map.get(by_cat, c.name)
        %{category: c.name, color: c.color, limit: (b && b.limit) || Decimal.new(0)}
      end)

    assign(socket, :rows, rows)
  end

  @impl true
  def handle_event("change_month", %{"year_month" => ym}, socket) do
    if String.match?(ym, ~r/^\d{4}-\d{2}$/) do
      {:noreply, socket |> assign(:year_month, ym) |> load_rows()}
    else
      {:noreply, socket}
    end
  end

  def handle_event("save_row", %{"category" => cat, "limit" => limit}, socket) do
    attrs = %{"category" => cat, "year_month" => socket.assigns.year_month, "limit" => limit}

    case Budgets.set_limit(attrs) do
      {:ok, _b} ->
        {:noreply, socket |> load_rows() |> put_flash(:info, "Budget for #{cat} saved")}

      {:error, %Ecto.Changeset{} = cs} ->
        msg =
          cs.errors
          |> Enum.map(fn {k, {m, _}} -> "#{k} #{m}" end)
          |> Enum.join(", ")

        {:noreply, put_flash(socket, :error, "Couldn't save: #{msg}")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="flex items-center justify-between">
        <div>
          <h1 class="text-2xl font-semibold">Budgets</h1>
          <p class="text-sm text-slate-500">Set a monthly cap for each category.</p>
        </div>
        <form phx-change="change_month" class="flex items-center gap-2">
          <label for="year_month" class="text-sm text-slate-600">Month</label>
          <input
            type="month"
            id="year_month"
            name="year_month"
            value={@year_month}
            class="rounded-md border-slate-300 shadow-sm sm:text-sm"
          />
        </form>
      </div>

      <div class="bg-white rounded-lg border border-slate-200 overflow-hidden">
        <table class="w-full text-sm">
          <thead class="bg-slate-50 text-left text-slate-600">
            <tr>
              <th class="px-4 py-2 font-medium">Category</th>
              <th class="px-4 py-2 font-medium">Monthly limit (USD)</th>
              <th class="px-4 py-2"></th>
            </tr>
          </thead>
          <tbody class="divide-y divide-slate-100">
            <tr :for={row <- @rows}>
              <td class="px-4 py-2">
                <div class="flex items-center gap-2">
                  <span class="inline-block size-3 rounded-full" style={"background-color: #{row.color}"}></span>
                  {row.category}
                </div>
              </td>
              <td class="px-4 py-2">
                <form phx-submit="save_row" class="flex items-center gap-2">
                  <input type="hidden" name="category" value={row.category} />
                  <input
                    type="number"
                    step="0.01"
                    min="0"
                    name="limit"
                    value={Decimal.to_string(row.limit, :normal)}
                    class="w-32 rounded-md border-slate-300 shadow-sm sm:text-sm"
                  />
                  <.button type="submit" class="!py-1 !px-3 !text-xs">Save</.button>
                </form>
              </td>
              <td class="px-4 py-2 text-right text-slate-500 text-xs">
                <span :if={Decimal.compare(row.limit, Decimal.new(0)) == :gt}>
                  {money(row.limit)}/mo
                </span>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
    """
  end
end
