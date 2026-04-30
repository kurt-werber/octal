defmodule Octal.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      OctalWeb.Telemetry,
      {Phoenix.PubSub, name: Octal.PubSub},
      mongo_child_spec(),
      {Task.Supervisor, name: Octal.TaskSupervisor},
      OctalWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: Octal.Supervisor]

    case Supervisor.start_link(children, opts) do
      {:ok, _pid} = ok ->
        Task.start(fn -> seed_and_index() end)
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

  defp mongo_child_spec do
    url = Application.get_env(:octal, :mongo_url) || "mongodb://localhost:27017"
    db = Application.get_env(:octal, :mongo_database) || "octal"
    {Mongo, [name: :mongo, url: url, database: db, pool_size: 5]}
  end

  defp seed_and_index do
    # Seed default categories and ensure indexes exist. Tolerates startup
    # races where Mongo isn't ready yet — caller logs and moves on.
    try do
      Octal.Categories.ensure_defaults()
      Octal.MongoHelpers.ensure_indexes()
    rescue
      e -> require Logger; Logger.warning("seed_and_index failed: #{inspect(e)}")
    end
  end
end
