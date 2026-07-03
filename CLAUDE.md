# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Octal is a single-user, no-auth personal-finance tracker: Phoenix 1.7 LiveView + Ecto/Postgres, with optional Anthropic API integration. It runs locally and binds to `127.0.0.1:4000` in dev.

## Commands

Postgres must be reachable before most mix tasks. Connection settings come from standard `PG*` env vars (`PGHOST`, `PGPORT`, `PGUSER`, `PGPASSWORD`); `PGHOST` starting with `/` is treated as a socket dir. The dev DB is `octal_dev`, the test DB is `octal_test`.

```sh
mix setup            # deps.get + ecto.create/migrate + seeds + assets
mix phx.server       # run the app at http://localhost:4000
mix test             # creates/migrates octal_test, then runs tests
mix test test/octal/ai_test.exs           # single file
mix test test/octal/ai_test.exs:29        # single test by line
mix format           # required formatter (includes HEEx via Phoenix.LiveView.HTMLFormatter)
mix ecto.reset       # drop + recreate + migrate + seed
```

With [devenv](https://devenv.sh) installed, `devenv shell` provides Elixir/Erlang and a managed Postgres; `devenv up` starts Postgres → `mix setup` → `mix phx.server` in order.

AI features need `ANTHROPIC_API_KEY` (read in `config/runtime.exs`); the app degrades gracefully without it. Tests rely on the key being **absent** — AI tests assert `{:error, :missing_api_key}` and make no HTTP calls.

## Architecture

`lib/octal/` holds contexts; `lib/octal_web/` holds the web layer. Each nav tab is one LiveView at `lib/octal_web/live/<name>_live/index.ex` (Transactions, Budgets, Categories, Visualizations, AI Insights), routed in `router.ex` with all actions (`:index`/`:new`/`:edit`) on the same LiveView module and each setting a `current_tab` assign for the nav.

### Categories are linked by name, not foreign key

`transactions.category` and `budgets.category` are plain strings matching `categories.name`. This has consequences that span files:

- Renaming a category (`Octal.Categories.update/2`) manually cascades `update_all` renames into transactions and budgets.
- Deleting is blocked for default categories (`{:error, :is_default}`) and for categories referenced by any transaction (`{:error, :in_use}`).
- The 10 default categories are seeded idempotently (`insert_all` with `on_conflict: :nothing` on `name`) both from `priv/repo/seeds.exs` and at boot via a `Task` in `Octal.Application.start/2`.

### Money and time conventions

- Amounts are `Decimal` in Elixir, `numeric(14,2)` in Postgres. Compare with `Decimal.compare/2` / `Decimal.equal?/2`, never `==` or `<`.
- Budgets are keyed by `(category, year_month)` where `year_month` is a `"YYYY-MM"` string; `Budgets.set_limit/1` is an upsert on that pair.
- All schemas use `binary_id` UUID primary keys and `:utc_datetime` timestamps.

### AI integration (`lib/octal/ai.ex`)

Direct `Req` calls to the Anthropic Messages API — no SDK. Two entry points:

- `suggest_amount/1`: history-first (median of the vendor's past amounts via Postgres `percentile_cont(0.5)` in `Transactions.median_for_vendor/1`, case-insensitive), falling back to a Haiku estimate. The returned source (`:history` | `:ai`) drives the UI badge.
- `analyze/2`: Sonnet-backed insights for the AI Insights tab.

The API key is read via `Application.get_env(:octal, :anthropic_api_key)`; a missing key returns `{:error, :missing_api_key}` without making a request.

### Analytics and charts

`Octal.Analytics` does all aggregation in SQL (`group_by` + `sum`), then pads results with zero rows for every category/day so chart axes stay stable. Charts are server-rendered HTML/CSS bars in the LiveViews — no chart JS.

## Testing

- Context tests use `Octal.DataCase`, LiveView tests use `OctalWeb.ConnCase` (both in `test/support/`, compiled only in `:test` via `elixirc_paths`). Both use the SQL sandbox and support `async: true`.
- LiveView tests use `Phoenix.LiveViewTest` + Floki and run `async: false` with `Octal.Categories.ensure_defaults()` in setup — the boot-time seeding task runs outside the sandbox, so default categories are not otherwise present in tests.
- Changesets do not validate that a category name exists, so context tests can use names like `"Dining"` without seeding.
