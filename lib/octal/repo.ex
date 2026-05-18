defmodule Octal.Repo do
  use Ecto.Repo,
    otp_app: :octal,
    adapter: Ecto.Adapters.Postgres
end
