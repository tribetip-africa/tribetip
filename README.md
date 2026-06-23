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
scripts/loadtest/run.sh              # 10k RPM read-only mixed traffic (~3 min)
scripts/loadtest/run-write.sh        # ~9.5k RPM reads + write traffic (tips/checkout/reconcile)
scripts/loadtest/e2e-under-load.sh   # E2E smoke test during sustained load + consistency verify
```

Load + E2E (Phase A/B):

```bash
bin/docker prod -f docker-compose.loadtest.yml up --build -d
TARGET_RPM=10000 WRITE_RPM=60 DURATION=3m scripts/loadtest/e2e-under-load.sh
```

`WRITE_RPM` defaults to 60 (~1/s) so tip checkout hits Paystack test mode safely while reads soak at ~9.5k RPM.
Set `LOADTEST_STRICT_RECONCILE=true` to fail on historical Paystack drift (seed paid tips vs live verify).

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
| Rate limits | See [Rack::Attack](#rackattack) below |
| Checkout waits | `TRIBETIP_CHECKOUT_WAIT_SECONDS`, `TRIBETIP_ONBOARDING_WAIT_SECONDS`, etc. |

Production requires `TRIBETIP_DATABASE_PASSWORD`, `DEVISE_JWT_SECRET_KEY`, `APP_HOSTS`, and `CORS_ALLOWED_ORIGINS`.

## Rack::Attack

API rate limits return `429` with `{ "error": { "code": "rate_limited" } }`. Throttle keys are scoped so unrelated users do not share the same bucket (e.g. tipping creator A does not block creator B on the same IP).

**Note:** Paystack’s own API rate limits are **per secret key** (platform-wide). Checkout jobs queue and retry on Paystack `Rate limit exceeded` responses — see `TRIBETIP_PAYSTACK_*` in `.env.example`.

| Endpoint | Throttle key | Env var (default / min) |
|----------|--------------|-------------------------|
| `GET /tribes/:username` | `profile:{ip}:{username}` | `RACK_ATTACK_PUBLIC_PROFILE_LIMIT` (60/min) |
| `GET /share/:token` | `share:{ip}:{token}` | `RACK_ATTACK_SHARE_PROFILE_LIMIT` (180/min) |
| `GET /widget/config` | `widget:{ip}` | `RACK_ATTACK_WIDGET_CONFIG_LIMIT` (120/min) |
| `POST /tips` | `tip-create:{ip}:{creator}` | `RACK_ATTACK_TIPS_LIMIT` (30/min) |
| `GET /tips/checkout/:ref` | `tip-checkout:{ip}:{ref}` | `RACK_ATTACK_TIP_CHECKOUT_LIMIT` (30/min) |
| `POST /tips/:ref/reconcile` | `tip-reconcile:{ip}:{ref}` | `RACK_ATTACK_TIP_RECONCILE_LIMIT` (20/min) |
| `POST /me/paystack/repair` | `account:{bearer_hash}` | fixed 6 / 5 min |
| `POST /me/paystack/withdrawals` | `account:{bearer_hash}` | fixed 6 / 5 min |
| `POST /tribes/sign_in` | per email + per IP | fixed 5/min email, 10/min IP |
| `POST /admin/tribes/:id/repair` | per IP | fixed 10 / 5 min |

Implementation: `config/initializers/rack_attack.rb`, keys in `lib/tribetip/rack_attack_keys.rb`.

For load tests, `docker-compose.loadtest.yml` raises the `RACK_ATTACK_*` limits. Do not use those overrides in production unless you intend to.

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
