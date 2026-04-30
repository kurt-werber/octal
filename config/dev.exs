import Config

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

config :octal,
  mongo_url: System.get_env("MONGO_URL") || "mongodb://localhost:27017",
  mongo_database: System.get_env("MONGO_DATABASE") || "octal_dev"
