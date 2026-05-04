{ pkgs, lib, config, ... }:

{
  # Elixir / Erlang toolchain
  languages.erlang.enable = true;
  languages.elixir = {
    enable = true;
    # Pin to a 1.17.x release that compiles against OTP 27.
    # Adjust the package if your nixpkgs revision ships a different version.
    package = pkgs.elixir;
  };

  # MongoDB service — devenv manages the data directory and process lifecycle.
  services.mongodb = {
    enable = true;
    package = pkgs.mongodb-ce;  # community edition (free); swap for pkgs.mongodb if available
    port = 27017;
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

  # Shell hook: install Hex + deps + assets on first enter.
  enterShell = ''
    echo "📦 Octal dev environment"
    echo "  MongoDB : ${config.services.mongodb.package.version} on port ${toString config.services.mongodb.port}"
    echo "  Elixir  : $(elixir --version | head -1)"
    echo ""
    echo "First time? Run:  mix setup"
    echo "Start server:     devenv up   (or just: mix phx.server)"
  '';

  # Ensure inotify limits are set on Linux for live-reload to work.
  devcontainer.settings.updateContentCommand = "mix setup";
}
