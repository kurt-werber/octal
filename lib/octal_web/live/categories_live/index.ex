defmodule OctalWeb.CategoriesLive.Index do
  use OctalWeb, :live_view

  alias Octal.Categories
  alias Octal.Categories.Category

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:current_tab, :categories)
     |> assign(:page_title, "Categories")
     |> stream(:categories, Categories.list())}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _), do: assign(socket, editing: nil, form: nil)

  defp apply_action(socket, :new, _) do
    socket
    |> assign(:editing, :new)
    |> assign(:form, to_form(Categories.change(%Category{color: "#64748b"})))
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    case Categories.get(id) do
      nil ->
        socket |> put_flash(:error, "Not found") |> push_navigate(to: ~p"/categories")

      %Category{} = cat ->
        socket
        |> assign(:editing, cat)
        |> assign(:form, to_form(Categories.change(cat)))
    end
  end

  @impl true
  def handle_event("validate", %{"category" => params}, socket) do
    cs =
      %Category{}
      |> Categories.change(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(cs))}
  end

  def handle_event("save", %{"category" => params}, socket) do
    case socket.assigns.editing do
      :new ->
        case Categories.create(params) do
          {:ok, cat} ->
            {:noreply,
             socket
             |> stream_insert(:categories, cat)
             |> put_flash(:info, "Category added")
             |> push_patch(to: ~p"/categories")}

          {:error, %Ecto.Changeset{} = cs} ->
            {:noreply, assign(socket, :form, to_form(cs))}
        end

      %{} = existing ->
        case Categories.update(existing, params) do
          {:ok, cat} ->
            {:noreply,
             socket
             |> stream_insert(:categories, cat)
             |> put_flash(:info, "Category updated")
             |> push_patch(to: ~p"/categories")}

          {:error, %Ecto.Changeset{} = cs} ->
            {:noreply, assign(socket, :form, to_form(cs))}
        end
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    cat = Categories.get(id)

    case Categories.delete(cat) do
      :ok ->
        {:noreply,
         socket
         |> stream_delete_by_dom_id(:categories, "categories-#{id}")
         |> put_flash(:info, "Category deleted")}

      {:error, :is_default} ->
        {:noreply, put_flash(socket, :error, "Default categories can't be deleted.")}

      {:error, :in_use} ->
        {:noreply, put_flash(socket, :error, "Category is used by existing transactions.")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="flex items-center justify-between">
        <div>
          <h1 class="text-2xl font-semibold">Categories</h1>
          <p class="text-sm text-slate-500">
            Defaults are seeded automatically. Add your own — or rename one to fit how you spend.
          </p>
        </div>
        <.link patch={~p"/categories/new"}>
          <.button>+ New category</.button>
        </.link>
      </div>

      <div :if={@editing} class="bg-white rounded-lg border border-slate-200 p-4">
        <.form for={@form} phx-change="validate" phx-submit="save" class="space-y-3">
          <h2 class="font-medium">
            {if @editing == :new, do: "Add category", else: "Edit category"}
          </h2>
          <.field field={@form[:name]} label="Name" required />
          <.field field={@form[:color]} type="color" label="Color" />
          <div class="flex gap-2">
            <.button type="submit">Save</.button>
            <.link patch={~p"/categories"} class="px-3 py-2 text-sm text-slate-600">
              Cancel
            </.link>
          </div>
        </.form>
      </div>

      <ul id="categories" phx-update="stream" class="grid grid-cols-1 sm:grid-cols-2 gap-2">
        <li
          :for={{dom_id, c} <- @streams.categories}
          id={dom_id}
          class="flex items-center justify-between bg-white border border-slate-200 rounded-md px-4 py-2"
        >
          <div class="flex items-center gap-2">
            <span class="inline-block size-4 rounded-full" style={"background-color: #{c.color}"}></span>
            <span class="font-medium">{c.name}</span>
            <span :if={c.is_default} class="text-xs text-slate-400">default</span>
          </div>
          <div class="flex gap-3 text-sm">
            <.link patch={~p"/categories/#{c.id}/edit"} class="text-slate-600 hover:underline">Edit</.link>
            <button
              :if={!c.is_default}
              type="button"
              phx-click="delete"
              phx-value-id={c.id}
              data-confirm={"Delete category #{c.name}?"}
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
