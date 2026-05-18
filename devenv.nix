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
    initialDatabases = [ { name = "octal_dev"; } ];
    initialScript = ''
      CREATE USER postgres WITH SUPERUSER PASSWORD 'postgres';
    '';
  };

  # Environment variables available in the shell and to `devenv up` processes.
  # PGHOST, PGPORT, and PGDATABASE are set automatically by services.postgres.
  env.PGUSER = "postgres";
  env.PGPASSWORD = "postgres";
  # Put your real key in .env (git-ignored) — devenv loads it automatically.
  # env.ANTHROPIC_API_KEY = "sk-ant-...";

  # Processes started by `devenv up`.
  # `setup` runs once after Postgres is healthy; `phoenix` waits for it to finish.
  processes = {
    setup = {
      exec = "until pg_isready -h $PGHOST -p $PGPORT -q; do sleep 1; done && mix setup";
      process-compose = {
        depends_on.postgres.condition = "process_started";
        availability.restart = "no";
      };
    };
    phoenix = {
      exec = "mix phx.server";
      process-compose.depends_on.setup.condition = "process_completed_successfully";
    };
  };

  enterShell = ''
    echo "📦 Octal dev environment"
    echo "  Postgres : ${config.services.postgres.package.version or "unknown"}"
    echo "  Elixir   : $(elixir --version | awk '/^Elixir/')"
    echo ""
    echo "Start everything:  devenv up   (postgres → mix setup → phx.server)"
  '';

  devcontainer.settings.updateContentCommand = "mix setup";
}
