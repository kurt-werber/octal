import Config

pghost = System.get_env("PGHOST", "localhost")

# devenv's postgres runs unix-socket-only; PGHOST is the socket directory path.
# Fall back to TCP hostname for other environments.
db_connect =
  if String.starts_with?(pghost, "/"),
    do: [socket_dir: pghost],
    else: [hostname: pghost]

config :octal, Octal.Repo,
  [
    username: System.get_env("PGUSER", "postgres"),
    password: System.get_env("PGPASSWORD", "postgres"),
    port: String.to_integer(System.get_env("PGPORT", "5432")),
    database: System.get_env("PGDATABASE", "octal_dev"),
    stacktrace: true,
    show_sensitive_data_on_connection_error: true,
    pool_size: 10
  ] ++ db_connect

config :octal, OctalWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4000],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "change-me-in-prod-this-is-a-dev-only-secret-key-base-1234567890abcdef",
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:octal, ~w(--sourcemap=inline --watch)]},
    tailwind: {Tailwind, :install_and_run, [:octal, ~w(--watch)]}
  ]

config :octal, OctalWeb.Endpoint,
  live_reload: [
    patterns: [
      ~r"priv/static/(?!uploads/).*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"lib/octal_web/(controllers|live|components)/.*(ex|heex)$"
    ]
  ]

config :octal, dev_routes: true

config :logger, :console, format: "[$level] $message\n"
config :phoenix, :stacktrace_depth, 20
config :phoenix, :plug_init_mode, :runtime
config :phoenix_live_view, :debug_heex_annotations, true
