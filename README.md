# Octal

A small personal-finance tracker. Phoenix LiveView + MongoDB + Claude.

- Record transactions (date, vendor, amount, category, note).
- AI-suggested default amount for new vendors (history-first, AI-fallback).
- Per-category, per-month budgets with default categories you can edit.
- Visualize spend-by-category, spend-vs-budget, and a 30-day trend.
- AI Insights tab that asks Claude for suggestions over your last 90 days.

This is a single-user, no-auth v1 — designed to run locally.

## Setup

Prerequisites:
- Elixir 1.14+ / Erlang/OTP 25+
- A running MongoDB (Docker is easiest):

  ```sh
  docker run -d --name octal-mongo -p 27017:27017 mongo:7
  ```

- An Anthropic API key (optional; without it, the AI features show a friendly error and the rest of the app still works).

Install deps and assets:

```sh
mix setup
```

Set environment variables:

```sh
export MONGO_URL=mongodb://localhost:27017
export MONGO_DATABASE=octal_dev
export ANTHROPIC_API_KEY=sk-ant-...
```

Run the server:

```sh
mix phx.server
```

Visit http://localhost:4000.

## Smoke test

1. **Categories tab**: confirm the 10 defaults are seeded; add a "Coffee" category.
2. **Transactions tab → New**: type "Blue Bottle Coffee" as the vendor and tab away — Claude Haiku suggests a typical amount (badge: "AI-estimated"). Save.
3. Add another Blue Bottle transaction — this time the suggestion comes from your history (badge: "Default from your past spend").
4. **Budgets tab**: set Coffee = $80 for the current month.
5. **Visualize tab**: confirm the bar chart shows your spend.
6. **AI Insights tab**: click "Analyze" — Claude Sonnet returns 3-6 bullet suggestions.

## Architecture

- **`Octal.Application`** starts a single MongoDB pool (`name: :mongo`) and seeds default categories on first boot.
- **Contexts** under `lib/octal/` (`Categories`, `Transactions`, `Budgets`, `Analytics`, `AI`) wrap Mongo collections and expose plain Elixir-shaped data to the LiveViews.
- **Form validation** uses `Ecto.embedded_schema` + `Ecto.Changeset` (no Ecto Repo). Documents persist as plain Mongo BSON.
- **Money** is stored as `Decimal128` and exchanged as `Decimal` everywhere else.
- **Charts** are server-rendered SVG/HTML — no JS hooks beyond LiveView itself.

## Layout

```
lib/octal/                # business logic, MongoDB I/O, Anthropic client
lib/octal_web/            # endpoint, router, LiveViews, components
config/                   # config + runtime secrets reading
assets/                   # CSS, JS, Tailwind config
```

## Notes

- The default `MONGO_DATABASE` is `octal` in production and `octal_dev` in development.
- The app binds to `127.0.0.1:4000` in dev — there is no auth, do not expose it on a network.
- Indexes on `transactions`, `budgets`, `categories` are created idempotently on boot.

## License

See [LICENSE](LICENSE).
