# Octal

A small personal-finance tracker. Phoenix LiveView + MongoDB + Claude.

- Record transactions (date, vendor, amount, category, note).
- AI-suggested default amount for new vendors (history-first, AI-fallback).
- Per-category, per-month budgets with default categories you can edit.
- Visualize spend-by-category, spend-vs-budget, and a 30-day trend.
- AI Insights tab that asks Claude for suggestions over your last 90 days.

This is a single-user, no-auth v1 — designed to run locally.

## Setup (recommended: devenv)

[devenv](https://devenv.sh) provides a reproducible shell with Elixir,
Erlang, and a managed MongoDB process — no Docker or manual installs needed.

### 1. Install devenv

Follow the [devenv getting started guide](https://devenv.sh/getting-started/).
The short version on most systems:

```sh
nix-env -iA devenv -f https://github.com/NixOS/nixpkgs/tarball/nixpkgs-unstable
```

Or with the Determinate Nix installer:

```sh
nix profile install nixpkgs#devenv
```

### 2. Clone and enter the environment

```sh
git clone <repo-url> octal
cd octal
devenv shell       # downloads Elixir + Erlang + MongoDB; drops you into the dev shell
```

On first entry you'll see a short summary of versions. You only need to wait
for the Nix build once; subsequent `devenv shell` invocations are instant.

### 3. Set your Anthropic API key

AI features are optional — the app works fully without them. If you want them:

```sh
# .env is git-ignored; devenv loads it automatically on shell entry
echo 'ANTHROPIC_API_KEY=sk-ant-...' >> .env
```

### 4. Install Elixir deps and build assets

```sh
mix setup
```

### 5. Start everything

```sh
devenv up
```

This starts MongoDB on port 27017 and `mix phx.server` together. Visit
http://localhost:4000.

Alternatively, run them separately:

```sh
devenv up mongodb &   # just MongoDB
mix phx.server        # Phoenix in the foreground
```

---

## Setup (manual, without devenv)

Prerequisites:
- Elixir 1.14+ / Erlang/OTP 25+
- MongoDB 6+ (Docker is easiest):

  ```sh
  docker run -d --name octal-mongo -p 27017:27017 mongo:7
  ```

- An Anthropic API key (optional).

```sh
export MONGO_URL=mongodb://localhost:27017
export MONGO_DATABASE=octal_dev
export ANTHROPIC_API_KEY=sk-ant-...   # optional

mix setup
mix phx.server
```

Visit http://localhost:4000.

---

## Smoke test

1. **Categories tab** — confirm the 10 defaults are seeded; add a "Coffee" category.
2. **Transactions → New** — type "Blue Bottle Coffee" as the vendor and tab away — Claude Haiku suggests a typical amount (badge: "AI-estimated"). Save.
3. Add another Blue Bottle transaction — amount comes from your history (badge: "Default from your past spend").
4. **Budgets** — set Coffee = $80 for the current month.
5. **Visualize** — confirm the bar charts render.
6. **AI Insights** — click "Analyze" — Claude Sonnet returns 3-6 bullet suggestions.

## Architecture

- **`Octal.Application`** starts a single MongoDB pool (`name: :mongo`) and seeds default categories on first boot.
- **Contexts** under `lib/octal/` (`Categories`, `Transactions`, `Budgets`, `Analytics`, `AI`) wrap Mongo collections and expose plain Elixir maps to the LiveViews.
- **Form validation** uses `Ecto.embedded_schema` + `Ecto.Changeset` (no Ecto Repo). Documents persist as plain Mongo BSON.
- **Money** is stored as `Decimal128` in Mongo and as `Decimal` in Elixir everywhere else.
- **Charts** are server-rendered HTML/CSS bars — no extra JS beyond LiveView.

## Layout

```
devenv.nix            # reproducible dev environment (Elixir + MongoDB)
lib/octal/            # business logic, MongoDB I/O, Anthropic client
lib/octal_web/        # endpoint, router, LiveViews, components
config/               # config.exs + runtime.exs (reads env vars)
assets/               # Tailwind CSS, JS (esbuild), topbar
```

## Notes

- `MONGO_DATABASE` defaults to `octal_dev` in dev and `octal` in prod.
- The server binds to `127.0.0.1:4000` in dev — no auth, don't expose it.
- Indexes on `transactions`, `budgets`, `categories` are created idempotently at boot.
- Rename a category → all linked transactions and budgets update automatically.
- Delete a category → blocked if it's a default or has linked transactions.

## License

See [LICENSE](LICENSE).
