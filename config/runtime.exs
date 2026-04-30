import Config

if System.get_env("PHX_SERVER") do
  config :octal, OctalWeb.Endpoint, server: true
end

config :octal,
  anthropic_api_key: System.get_env("ANTHROPIC_API_KEY"),
  mongo_url: System.get_env("MONGO_URL") || "mongodb://localhost:27017",
  mongo_database: System.get_env("MONGO_DATABASE") || "octal"

if config_env() == :prod do
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      Generate one with: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "example.com"
  port = String.to_integer(System.get_env("PORT") || "4000")

  config :octal, OctalWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port
    ],
    secret_key_base: secret_key_base
end
