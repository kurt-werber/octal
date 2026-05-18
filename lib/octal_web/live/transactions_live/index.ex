defmodule OctalWeb.TransactionsLive.Index do
  use OctalWeb, :live_view

  alias Octal.{AI, Categories, Transactions}
  alias Octal.Transactions.Transaction

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:current_tab, :transactions)
     |> assign(:page_title, "Transactions")
     |> assign(:categories, Categories.list())
     |> stream(:transactions, Transactions.list())}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:editing, nil)
    |> assign(:form, nil)
  end

  defp apply_action(socket, :new, _params) do
    txn = %Transaction{date: Date.utc_today()}

    socket
    |> assign(:editing, :new)
    |> assign(:amount_source, nil)
    |> assign(:form, to_form(Transactions.change(txn)))
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    case Transactions.get(id) do
      nil ->
        socket
        |> put_flash(:error, "Transaction not found")
        |> push_navigate(to: ~p"/")

      %Transaction{} = existing ->
        socket
        |> assign(:editing, existing)
        |> assign(:amount_source, nil)
        |> assign(:form, to_form(Transactions.change(existing)))
    end
  end

  @impl true
  def handle_event("validate", %{"transaction" => params}, socket) do
    cs =
      %Transaction{}
      |> Transactions.change(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(cs))}
  end

  def handle_event("suggest_amount", %{"value" => vendor}, socket) do
    handle_suggest(socket, vendor)
  end

  def handle_event("suggest_amount", %{"vendor" => vendor}, socket) do
    handle_suggest(socket, vendor)
  end

  def handle_event("save", %{"transaction" => params}, socket) do
    case socket.assigns.editing do
      :new -> save_new(socket, params)
      %{} = existing -> save_edit(socket, existing, params)
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    Transactions.delete(id)

    {:noreply,
     socket
     |> stream_delete_by_dom_id(:transactions, "transactions-#{id}")
     |> put_flash(:info, "Transaction deleted")}
  end

  defp handle_suggest(socket, vendor) do
    vendor = vendor |> to_string() |> String.trim()

    if vendor == "" or socket.assigns.form == nil do
      {:noreply, socket}
    else
      case AI.suggest_amount(vendor) do
        {:ok, %Decimal{} = amount, source} ->
          form = socket.assigns.form
          current = form.params["amount"] || form.data.amount

          if blank?(current) do
            params = Map.put(form.params || %{}, "amount", Decimal.to_string(amount))
            cs = Transactions.change(form.data, params) |> Map.put(:action, :validate)

            {:noreply,
             socket
             |> assign(:form, to_form(cs))
             |> assign(:amount_source, source)}
          else
            {:noreply, socket}
          end

        {:error, reason} ->
          {:noreply,
           put_flash(
             socket,
             :error,
             "Couldn't suggest an amount (#{inspect(reason)}). Enter manually."
           )}
      end
    end
  end

  defp blank?(nil), do: true
  defp blank?(""), do: true
  defp blank?(s) when is_binary(s), do: String.trim(s) == ""
  defp blank?(_), do: false

  defp save_new(socket, params) do
    case Transactions.create(params) do
      {:ok, txn} ->
        {:noreply,
         socket
         |> stream_insert(:transactions, txn, at: 0)
         |> put_flash(:info, "Transaction added")
         |> push_patch(to: ~p"/")}

      {:error, %Ecto.Changeset{} = cs} ->
        {:noreply, assign(socket, :form, to_form(cs))}
    end
  end

  defp save_edit(socket, existing, params) do
    case Transactions.update(existing, params) do
      {:ok, txn} ->
        {:noreply,
         socket
         |> stream_insert(:transactions, txn)
         |> put_flash(:info, "Transaction updated")
         |> push_patch(to: ~p"/")}

      {:error, %Ecto.Changeset{} = cs} ->
        {:noreply, assign(socket, :form, to_form(cs))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="flex items-center justify-between">
        <div>
          <h1 class="text-2xl font-semibold text-slate-900">Transactions</h1>
          <p class="text-sm text-slate-500">Record what you spent, where, and on what.</p>
        </div>
        <.link patch={~p"/transactions/new"}>
          <.button>+ New transaction</.button>
        </.link>
      </div>

      <.modal :if={@editing} on_close={JS.patch(~p"/")}>
        <.form
          for={@form}
          id="transaction-form"
          phx-change="validate"
          phx-submit="save"
          class="space-y-4"
        >
          <h2 class="text-lg font-semibold text-slate-900">
            {if @editing == :new, do: "New transaction", else: "Edit transaction"}
          </h2>

          <.field field={@form[:date]} type="date" label="Date" required />

          <.field
            field={@form[:vendor]}
            label="Vendor"
            placeholder="e.g. Blue Bottle Coffee"
            phx-blur="suggest_amount"
            phx-debounce="600"
            required
          />

          <div>
            <.field field={@form[:amount]} type="number" label="Amount (USD)" step="0.01" required />
            <p :if={@amount_source} class="mt-1 text-xs text-slate-500">
              {amount_source_label(@amount_source)}
            </p>
          </div>

          <.field
            field={@form[:category]}
            type="select"
            label="Category"
            options={Enum.map(@categories, &{&1.name, &1.name})}
            required
          />

          <.field field={@form[:note]} type="text" label="Note (optional)" />

          <div class="flex gap-2 pt-2">
            <.button type="submit" phx-disable-with="Saving...">Save</.button>
            <.link patch={~p"/"} class="px-3 py-2 text-sm text-slate-600 hover:text-slate-900">
              Cancel
            </.link>
          </div>
        </.form>
      </.modal>

      <div class="bg-white rounded-lg border border-slate-200 overflow-hidden">
        <table class="w-full text-sm">
          <thead class="bg-slate-50 text-left text-slate-600">
            <tr>
              <th class="px-4 py-2 font-medium">Date</th>
              <th class="px-4 py-2 font-medium">Vendor</th>
              <th class="px-4 py-2 font-medium">Category</th>
              <th class="px-4 py-2 font-medium text-right">Amount</th>
              <th class="px-4 py-2 font-medium"></th>
            </tr>
          </thead>
          <tbody id="transactions" phx-update="stream" class="divide-y divide-slate-100">
            <tr id="transactions-empty" class="hidden only:table-row">
              <td colspan="5" class="px-4 py-8 text-center text-slate-500">
                No transactions yet. Add your first one to get started.
              </td>
            </tr>
            <tr :for={{dom_id, t} <- @streams.transactions} id={dom_id} class="hover:bg-slate-50">
              <td class="px-4 py-2 text-slate-700">{t.date}</td>
              <td class="px-4 py-2">{t.vendor}</td>
              <td class="px-4 py-2 text-slate-700">{t.category}</td>
              <td class="px-4 py-2 text-right font-mono">{money(t.amount)}</td>
              <td class="px-4 py-2 text-right whitespace-nowrap">
                <.link patch={~p"/transactions/#{t.id}/edit"} class="text-slate-600 hover:underline">
                  Edit
                </.link>
                <button
                  type="button"
                  phx-click="delete"
                  phx-value-id={t.id}
                  data-confirm="Delete this transaction?"
                  class="ml-3 text-red-600 hover:underline"
                >
                  Delete
                </button>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
    """
  end

  attr :on_close, JS, default: %JS{}
  slot :inner_block, required: true

  defp modal(assigns) do
    ~H"""
    <div class="fixed inset-0 z-50 flex items-start justify-center bg-slate-900/40 p-4 overflow-y-auto" phx-click={@on_close}>
      <div class="w-full max-w-md rounded-lg bg-white p-6 shadow-xl mt-16" onclick="event.stopPropagation()">
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end

  defp amount_source_label(:history), do: "Default from your past spend at this vendor."
  defp amount_source_label(:ai), do: "AI-estimated for this vendor — please double-check."
  defp amount_source_label(_), do: nil
end
