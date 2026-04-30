defmodule OctalWeb.VisualizationsLive.Index do
  use OctalWeb, :live_view

  alias Octal.Analytics

  @impl true
  def mount(_params, _session, socket) do
    ym = Analytics.current_year_month()

    {:ok,
     socket
     |> assign(:current_tab, :visualize)
     |> assign(:page_title, "Visualize")
     |> assign(:year_month, ym)
     |> load_data()}
  end

  defp load_data(socket) do
    ym = socket.assigns.year_month

    socket
    |> assign(:by_cat, Analytics.spend_by_category(ym))
    |> assign(:vs_budget, Analytics.spend_vs_budget(ym))
    |> assign(:trend, Analytics.daily_spend(30))
  end

  @impl true
  def handle_event("change_month", %{"year_month" => ym}, socket) do
    if String.match?(ym, ~r/^\d{4}-\d{2}$/) do
      {:noreply, socket |> assign(:year_month, ym) |> load_data()}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-8">
      <div class="flex items-center justify-between">
        <div>
          <h1 class="text-2xl font-semibold">Visualize</h1>
          <p class="text-sm text-slate-500">Where did your money go?</p>
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

      <section class="bg-white rounded-lg border border-slate-200 p-6">
        <h2 class="font-semibold mb-3">Spend by category</h2>
        <.bar_chart_horizontal data={@by_cat} />
      </section>

      <section class="bg-white rounded-lg border border-slate-200 p-6">
        <h2 class="font-semibold mb-3">Spend vs. budget</h2>
        <.spend_vs_budget rows={@vs_budget} />
      </section>

      <section class="bg-white rounded-lg border border-slate-200 p-6">
        <h2 class="font-semibold mb-3">Last 30 days</h2>
        <.trend data={@trend} />
      </section>
    </div>
    """
  end

  attr :data, :list, required: true

  defp bar_chart_horizontal(assigns) do
    max =
      assigns.data
      |> Enum.map(& &1.total)
      |> Enum.reduce(Decimal.new(0), fn v, acc -> if Decimal.compare(v, acc) == :gt, do: v, else: acc end)

    assigns = assign(assigns, :max, max)

    ~H"""
    <div :if={@data == []} class="text-sm text-slate-500">No transactions yet for this month.</div>
    <div :if={@data != []} class="space-y-2">
      <div :for={row <- @data} class="grid grid-cols-[8rem_1fr_5rem] gap-3 items-center">
        <div class="text-sm text-slate-700 truncate">{row.category}</div>
        <div class="bg-slate-100 rounded h-5 overflow-hidden">
          <div class="h-full bg-slate-900" style={"width: #{percent(row.total, @max)}%"}></div>
        </div>
        <div class="text-right text-sm font-mono">{money(row.total)}</div>
      </div>
    </div>
    """
  end

  attr :rows, :list, required: true

  defp spend_vs_budget(assigns) do
    max =
      assigns.rows
      |> Enum.flat_map(fn r -> [r.spent, r.limit] end)
      |> Enum.reduce(Decimal.new(0), fn v, acc -> if Decimal.compare(v, acc) == :gt, do: v, else: acc end)

    assigns = assign(assigns, :max, max)

    ~H"""
    <div :if={@rows == []} class="text-sm text-slate-500">No data.</div>
    <div :if={@rows != []} class="space-y-3">
      <div :for={r <- @rows} class="grid grid-cols-[8rem_1fr_8rem] gap-3 items-center">
        <div class="text-sm text-slate-700 truncate">{r.category}</div>
        <div class="space-y-0.5">
          <div class="bg-slate-100 rounded h-3 overflow-hidden">
            <div class={["h-full", if(r.over, do: "bg-red-600", else: "bg-slate-900")]} style={"width: #{percent(r.spent, @max)}%"}></div>
          </div>
          <div class="bg-slate-100 rounded h-3 overflow-hidden">
            <div class="h-full bg-emerald-500" style={"width: #{percent(r.limit, @max)}%"}></div>
          </div>
        </div>
        <div class="text-right text-xs text-slate-500">
          <div>spent {money(r.spent)}</div>
          <div>limit {money(r.limit)}</div>
        </div>
      </div>
      <div class="flex gap-4 text-xs text-slate-500 pt-2">
        <span class="flex items-center gap-1"><span class="size-3 bg-slate-900 rounded-sm"></span> spent</span>
        <span class="flex items-center gap-1"><span class="size-3 bg-emerald-500 rounded-sm"></span> budget</span>
        <span class="flex items-center gap-1"><span class="size-3 bg-red-600 rounded-sm"></span> over budget</span>
      </div>
    </div>
    """
  end

  attr :data, :list, required: true

  defp trend(assigns) do
    max =
      assigns.data
      |> Enum.map(& &1.total)
      |> Enum.reduce(Decimal.new(0), fn v, acc -> if Decimal.compare(v, acc) == :gt, do: v, else: acc end)

    assigns = assign(assigns, :max, max)

    ~H"""
    <div class="flex items-end gap-1 h-32">
      <div :for={d <- @data} class="flex-1 group relative">
        <div
          class="bg-slate-300 hover:bg-slate-700 transition-colors w-full rounded-sm"
          style={"height: #{percent(d.total, @max)}%; min-height: 1px"}
        >
        </div>
        <div class="absolute bottom-full left-1/2 -translate-x-1/2 mb-1 hidden group-hover:block whitespace-nowrap bg-slate-900 text-white text-xs px-2 py-0.5 rounded">
          {d.date}: {money(d.total)}
        </div>
      </div>
    </div>
    """
  end

  defp percent(v, max) do
    if Decimal.compare(max, Decimal.new(0)) == :gt and
         Decimal.compare(v, Decimal.new(0)) == :gt do
      v
      |> Decimal.div(max)
      |> Decimal.mult(Decimal.new(100))
      |> Decimal.to_float()
      |> floor_one()
    else
      0
    end
  end

  defp floor_one(n) when n < 1, do: 1
  defp floor_one(n), do: n
end
