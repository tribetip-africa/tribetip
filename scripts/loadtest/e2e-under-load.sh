#!/usr/bin/env bash
# Phase A + B: run live E2E while sustained read/write load runs, then verify consistency.
#
# Usage:
#   scripts/loadtest/e2e-under-load.sh
#   TARGET_RPM=10000 WRITE_RPM=60 DURATION=3m scripts/loadtest/e2e-under-load.sh
#   START_STACK=false scripts/loadtest/e2e-under-load.sh   # stack already up
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

TARGET_RPM="${TARGET_RPM:-10000}"
READ_RPM="${READ_RPM:-$((TARGET_RPM * 95 / 100))}"
WRITE_RPM="${WRITE_RPM:-60}"
DURATION="${DURATION:-3m}"
CREATOR_USERNAME="${CREATOR_USERNAME:-demo_creator}"
TIPPABLE_USERNAME="${TIPPABLE_USERNAME:-}"
HOST_HEALTH_URL="${HOST_HEALTH_URL:-http://localhost:3001}"
E2E_API_URL="${E2E_API_URL:-$HOST_HEALTH_URL}"
START_STACK="${START_STACK:-true}"
LOAD_PROFILE="${LOAD_PROFILE:-write}" # write | read
RESULTS_DIR="$ROOT/scripts/loadtest/results"
COMPOSE=(docker compose -f docker-compose.yml -f docker-compose.prod.yml -f docker-compose.loadtest.yml --env-file .env.docker.prod)

mkdir -p "$RESULTS_DIR"

log() {
  printf "\n\033[1m[load+e2e]\033[0m %s\n" "$1"
}

wait_for_health() {
  log "Waiting for API health at ${HOST_HEALTH_URL}/up ..."
  for i in $(seq 1 90); do
    if curl -fsS "${HOST_HEALTH_URL}/up" >/dev/null 2>&1; then
      log "API is healthy."
      return 0
    fi
    sleep 2
  done
  echo "API did not become healthy in time." >&2
  exit 1
}

snapshot() {
  local path="$1"
  "${COMPOSE[@]}" exec -T api bin/rails runner scripts/loadtest/snapshot-consistency.rb > "$path"
}

resolve_tippable_username() {
  local seed_password="${TRIBETIP_SEED_PASSWORD:-localdev}"
  local sign_in_body
  sign_in_body="$(curl -sS -X POST "${HOST_HEALTH_URL}/tribes/sign_in.json" \
    -H "Content-Type: application/json" \
    -d "{\"tribe\":{\"login\":\"admin@tribetip.africa\",\"password\":\"${seed_password}\"}}")"

  local admin_token
  admin_token="$(ruby -rjson -e 'puts JSON.parse(STDIN.read).fetch("token", "")' <<<"$sign_in_body" 2>/dev/null || true)"
  if [[ -z "$admin_token" ]]; then
    echo "$CREATOR_USERNAME"
    return
  fi

  local username
  username="$(curl -sS -H "Authorization: Bearer ${admin_token}" "${HOST_HEALTH_URL}/admin/tribes" \
    | ruby -rjson -e '
        tribes = JSON.parse(STDIN.read).fetch("tribes", [])
        match = tribes.find do |t|
          t["role"] == "creator" &&
            t["account_status"] == "active" &&
            t["is_profile_public"] &&
            t["paystack_onboarding_complete"]
        end
        puts(match["username"]) if match
      ' 2>/dev/null || true)"

  if [[ -n "$username" ]]; then
    echo "$username"
  else
    echo "$CREATOR_USERNAME"
  fi
}

if [[ "$START_STACK" == "true" ]]; then
  log "Starting production + loadtest Docker stack ..."
  bin/docker prod -f docker-compose.loadtest.yml up --build -d
fi

wait_for_health

if [[ -z "$TIPPABLE_USERNAME" ]]; then
  TIPPABLE_USERNAME="$(resolve_tippable_username)"
fi
log "Public read profile: ${CREATOR_USERNAME} | Tip writes target: ${TIPPABLE_USERNAME}"

