defmodule OctalWeb.CreditCardsLive.Show do
  use OctalWeb, :live_view

  alias Octal.CreditCards
  alias Octal.CreditCards.Benefit

  @frequencies [
    {"Monthly", :monthly},
    {"Quarterly", :quarterly},
    {"Semi-annual", :semi_annual},
    {"Annual", :annual}
  ]

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:current_tab, :credit_cards)
     |> assign(:frequencies, @frequencies)}
  end

  @impl true
  def handle_params(%{"id" => id} = params, _url, socket) do
    case CreditCards.get_card(id) do
      nil ->
        {:noreply,
         socket
         |> put_flash(:error, "Credit card not found")
         |> push_navigate(to: ~p"/credit-cards")}

      card ->
        socket =
          socket
          |> assign(:page_title, card.name)
          |> assign(:card, card)
          |> stream(:benefit_rows, benefit_rows(id), reset: true)

        {:noreply, apply_action(socket, socket.assigns.live_action, params)}
    end
  end

  defp apply_action(socket, :show, _params) do
    socket
    |> assign(:editing, nil)
    |> assign(:form, nil)
  end

  defp apply_action(socket, :new_benefit, _params) do
    socket
    |> assign(:editing, :new)
    |> assign(:form, to_form(CreditCards.change_benefit(%Benefit{})))
  end

  defp apply_action(socket, :edit_benefit, %{"benefit_id" => benefit_id}) do
    case CreditCards.get_benefit(benefit_id) do
      nil ->
        socket
        |> put_flash(:error, "Benefit not found")
        |> push_patch(to: ~p"/credit-cards/#{socket.assigns.card.id}")

      %Benefit{} = benefit ->
        socket
        |> assign(:editing, benefit)
        |> assign(:form, to_form(CreditCards.change_benefit(benefit)))
    end
  end

  @impl true
  def handle_event("validate", %{"benefit" => params}, socket) do
    cs =
      %Benefit{}
      |> CreditCards.change_benefit(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(cs))}
  end

  def handle_event("save", %{"benefit" => params}, socket) do
    card = socket.assigns.card

    case socket.assigns.editing do
      :new ->
        case CreditCards.create_benefit(card.id, params) do
          {:ok, _benefit} ->
            {:noreply,
             socket
             |> put_flash(:info, "Benefit added")
             |> push_patch(to: ~p"/credit-cards/#{card.id}")}

          {:error, %Ecto.Changeset{} = cs} ->
            {:noreply, assign(socket, :form, to_form(cs))}
        end

      %Benefit{} = existing ->
        case CreditCards.update_benefit(existing, params) do
          {:ok, _benefit} ->
            {:noreply,
             socket
             |> put_flash(:info, "Benefit updated")
             |> push_patch(to: ~p"/credit-cards/#{card.id}")}

          {:error, %Ecto.Changeset{} = cs} ->
            {:noreply, assign(socket, :form, to_form(cs))}
        end
    end
  end

  def handle_event("delete_benefit", %{"id" => id}, socket) do
    case CreditCards.get_benefit(id) do
      nil ->
        {:noreply, socket}

      benefit ->
        {:ok, _} = CreditCards.delete_benefit(benefit)

        {:noreply,
         socket
         |> stream_delete_by_dom_id(:benefit_rows, "benefit_rows-#{id}")
         |> put_flash(:info, "Benefit deleted")}
    end
  end

  def handle_event("toggle_usage", %{"id" => id}, socket) do
    benefit = CreditCards.get_benefit(id)
    {:ok, _status} = CreditCards.toggle_usage(benefit)

    {:noreply, stream_insert(socket, :benefit_rows, row_for(benefit))}
  end

  defp benefit_rows(card_id) do
    card_id |> CreditCards.list_benefits() |> Enum.map(&row_for/1)
  end

  defp row_for(%Benefit{} = benefit) do
    %{
      id: benefit.id,
      benefit: benefit,
      used?: CreditCards.used_this_period?(benefit),
      last_used: CreditCards.last_used_period(benefit)
    }
  end

  defp humanize_frequency(:monthly), do: "Monthly"
  defp humanize_frequency(:quarterly), do: "Quarterly"
  defp humanize_frequency(:semi_annual), do: "Semi-annual"
  defp humanize_frequency(:annual), do: "Annual"

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="flex items-center justify-between">
        <div>
          <p class="text-sm text-slate-500">
            <.link navigate={~p"/credit-cards"} class="hover:underline">Credit Cards</.link> / {@card.name}
          </p>
          <h1 class="text-2xl font-semibold">{@card.name}</h1>
        </div>
        <.link patch={~p"/credit-cards/#{@card.id}/benefits/new"}>
          <.button>+ New benefit</.button>
        </.link>
      </div>

      <div :if={@editing} class="bg-white rounded-lg border border-slate-200 p-4">
        <.form for={@form} phx-change="validate" phx-submit="save" class="space-y-3">
          <h2 class="font-medium">
            {if @editing == :new, do: "Add benefit", else: "Edit benefit"}
          </h2>
          <.field field={@form[:name]} label="Name" required />
          <.field field={@form[:amount]} type="number" label="Amount (USD)" step="0.01" required />
          <.field
            field={@form[:frequency]}
            type="select"
            label="Frequency"
            options={@frequencies}
            required
          />
          <div class="flex gap-2">
            <.button type="submit">Save</.button>
            <.link patch={~p"/credit-cards/#{@card.id}"} class="px-3 py-2 text-sm text-slate-600">
              Cancel
            </.link>
          </div>
        </.form>
      </div>

      <ul id="benefit_rows" phx-update="stream" class="space-y-2">
        <li
          :for={{dom_id, row} <- @streams.benefit_rows}
          id={dom_id}
          class="flex items-center justify-between bg-white border border-slate-200 rounded-md px-4 py-3"
        >
          <div>
            <p class="font-medium">
              {row.benefit.name}
              <span class="text-slate-500 font-normal">
                · {money(row.benefit.amount)} · {humanize_frequency(row.benefit.frequency)}
              </span>
            </p>
            <p class="text-xs text-slate-400">
              last used: {row.last_used || "never"}
            </p>
          </div>
          <div class="flex items-center gap-3 text-sm">
            <button
              type="button"
              phx-click="toggle_usage"
              phx-value-id={row.benefit.id}
              class={[
                "rounded-md px-3 py-1.5 font-medium",
                row.used? && "bg-emerald-600 text-white hover:bg-emerald-700",
                !row.used? && "bg-slate-100 text-slate-700 hover:bg-slate-200"
              ]}
            >
              {if row.used?, do: "Used this period", else: "Mark used"}
            </button>
            <.link
              patch={~p"/credit-cards/#{@card.id}/benefits/#{row.benefit.id}/edit"}
              class="text-slate-600 hover:underline"
            >
              Edit
            </.link>
            <button
              type="button"
              phx-click="delete_benefit"
              phx-value-id={row.benefit.id}
              data-confirm={"Delete #{row.benefit.name}?"}
              class="text-red-600 hover:underline"
            >
              Delete
            </button>
          </div>
        </li>
      </ul>
    </div>
    """
  end
end
