defmodule OctalWeb.CreditCardsLive.Index do
  use OctalWeb, :live_view

  alias Octal.CreditCards
  alias Octal.CreditCards.CreditCard

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:current_tab, :credit_cards)
     |> assign(:page_title, "Credit Cards")
     |> stream(:cards, CreditCards.list_cards_with_benefits())}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:editing, nil)
    |> assign(:form, nil)
    |> assign(:template_key, "custom")
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:editing, :new)
    |> assign(:template_key, "custom")
    |> assign(:form, to_form(CreditCards.change_card(%CreditCard{})))
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    case CreditCards.get_card(id) do
      nil ->
        socket
        |> put_flash(:error, "Credit card not found")
        |> push_navigate(to: ~p"/credit-cards")

      %CreditCard{} = card ->
        socket
        |> assign(:editing, card)
        |> assign(:template_key, "custom")
        |> assign(:form, to_form(CreditCards.change_card(card)))
    end
  end

  @impl true
  def handle_event("pick_template", %{"template_key" => key} = params, socket) do
    form_params = Map.get(params, "credit_card", %{})

    form_params =
      case CreditCards.template_card_name(key) do
        nil -> form_params
        name -> Map.put(form_params, "name", name)
      end

    cs = CreditCards.change_card(%CreditCard{}, form_params)

    {:noreply,
     socket
     |> assign(:template_key, key)
     |> assign(:form, to_form(cs))}
  end

  def handle_event("validate", %{"credit_card" => params}, socket) do
    cs =
      %CreditCard{}
      |> CreditCards.change_card(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(cs))}
  end

  def handle_event("save", %{"credit_card" => params}, socket) do
    case socket.assigns.editing do
      :new ->
        case CreditCards.create_card(params, socket.assigns.template_key) do
          {:ok, card} ->
            {:noreply,
             socket
             |> stream_insert(:cards, Octal.Repo.preload(card, :benefits))
             |> put_flash(:info, "Credit card added")
             |> push_patch(to: ~p"/credit-cards")}

          {:error, %Ecto.Changeset{} = cs} ->
            {:noreply, assign(socket, :form, to_form(cs))}
        end

      %CreditCard{} = existing ->
        case CreditCards.update_card(existing, params) do
          {:ok, card} ->
            {:noreply,
             socket
             |> stream_insert(:cards, Octal.Repo.preload(card, :benefits))
             |> put_flash(:info, "Credit card updated")
             |> push_patch(to: ~p"/credit-cards")}

          {:error, %Ecto.Changeset{} = cs} ->
            {:noreply, assign(socket, :form, to_form(cs))}
        end
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    case CreditCards.get_card(id) do
      nil ->
        {:noreply, socket}

      card ->
        {:ok, _} = CreditCards.delete_card(card)

        {:noreply,
         socket
         |> stream_delete_by_dom_id(:cards, "cards-#{id}")
         |> put_flash(:info, "Credit card deleted")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="flex items-center justify-between">
        <div>
          <h1 class="text-2xl font-semibold">Credit Cards</h1>
          <p class="text-sm text-slate-500">
            Track the cards you carry and whether you've used their recurring benefits.
          </p>
        </div>
        <.link patch={~p"/credit-cards/new"}>
          <.button>+ New card</.button>
        </.link>
      </div>

      <div :if={@editing} class="bg-white rounded-lg border border-slate-200 p-4">
        <.form for={@form} phx-change="validate" phx-submit="save" class="space-y-3">
          <h2 class="font-medium">
            {if @editing == :new, do: "Add credit card", else: "Edit credit card"}
          </h2>
          <div :if={@editing == :new}>
            <label class="block text-sm font-medium text-slate-700 mb-1">Start from a template</label>
            <select
              name="template_key"
              phx-change="pick_template"
              class="w-full rounded-md border border-slate-300 px-3 py-2 text-sm"
            >
              <option value="custom" selected={@template_key == "custom"}>Custom</option>
              <option
                :for={{key, label} <- CreditCards.templates()}
                value={key}
                selected={@template_key == key}
              >
                {label}
              </option>
            </select>
          </div>
          <.field field={@form[:name]} label="Name" required />
          <div class="flex gap-2">
            <.button type="submit">Save</.button>
            <.link patch={~p"/credit-cards"} class="px-3 py-2 text-sm text-slate-600">
              Cancel
            </.link>
          </div>
        </.form>
      </div>

      <ul id="cards" phx-update="stream" class="grid grid-cols-1 sm:grid-cols-2 gap-2">
        <li
          :for={{dom_id, card} <- @streams.cards}
          id={dom_id}
          class="flex items-center justify-between bg-white border border-slate-200 rounded-md px-4 py-3"
        >
          <div>
            <.link navigate={~p"/credit-cards/#{card.id}"} class="font-medium hover:underline">
              {card.name}
            </.link>
            <p class="text-xs text-slate-500">
              {length(card.benefits)} benefit{if length(card.benefits) != 1, do: "s"} · up to {money(
                CreditCards.annual_value(card)
              )}/yr
            </p>
          </div>
          <div class="flex gap-3 text-sm">
            <.link patch={~p"/credit-cards/#{card.id}/edit"} class="text-slate-600 hover:underline">
              Edit
            </.link>
            <button
              type="button"
              phx-click="delete"
              phx-value-id={card.id}
              data-confirm={"Delete #{card.name} and all its benefits?"}
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
