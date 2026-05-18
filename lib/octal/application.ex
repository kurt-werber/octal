defmodule Octal.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      OctalWeb.Telemetry,
      Octal.Repo,
      {Phoenix.PubSub, name: Octal.PubSub},
      {Task.Supervisor, name: Octal.TaskSupervisor},
      OctalWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: Octal.Supervisor]

    case Supervisor.start_link(children, opts) do
      {:ok, _pid} = ok ->
        Task.start(fn -> seed() end)
        ok

      other ->
        other
    end
  end

  @impl true
  def config_change(changed, _new, removed) do
    OctalWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp seed do
    try do
      Octal.Categories.ensure_defaults()
    rescue
      e ->
        require Logger
        Logger.warning("Category seed failed: #{inspect(e)}")
    end
  end
end
