import Config

config :octal,
  ecto_repos: [Octal.Repo],
  generators: [timestamp_type: :utc_datetime, binary_id: true]

config :octal, OctalWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: OctalWeb.ErrorHTML, json: OctalWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Octal.PubSub,
  live_view: [signing_salt: "8rEQT4hP"]

config :esbuild,
  version: "0.17.11",
  octal: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

config :tailwind,
  version: "3.4.3",
  octal: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :phoenix, :json_library, Jason

import_config "#{config_env()}.exs"
