{ pkgs, lib, config, ... }:

{
  # Elixir / Erlang toolchain
  languages.erlang.enable = true;
  languages.elixir = {
    enable = true;
    package = pkgs.elixir;
  };

  # Postgres service — devenv manages the data directory and process lifecycle.
  services.postgres = {
    enable = true;
    package = pkgs.postgresql_16;
    listen_addresses = "127.0.0.1";
    initialDatabases = [ { name = "octal_dev"; } ];
    initialScript = ''
      CREATE USER postgres WITH SUPERUSER PASSWORD 'postgres';
    '';
  };

  # Environment variables available in the shell and to `devenv up` processes.
  env.PGHOST = "127.0.0.1";
  env.PGPORT = "5432";
  env.PGUSER = "postgres";
  env.PGPASSWORD = "postgres";
  env.PGDATABASE = "octal_dev";
  # Put your real key in .env (git-ignored) — devenv loads it automatically.
  # env.ANTHROPIC_API_KEY = "sk-ant-...";

  # Processes started by `devenv up`.
  processes = {
    phoenix.exec = "mix phx.server";
  };

  enterShell = ''
    echo "📦 Octal dev environment"
    echo "  Postgres : ${config.services.postgres.package.version or "unknown"}"
    echo "  Elixir   : $(elixir --version | head -1)"
    echo ""
    echo "First time? Run:  mix setup"
    echo "Start server:     devenv up   (or just: mix phx.server)"
  '';

  devcontainer.settings.updateContentCommand = "mix setup";
}
