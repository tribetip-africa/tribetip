# TribeTip API

Rails JSON API for [TribeTip](https://tribetip.africa) — creator accounts, Paystack tips and payouts, webhooks, and admin operations.

The Next.js frontend lives in the sibling [`frontend`](../frontend) repository.

## Stack

- Ruby 3.3.6 / Rails 8
- PostgreSQL
- Devise + JWT authentication
- Paystack (checkout, subaccounts, settlements, transfers, webhooks)
- Solid Queue (background jobs) and Solid Cache (production caching)
- Rack::Attack rate limiting

## Prerequisites

- Ruby 3.3.6 (see `.ruby-version`)
- PostgreSQL 16+
- Bundler 4.x

Optional: Docker for the all-in-one dev stack.

## Quick start (local)

```bash
cp .env.example .env          # optional; sensible dev defaults exist
bin/setup                     # bundle install, db:prepare, git hooks
bin/rails server -p 3001      # API on http://localhost:3001
```

`bin/setup` seeds development accounts by default. Sign in with any seeded username and password `TribetipDev1!` (see `bin/rails db:seed` output).

Start the frontend from `../frontend` on port 3000.

## Docker

```bash
bin/docker up --build         # API on http://localhost:3001, Postgres, Solid Queue worker
bin/docker logs -f worker     # webhook + Paystack jobs
bin/docker down
```

### Production-like stack (load testing)

Tuned Puma workers, healthchecks, Postgres limits, and resource caps. Rate limits stay at production defaults.

```bash
bin/docker prod down
bin/docker prod up --build -d
bin/docker prod ps            # wait until api is healthy
scripts/loadtest/run.sh       # 10k RPM mixed traffic (~3 min)
```

Copy `.env.docker.example` to `.env.docker` automatically on first run. Docker seeds with password `localdev` when `TRIBETIP_SEED_ENABLED=true`.

### Paystack webhooks locally

```bash
bin/docker up --build
bin/ngrok-webhook             # exposes http://localhost:3001
# Add https://<ngrok-host>/paystack/webhook in Paystack dashboard
bin/docker logs -f worker
```

## Configuration

See [`.env.example`](.env.example) for the full list. Highlights:

| Area | Notes |
|------|--------|
| URLs | `TRIBETIP_PLATFORM_URL` (web), `TRIBETIP_API_URL` (API) |
| Paystack | Leave `PAYSTACK_SECRET_KEY` blank for stub mode; set `sk_test_...` for real test API calls |
| Payout mode | `TRIBETIP_PAYOUT_MODE=auto` (default), `manual`, or `both` |
| Regions | Kenya enabled by default; override with `TRIBETIP_ENABLED_REGIONS` |
| Rate limits | `RACK_ATTACK_*` vars for public tip checkout/reconcile endpoints |
| Checkout waits | `TRIBETIP_CHECKOUT_WAIT_SECONDS`, `TRIBETIP_ONBOARDING_WAIT_SECONDS`, etc. |

Production requires `TRIBETIP_DATABASE_PASSWORD`, `DEVISE_JWT_SECRET_KEY`, `APP_HOSTS`, and `CORS_ALLOWED_ORIGINS`.

## API surface (summary)

| Area | Examples |
|------|----------|
| Health | `GET /up` |
| Auth | Devise routes under `/tribes` |
| Public profiles | `GET /tribes/:username`, `GET /share/:token` |
| Tips | `POST /tips`, `GET /tips/checkout/:ref`, `POST /tips/:ref/reconcile` |
| Creator (`/me`) | profile, tips, notifications, Paystack onboarding/settlements/withdrawals |
| Admin | tribes, settlements, webhook replay, payment alerts, platform reconciliation |
| Webhooks | `POST /paystack/webhook` |

Creator and admin routes require a Bearer JWT from sign-in.

## Background jobs

Production recurring tasks (`config/recurring.yml`):

- Reconcile stale pending tips (every 15 minutes)
- Retry failed Paystack webhooks (hourly)
- Sync settlements from Paystack (hourly)
- Platform reconciliation audit (every 6 hours)

Run the worker locally with `bin/jobs` or via Docker (`worker` service).

## Database

```bash
bin/rails db:prepare          # create + migrate (+ seed in development)
bin/rails db:seed             # idempotent dev seeds
```

**Test environment:** `db:prepare` does **not** seed unless `TRIBETIP_SEED_ENABLED=true`. This keeps RSpec fixtures isolated from seeded `platform_admin` / `demo_creator` accounts.

## Tests

```bash
bin/rails spec                              # full RSpec suite
bundle exec rspec spec/lib/tribetip/errors  # error-handling specs only
bin/rubocop -f github
bin/brakeman --no-pager -q -w2
bundle exec bundle-audit check --update
bin/rails zeitwerk:check
```

## CI

GitHub Actions (`.github/workflows/ci.yml`) runs on push/PR to `main`:

- RuboCop
- Zeitwerk autoload check
- Brakeman + `bundle-audit`
- RSpec (with Postgres service)
- Error-handling specs

### Run CI locally with act

```bash
act push -W .github/workflows/ci.yml --container-architecture linux/amd64 --concurrent-jobs 1 --env-file .github/act.env
```

Use `--concurrent-jobs 1` so Postgres service containers do not fight for port 5432. On Apple Silicon, `--container-architecture linux/amd64` matches GitHub-hosted runners.

## Ops helpers

```bash
bin/simulate-settlement USERNAME   # record a stub settlement for a paid tip
bin/ngrok-webhook                  # tunnel for Paystack webhooks
```

## Security notes

- Public tip JSON omits supporter contact fields; share-link and checkout responses use scoped idempotency keys.
- Paystack webhook payloads are redacted before persistence.
- Platform reconciliation records payment alerts for drift (stale tips, webhook backlog, settlement conflicts, etc.).
