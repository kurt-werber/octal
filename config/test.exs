import Config

pghost = System.get_env("PGHOST", "localhost")

db_connect =
  if String.starts_with?(pghost, "/"),
    do: [socket_dir: pghost],
    else: [hostname: pghost]

config :octal, Octal.Repo,
  [
    username: System.get_env("PGUSER", "postgres"),
    password: System.get_env("PGPASSWORD", "postgres"),
    port: String.to_integer(System.get_env("PGPORT", "5432")),
    database: "octal_test",
    pool: Ecto.Adapters.SQL.Sandbox,
    pool_size: 10
  ] ++ db_connect

config :octal, OctalWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "test-secret-key-base-1234567890abcdef1234567890abcdef1234567890abcdef1234567890",
  server: false

config :logger, level: :warning
config :phoenix, :plug_init_mode, :runtime