BEFORE_SNAPSHOT="$RESULTS_DIR/snapshot-before.json"
AFTER_SNAPSHOT="$RESULTS_DIR/snapshot-after.json"
K6_LOG="$RESULTS_DIR/k6-under-load.log"

log "Capturing pre-run consistency snapshot ..."
snapshot "$BEFORE_SNAPSHOT"

log "Starting background load (${LOAD_PROFILE}): ${READ_RPM} read RPM + ${WRITE_RPM} write RPM for ${DURATION} ..."
if [[ "$LOAD_PROFILE" == "read" ]]; then
  (
    TARGET_RPM="$READ_RPM" DURATION="$DURATION" CREATOR_USERNAME="$CREATOR_USERNAME" \
      ./scripts/loadtest/run.sh
  ) >"$K6_LOG" 2>&1 &
else
  (
    READ_RPM="$READ_RPM" WRITE_RPM="$WRITE_RPM" DURATION="$DURATION" \
      CREATOR_USERNAME="$CREATOR_USERNAME" TIPPABLE_USERNAME="$TIPPABLE_USERNAME" \
      ./scripts/loadtest/run-write.sh
  ) >"$K6_LOG" 2>&1 &
fi
K6_PID=$!

cleanup_k6() {
  if kill -0 "$K6_PID" 2>/dev/null; then
    wait "$K6_PID" || true
  fi
}
trap cleanup_k6 EXIT

sleep 5

log "Running live E2E against ${E2E_API_URL} while load is active ..."
E2E_FAILED=0
if ! E2E_UNDER_LOAD=true TRIBETIP_API_URL="$E2E_API_URL" script/e2e_api.sh "$E2E_API_URL"; then
  E2E_FAILED=1
fi

log "Waiting for background k6 run to finish ..."
set +e
wait "$K6_PID"
K6_EXIT=$?
set -e
trap - EXIT

log "Capturing post-run consistency snapshot ..."
snapshot "$AFTER_SNAPSHOT"

log "Verifying data consistency ..."
CONSISTENCY_FAILED=0
if ! "${COMPOSE[@]}" exec -T api bin/rails runner scripts/loadtest/verify-consistency.rb \
  "/rails/scripts/loadtest/results/$(basename "$BEFORE_SNAPSHOT")" \
  "/rails/scripts/loadtest/results/$(basename "$AFTER_SNAPSHOT")"; then
  CONSISTENCY_FAILED=1
fi

printf "\n\033[1m=== Load + E2E summary ===\033[0m\n"
printf "  Load profile:     %s\n" "$LOAD_PROFILE"
printf "  Read target:      %s RPM\n" "$READ_RPM"
printf "  Write target:     %s RPM\n" "$WRITE_RPM"
printf "  Duration:         %s\n" "$DURATION"
printf "  k6 exit code:     %s\n" "$K6_EXIT"
printf "  E2E:              %s\n" "$([[ "$E2E_FAILED" -eq 0 ]] && echo passed || echo FAILED)"
printf "  Consistency:      %s\n" "$([[ "$CONSISTENCY_FAILED" -eq 0 ]] && echo passed || echo FAILED)"
printf "  Snapshots:        %s\n" "$RESULTS_DIR"
printf "  k6 log:           %s\n" "$K6_LOG"

if [[ -f "$RESULTS_DIR/summary-write.json" ]]; then
  printf "  k6 metrics:       %s/summary-write.json\n" "$RESULTS_DIR"
elif [[ -f "$RESULTS_DIR/summary.json" ]]; then
  printf "  k6 metrics:       %s/summary.json\n" "$RESULTS_DIR"
fi

if [[ "$K6_EXIT" -ne 0 || "$E2E_FAILED" -ne 0 || "$CONSISTENCY_FAILED" -ne 0 ]]; then
  echo ""
  echo "One or more checks failed. Tail of k6 log:"
  tail -n 40 "$K6_LOG" || true
  exit 1
fi

printf "\n\033[32mLoad + E2E + consistency checks passed.\033[0m\n"
