{ pkgs, lib, config, ... }:

{
  # Elixir / Erlang toolchain
  languages.erlang.enable = true;
  languages.elixir = {
    enable = true;
    package = pkgs.elixir;
  };

  # MongoDB service — devenv manages the data directory and process lifecycle.
  # Listens on the default port 27017; pass `--port` via additionalArgs if you
  # need to change it (and update env.MONGO_URL below to match).
  services.mongodb = {
    enable = true;
    package = pkgs.mongodb-ce;  # community edition; swap for pkgs.mongodb if your nixpkgs lacks ce
  };

  # Environment variables available in the shell and to `devenv up` processes.
  env.MONGO_URL = "mongodb://localhost:27017";
  env.MONGO_DATABASE = "octal_dev";
  # Put your real key in .env (git-ignored) — devenv loads it automatically.
  # env.ANTHROPIC_API_KEY = "sk-ant-...";

  # Processes started by `devenv up`.
  processes = {
    phoenix.exec = "mix phx.server";
  };

  # Shell hook: print versions and first-time hints.
  enterShell = ''
    echo "📦 Octal dev environment"
    echo "  MongoDB : ${config.services.mongodb.package.version or "unknown"}"
    echo "  Elixir  : $(elixir --version | head -1)"
    echo ""
    echo "First time? Run:  mix setup"
    echo "Start server:     devenv up   (or just: mix phx.server)"
  '';

  devcontainer.settings.updateContentCommand = "mix setup";
}
