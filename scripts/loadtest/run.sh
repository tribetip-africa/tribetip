#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

BASE_URL="${BASE_URL:-http://api:80}"
HOST_HEALTH_URL="${HOST_HEALTH_URL:-http://localhost:3001}"
TARGET_RPM="${TARGET_RPM:-10000}"
DURATION="${DURATION:-3m}"
CREATOR_USERNAME="${CREATOR_USERNAME:-demo_creator}"
K6_SCRIPT="${K6_SCRIPT:-k6-mixed.js}"
RESULTS_DIR="$ROOT/scripts/loadtest/results"
COMPOSE=(docker compose -f docker-compose.yml -f docker-compose.prod.yml --env-file .env.docker.prod)

mkdir -p "$RESULTS_DIR"

echo "Waiting for API health at ${HOST_HEALTH_URL}/up ..."
for i in $(seq 1 60); do
  if curl -fsS "${HOST_HEALTH_URL}/up" >/dev/null 2>&1; then
    echo "API is healthy."
    break
  fi
  if [[ "$i" -eq 60 ]]; then
    echo "API did not become healthy in time." >&2
    exit 1
  fi
  sleep 2
done

NETWORK="$("${COMPOSE[@]}" ps -q api | xargs docker inspect -f '{{range $k, $v := .NetworkSettings.Networks}}{{$k}}{{end}}' 2>/dev/null || true)"
if [[ -z "$NETWORK" ]]; then
  echo "Could not detect tribetip Docker network. Is bin/docker prod up running?" >&2
  exit 1
fi

echo "Running k6 (${K6_SCRIPT}) on network ${NETWORK}: ${TARGET_RPM} RPM (~$((TARGET_RPM / 60))/s) for ${DURATION} ..."
docker run --rm \
  --network "$NETWORK" \
  -e BASE_URL="$BASE_URL" \
  -e TARGET_RPM="$TARGET_RPM" \
  -e DURATION="$DURATION" \
  -e HOST_HEADER="${HOST_HEADER:-localhost}" \
  -e CREATOR_USERNAME="$CREATOR_USERNAME" \
  -v "$ROOT/scripts/loadtest/${K6_SCRIPT}:/scripts/${K6_SCRIPT}:ro" \
  -v "$RESULTS_DIR:/results" \
  grafana/k6:latest run "/scripts/${K6_SCRIPT}"

echo ""
echo "Full metrics: ${RESULTS_DIR}/summary.json"
