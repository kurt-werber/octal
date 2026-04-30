defmodule OctalWeb.AiAnalyticsLive.Index do
  use OctalWeb, :live_view

  alias Octal.{AI, Analytics, Budgets, Transactions}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:current_tab, :insights)
     |> assign(:page_title, "AI Insights")
     |> assign(:loading?, false)
     |> assign(:insights, nil)
     |> assign(:generated_at, nil)
     |> assign(:error, nil)}
  end

  @impl true
  def handle_event("analyze", _, socket) do
    parent = self()

    Task.Supervisor.start_child(Octal.TaskSupervisor, fn ->
      result = run_analysis()
      send(parent, {:analysis_done, result})
    end)

    {:noreply, assign(socket, loading?: true, error: nil)}
  end

  @impl true
  def handle_info({:analysis_done, {:ok, text}}, socket) do
    {:noreply,
     socket
     |> assign(:loading?, false)
     |> assign(:insights, text)
     |> assign(:generated_at, DateTime.utc_now())}
  end

  def handle_info({:analysis_done, {:error, reason}}, socket) do
    {:noreply,
     socket
     |> assign(:loading?, false)
     |> assign(:error, format_error(reason))}
  end

  defp run_analysis do
    ninety_days_ago = Date.add(Date.utc_today(), -90)
    txns = Transactions.list(from: ninety_days_ago, limit: 500)
    budgets = Budgets.list_for_month(Analytics.current_year_month())
    AI.analyze(txns, budgets)
  end

  defp format_error(:missing_api_key),
    do: "ANTHROPIC_API_KEY isn't set. Add it to your environment to enable AI insights."

  defp format_error({:http_status, status, _}), do: "Anthropic returned HTTP #{status}."
  defp format_error(other), do: "Couldn't generate insights: #{inspect(other)}"

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <div>
        <h1 class="text-2xl font-semibold">AI Insights</h1>
        <p class="text-sm text-slate-500">
          Click <em>Analyze</em> to ask Claude for suggestions based on your last 90 days of
          transactions and your current budgets. Nothing is sent until you click.
        </p>
      </div>

      <div class="flex items-center gap-3">
        <.button phx-click="analyze" phx-disable-with="Analyzing…" disabled={@loading?}>
          {if @loading?, do: "Analyzing…", else: "Analyze"}
        </.button>
        <span :if={@generated_at} class="text-xs text-slate-500">
          Last run: {Calendar.strftime(@generated_at, "%Y-%m-%d %H:%M UTC")}
        </span>
      </div>

      <div :if={@error} class="bg-red-50 border border-red-200 text-red-900 rounded-md p-4 text-sm">
        {@error}
      </div>

      <article :if={@insights} class="prose prose-slate max-w-none bg-white border border-slate-200 rounded-lg p-6">
        {raw(render_markdown(@insights))}
      </article>

      <div :if={!@insights and !@loading? and !@error} class="text-sm text-slate-500">
        No insights yet — run an analysis to get started.
      </div>
    </div>
    """
  end

  # Minimal Markdown rendering — bullets, paragraphs, **bold**, *italic*. Avoids
  # pulling a full markdown dep for what is effectively a small bullet list.
  defp render_markdown(text) do
    text
    |> String.split("\n", trim: false)
    |> Enum.reduce({[], :para, []}, &collect_line/2)
    |> close_block()
    |> Enum.reverse()
    |> Enum.join("\n")
  end

  defp collect_line(line, {acc, mode, buf}) do
    cond do
      String.match?(line, ~r/^\s*[-*]\s+/) ->
        item = Regex.replace(~r/^\s*[-*]\s+/, line, "")
        case mode do
          :list -> {acc, :list, [item | buf]}
          _ -> {flush(acc, mode, buf), :list, [item]}
        end

      String.trim(line) == "" ->
        {flush(acc, mode, buf), :para, []}

      true ->
        case mode do
          :list -> {flush(acc, mode, buf), :para, [line]}
          _ -> {acc, :para, [line | buf]}
        end
    end
  end

  defp flush(acc, _mode, []), do: acc

  defp flush(acc, :list, items) do
    body =
      items
      |> Enum.reverse()
      |> Enum.map_join("\n", &"<li>#{format_inline(&1)}</li>")

    ["<ul>#{body}</ul>" | acc]
  end

  defp flush(acc, :para, lines) do
    body = lines |> Enum.reverse() |> Enum.join(" ") |> format_inline()
    ["<p>#{body}</p>" | acc]
  end

  defp close_block({acc, mode, buf}), do: flush(acc, mode, buf)

  defp format_inline(s) do
    s
    |> Phoenix.HTML.html_escape()
    |> Phoenix.HTML.safe_to_string()
    |> String.replace(~r/\*\*([^*]+)\*\*/, "<strong>\\1</strong>")
    |> String.replace(~r/\*([^*]+)\*/, "<em>\\1</em>")
    |> String.replace(~r/`([^`]+)`/, "<code>\\1</code>")
  end
end
