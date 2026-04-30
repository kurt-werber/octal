defmodule OctalWeb.CoreComponents do
  @moduledoc """
  Lean set of UI components used across LiveViews. Avoids the kitchen-sink
  default Phoenix generator output — only what we actually use.
  """
  use Phoenix.Component
  alias Phoenix.LiveView.JS

  @doc "Top-of-page navigation tab link with active state styling."
  attr :to, :string, required: true
  attr :label, :string, required: true
  attr :current, :atom, default: nil
  attr :match, :atom, required: true

  def tab_link(assigns) do
    ~H"""
    <.link
      navigate={@to}
      class={[
        "px-3 py-2 rounded-md transition-colors",
        @current == @match && "bg-slate-900 text-white",
        @current != @match && "text-slate-600 hover:bg-slate-100 hover:text-slate-900"
      ]}
    >
      {@label}
    </.link>
    """
  end

  attr :flash, :map, required: true

  def flash_group(assigns) do
    ~H"""
    <div class="space-y-2 mb-4">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />
    </div>
    """
  end

  attr :kind, :atom, required: true
  attr :flash, :map, default: %{}

  def flash(assigns) do
    ~H"""
    <div
      :if={msg = Phoenix.Flash.get(@flash, @kind)}
      role="alert"
      class={[
        "rounded-md px-4 py-3 text-sm",
        @kind == :info && "bg-emerald-50 text-emerald-900 border border-emerald-200",
        @kind == :error && "bg-red-50 text-red-900 border border-red-200"
      ]}
      phx-click={JS.hide(transition: "fade-out")}
    >
      {msg}
    </div>
    """
  end

  attr :type, :string, default: "text"
  attr :name, :string, required: true
  attr :value, :any, default: nil
  attr :label, :string, default: nil
  attr :id, :string, default: nil
  attr :step, :string, default: nil
  attr :placeholder, :string, default: nil
  attr :options, :list, default: []
  attr :rest, :global, include: ~w(autocomplete phx-blur phx-change phx-debounce required)
  attr :errors, :list, default: []

  def input(%{type: "select"} = assigns) do
    ~H"""
    <div>
      <.label :if={@label} for={@id || @name}>{@label}</.label>
      <select
        id={@id || @name}
        name={@name}
        class="mt-1 block w-full rounded-md border-slate-300 shadow-sm focus:border-slate-500 focus:ring-slate-500 sm:text-sm"
        {@rest}
      >
        <option :for={{label, value} <- @options} value={value} selected={to_string(@value) == to_string(value)}>
          {label}
        </option>
      </select>
      <p :for={err <- @errors} class="mt-1 text-xs text-red-600">{translate_error(err)}</p>
    </div>
    """
  end

  def input(assigns) do
    ~H"""
    <div>
      <.label :if={@label} for={@id || @name}>{@label}</.label>
      <input
        type={@type}
        id={@id || @name}
        name={@name}
        value={input_value(@value)}
        step={@step}
        placeholder={@placeholder}
        class="mt-1 block w-full rounded-md border-slate-300 shadow-sm focus:border-slate-500 focus:ring-slate-500 sm:text-sm"
        {@rest}
      />
      <p :for={err <- @errors} class="mt-1 text-xs text-red-600">{translate_error(err)}</p>
    </div>
    """
  end

  defp input_value(%Decimal{} = d), do: Decimal.to_string(d, :normal)
  defp input_value(%Date{} = d), do: Date.to_iso8601(d)
  defp input_value(nil), do: ""
  defp input_value(other), do: to_string(other)

  attr :for, :string, default: nil
  slot :inner_block, required: true

  def label(assigns) do
    ~H"""
    <label for={@for} class="block text-sm font-medium text-slate-700">
      {render_slot(@inner_block)}
    </label>
    """
  end

  attr :type, :string, default: "button"
  attr :class, :string, default: ""
  attr :rest, :global, include: ~w(disabled form name value phx-click phx-disable-with)
  slot :inner_block, required: true

  def button(assigns) do
    ~H"""
    <button
      type={@type}
      class={[
        "inline-flex items-center gap-1.5 rounded-md bg-slate-900 px-3.5 py-2 text-sm font-medium text-white shadow-sm hover:bg-slate-800 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-slate-900 disabled:opacity-50 disabled:cursor-not-allowed",
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </button>
    """
  end

  @doc """
  Render a `Phoenix.HTML.Form` field as one of our `input/1` variants. Pulls
  the name, value and errors from the form for you.
  """
  attr :field, Phoenix.HTML.FormField, required: true
  attr :type, :string, default: "text"
  attr :label, :string, default: nil
  attr :options, :list, default: []
  attr :step, :string, default: nil
  attr :placeholder, :string, default: nil
  attr :rest, :global, include: ~w(autocomplete phx-blur phx-change phx-debounce required)

  def field(assigns) do
    %Phoenix.HTML.FormField{} = f = assigns.field
    errors = if used_input?(f), do: f.errors, else: []

    assigns =
      assigns
      |> Map.put(:errors, Enum.map(errors, &translate_error/1))
      |> Map.put(:name, f.name)
      |> Map.put(:id, f.id)
      |> Map.put(:value, f.value)

    ~H"""
    <.input
      type={@type}
      name={@name}
      id={@id}
      value={@value}
      label={@label}
      step={@step}
      options={@options}
      placeholder={@placeholder}
      errors={@errors}
      {@rest}
    />
    """
  end

  defp used_input?(%Phoenix.HTML.FormField{} = field) do
    Phoenix.Component.used_input?(field)
  end

  def translate_error({msg, opts}) do
    Enum.reduce(opts, msg, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", to_string(value))
    end)
  end

  def translate_error(msg) when is_binary(msg), do: msg

  @doc "Format a Decimal as a currency string."
  def money(nil), do: "—"
  def money(%Decimal{} = d), do: "$" <> Decimal.to_string(Decimal.round(d, 2), :normal)
  def money(n) when is_number(n), do: "$" <> :erlang.float_to_binary(n / 1, decimals: 2)
end
