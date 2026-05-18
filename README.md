# Octal

A small personal-finance tracker. Phoenix LiveView + Postgres + Claude.

- Record transactions (date, vendor, amount, category, note).
- AI-suggested default amount for new vendors (history-first, AI-fallback).
- Per-category, per-month budgets with default categories you can edit.
- Visualize spend-by-category, spend-vs-budget, and a 30-day trend.
- AI Insights tab that asks Claude for suggestions over your last 90 days.

This is a single-user, no-auth v1 — designed to run locally.

## Setup (recommended: devenv)

[devenv](https://devenv.sh) provides a reproducible shell with Elixir,
Erlang, and a managed Postgres process — no Docker or manual installs needed.

### 1. Install devenv

Follow the [devenv getting started guide](https://devenv.sh/getting-started/).
Short version on most systems:

```sh
nix profile install nixpkgs#devenv
```

### 2. Clone and enter the environment

```sh
git clone <repo-url> octal
cd octal
devenv shell
```

On first entry you'll see a short summary of versions. The Nix build only
runs once; subsequent `devenv shell` invocations are instant.

### 3. Set your Anthropic API key (optional)

AI features are optional — the app works fully without them.

```sh
echo 'ANTHROPIC_API_KEY=sk-ant-...' >> .env
```

### 4. Install deps, create DB, build assets

```sh
mix setup
```

This installs Hex deps, creates the `octal_dev` database, runs migrations,
seeds default categories, and builds assets.

### 5. Start everything

```sh
devenv up
```

This starts Postgres and `mix phx.server` together. Visit http://localhost:4000.

Or run them separately:

```sh
devenv up postgres &   # just Postgres
mix phx.server         # Phoenix in the foreground
```

---

## Setup (manual, without devenv)

Prerequisites:
- Elixir 1.14+ / Erlang/OTP 25+
- Postgres 14+

```sh
# Postgres via Docker
docker run -d --name octal-pg \
  -e POSTGRES_PASSWORD=postgres \
  -p 5432:5432 postgres:16

export PGUSER=postgres
export PGPASSWORD=postgres
export PGHOST=localhost
export PGDATABASE=octal_dev
export ANTHROPIC_API_KEY=sk-ant-...   # optional

mix setup
mix phx.server
```

Visit http://localhost:4000.

---

## Smoke test

1. **Categories** — confirm the 10 defaults are seeded; add a "Coffee" category.
2. **Transactions → New** — type "Blue Bottle Coffee" as the vendor and tab away — Claude Haiku suggests a typical amount (badge: "AI-estimated"). Save.
3. Add another Blue Bottle transaction — amount comes from your history (badge: "Default from your past spend").
4. **Budgets** — set Coffee = $80 for the current month.
5. **Visualize** — confirm the bar charts render.
6. **AI Insights** — click "Analyze" — Claude Sonnet returns 3-6 bullet suggestions.

## Architecture

- **`Octal.Repo`** is a standard Ecto/Postgres repo. Schemas live in `lib/octal/*/`.
- **Contexts** under `lib/octal/` (`Categories`, `Transactions`, `Budgets`, `Analytics`, `AI`) wrap the repo and expose Ecto structs to the LiveViews.
- **Migrations** in `priv/repo/migrations/` create three tables (`categories`, `transactions`, `budgets`) with appropriate indexes.
- **Defaults** are upserted at boot via `on_conflict: :nothing` on `categories.name`.
- **Money** is stored as `numeric(14,2)` in Postgres and as `Decimal` in Elixir.
- **Medians** use Postgres's `percentile_cont(0.5)` aggregate so vendor-history lookups stay fast.
- **Charts** are server-rendered HTML/CSS bars — no extra JS beyond LiveView.

## Layout

```
devenv.nix              # reproducible dev environment (Elixir + Postgres)
lib/octal/              # business logic, repo, schemas, Anthropic client
lib/octal_web/          # endpoint, router, LiveViews, components
priv/repo/migrations/   # schema migrations
priv/repo/seeds.exs     # seeds default categories
config/                 # config.exs + runtime.exs (reads env vars)
assets/                 # Tailwind CSS, JS (esbuild), topbar
```

## Notes

- The server binds to `127.0.0.1:4000` in dev — no auth, don't expose it.
- Renaming a category cascades into existing transactions and budgets.
- Deleting a default or in-use category is blocked with a flash.
- Run `mix ecto.reset` to drop and recreate the database with seeds.

## License

See [LICENSE](LICENSE).
