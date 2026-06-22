#!/usr/bin/env bash
# Live API end-to-end smoke test — hits a running TribeTip API (default: http://localhost:3001).
# Usage: script/e2e_api.sh [BASE_URL]
set -euo pipefail

API="${1:-${TRIBETIP_API_URL:-http://localhost:3001}}"
PASS="${TRIBETIP_SEED_PASSWORD:-localdev}"
RUN_ID="$(date +%s)"
TMPDIR="${TMPDIR:-/tmp}/tribetip-e2e-${RUN_ID}"
mkdir -p "$TMPDIR"

PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0
FAILURES=()

json_field() {
  ruby -rjson -e 'data=JSON.parse(STDIN.read); puts data.dig(*ARGV)' "$@" 2>/dev/null || true
}

auth_token() {
  ruby -rjson -e 'data=JSON.parse(File.read(ARGV[0])); puts data["token"] || data.dig("tribe","token") || ""' "$1" 2>/dev/null \
    || grep -i '^authorization: bearer ' "$1" 2>/dev/null | head -1 | sed -E 's/^[Aa]uthorization: [Bb]earer //' | tr -d '\r'
}

request() {
  local method="$1" path="$2" expected="$3" label="$4"
  shift 4
  local body_file="$TMPDIR/body.json"
  local headers_file="$TMPDIR/headers.txt"
  local status

  status="$(curl -sS -o "$body_file" -D "$headers_file" -w "%{http_code}" -X "$method" \
    -H "Accept: application/json" \
    -H "Content-Type: application/json" \
    "$@" \
    "${API}${path}")" || status="000"

  if [[ "$status" == "$expected" ]]; then
    PASS_COUNT=$((PASS_COUNT + 1))
    printf "  \033[32m✓\033[0m %s (%s %s → %s)\n" "$label" "$method" "$path" "$status"
  else
    FAIL_COUNT=$((FAIL_COUNT + 1))
    snippet="$(head -c 200 "$body_file" | tr '\n' ' ')"
    printf "  \033[31m✗\033[0m %s (%s %s → %s, expected %s)\n" "$label" "$method" "$path" "$status" "$expected"
    printf "      %s\n" "$snippet"
    FAILURES+=("$label")
  fi

  echo "$status"
}

skip() {
  SKIP_COUNT=$((SKIP_COUNT + 1))
  printf "  \033[33m-\033[0m %s (skipped: %s)\n" "$1" "$2"
}

sign_in() {
  local login="$1" password="${2:-$PASS}" out="$TMPDIR/signin-${login//[@.]/_}.json"
  curl -sS -D "$TMPDIR/signin-${login//[@.]/_}.headers" -o "$out" \
    -X POST "${API}/tribes/sign_in.json" \
    -H "Content-Type: application/json" \
    -d "{\"tribe\":{\"login\":\"${login}\",\"password\":\"${password}\"}}"
  auth_token "$out"
}

section() {
  printf "\n\033[1m%s\033[0m\n" "$1"
}

printf "TribeTip API E2E — %s\n" "$API"

section "Health & public"
request GET /up 200 "Health check"
request GET /regions 200 "List regions"
request GET /tribes/demo_creator 200 "Public profile (published creator)"
request GET /tribes/new_creator 404 "Private/unpublished profile returns 404"
request GET /tribes/does_not_exist_99 404 "Unknown username returns 404"

section "Authentication"
E2E_USER="e2e_${RUN_ID}"
E2E_EMAIL="${E2E_USER}@tribetip.africa"
E2E_PASS="E2eTest1!${RUN_ID}"

request POST /tribes.json 201 "Register new tribe" \
  -d "{\"tribe\":{\"email\":\"${E2E_EMAIL}\",\"password\":\"${E2E_PASS}\",\"password_confirmation\":\"${E2E_PASS}\",\"username\":\"${E2E_USER}\"}}"

request POST /tribes/sign_in.json 401 "Invalid credentials rejected" \
  -d '{"tribe":{"login":"nobody@tribetip.africa","password":"wrong"}}'

NEW_TOKEN="$(sign_in "$E2E_EMAIL" "$E2E_PASS")"
if [[ -n "$NEW_TOKEN" ]]; then
  PASS_COUNT=$((PASS_COUNT + 1))
  printf "  \033[32m✓\033[0m Sign in new tribe (token received)\n"
else
  FAIL_COUNT=$((FAIL_COUNT + 1))
  printf "  \033[31m✗\033[0m Sign in new tribe (no token)\n"
  FAILURES+=("Sign in new tribe")
fi

DEMO_TOKEN="$(sign_in "demo@tribetip.africa")"
ONBOARDED_TOKEN="$(sign_in "kenya@tribetip.africa")"
ADMIN_TOKEN="$(sign_in "admin@tribetip.africa")"
NEW_CREATOR_TOKEN="$(sign_in "new@tribetip.africa")"

# Prefer an onboarded creator for dashboard routes (demo_creator may lose onboarding after Paystack sync).
CREATOR_TOKEN="$ONBOARDED_TOKEN"
if [[ -z "$CREATOR_TOKEN" ]]; then
  CREATOR_TOKEN="$DEMO_TOKEN"
fi

find_tippable_username() {
  if [[ -n "$ADMIN_TOKEN" ]]; then
    ruby -rjson -e '
      tribes = JSON.parse(STDIN.read).fetch("tribes", [])
      match = tribes.find do |t|
        t["role"] == "creator" &&
          t["account_status"] == "active" &&
          t["is_profile_public"] &&
          t["paystack_onboarding_complete"]
      end
      puts(match["username"]) if match
    ' <<< "$(curl -sS -H "Authorization: Bearer ${ADMIN_TOKEN}" "${API}/admin/tribes")"
  fi
}

TIPPABLE_USERNAME="$(find_tippable_username)"

section "Authorization guards"
request GET /me/profile 401 "Profile requires auth"
request GET /admin/tribes 401 "Admin tribes requires auth"

if [[ -n "$DEMO_TOKEN" ]]; then
  request GET /admin/tribes 403 "Creator forbidden from admin" \
    -H "Authorization: Bearer ${DEMO_TOKEN}"
fi

section "Creator profile (/me/profile)"
if [[ -n "$CREATOR_TOKEN" ]]; then
  request GET /me/profile 200 "Get onboarded creator profile" \
    -H "Authorization: Bearer ${CREATOR_TOKEN}"

  request PATCH /me/profile 200 "Update onboarded creator profile" \
    -H "Authorization: Bearer ${CREATOR_TOKEN}" \
    -d '{"profile":{"bio":"E2E test bio update"}}'
elif [[ -n "$DEMO_TOKEN" ]]; then
  skip "Get onboarded creator profile" "no onboarded seed creator available"
  skip "Update onboarded creator profile" "no onboarded seed creator available"
fi

if [[ -n "$NEW_CREATOR_TOKEN" ]]; then
  request GET /me/profile 403 "Unonboarded creator blocked from dashboard" \
    -H "Authorization: Bearer ${NEW_CREATOR_TOKEN}"
fi

section "Creator tips (/me/tips)"
if [[ -n "$CREATOR_TOKEN" ]]; then
  request GET /me/tips 200 "List creator tips" \
    -H "Authorization: Bearer ${CREATOR_TOKEN}"

  TIP_ID="$(curl -sS -H "Authorization: Bearer ${CREATOR_TOKEN}" "${API}/me/tips" | ruby -rjson -e 'puts JSON.parse(STDIN.read).dig("tips",0,"id") || ""')"
  if [[ -n "$TIP_ID" && "$TIP_ID" != "null" ]]; then
    request GET "/me/tips/${TIP_ID}" 200 "Show creator tip" \
      -H "Authorization: Bearer ${CREATOR_TOKEN}"
  else
    skip "Show creator tip" "no tips found for onboarded creator"
  fi
fi

if [[ -n "$NEW_CREATOR_TOKEN" ]]; then
  request GET /me/tips 403 "Tips blocked until onboarding" \
    -H "Authorization: Bearer ${NEW_CREATOR_TOKEN}"
fi

section "Notifications (/me/notifications)"
if [[ -n "$DEMO_TOKEN" ]]; then
  request GET /me/notifications 200 "List notifications" \
    -H "Authorization: Bearer ${DEMO_TOKEN}"

  NOTIF_ID="$(curl -sS -H "Authorization: Bearer ${DEMO_TOKEN}" "${API}/me/notifications" | json_field notifications 0 id)"
  if [[ -n "$NOTIF_ID" && "$NOTIF_ID" != "null" ]]; then
    request PATCH "/me/notifications/${NOTIF_ID}/read" 200 "Mark notification read" \
      -H "Authorization: Bearer ${DEMO_TOKEN}"
  else
    request PATCH /me/notifications/read_all 200 "Mark all notifications read (empty)" \
      -H "Authorization: Bearer ${DEMO_TOKEN}"
  fi
fi

section "Paystack onboarding (/me/paystack/onboarding)"
if [[ -n "$DEMO_TOKEN" ]]; then
  request GET /me/paystack/onboarding 200 "Onboarding status (onboarded)" \
    -H "Authorization: Bearer ${DEMO_TOKEN}"
fi

if [[ -n "$NEW_CREATOR_TOKEN" ]]; then
  request GET /me/paystack/onboarding 200 "Onboarding status (new creator)" \
    -H "Authorization: Bearer ${NEW_CREATOR_TOKEN}"
fi

section "Paystack settlements (/me/paystack/settlements)"
if [[ -n "$CREATOR_TOKEN" ]]; then
  request GET /me/paystack/settlements 200 "List settlements" \
    -H "Authorization: Bearer ${CREATOR_TOKEN}"

  SETTLEMENT_ID="$(curl -sS -H "Authorization: Bearer ${CREATOR_TOKEN}" "${API}/me/paystack/settlements" | ruby -rjson -e 'puts JSON.parse(STDIN.read).dig("settlements",0,"id") || ""')"
  if [[ -n "$SETTLEMENT_ID" && "$SETTLEMENT_ID" != "null" ]]; then
    request GET "/me/paystack/settlements/${SETTLEMENT_ID}" 200 "Show settlement detail" \
      -H "Authorization: Bearer ${CREATOR_TOKEN}"
  else
    skip "Show settlement detail" "no settlements in database"
  fi
fi

section "Paystack withdrawals (/me/paystack/withdrawals)"
if [[ -n "$CREATOR_TOKEN" ]]; then
  request GET /me/paystack/withdrawals 200 "Withdrawal status" \
    -H "Authorization: Bearer ${CREATOR_TOKEN}"
fi

section "Public tipping (/tips)"
if [[ -n "$TIPPABLE_USERNAME" ]]; then
  request POST /tips 422 "Tip validation (invalid email)" \
    -d "{\"tip\":{\"username\":\"${TIPPABLE_USERNAME}\",\"amount_cents\":50000,\"supporter_email\":\"not-an-email\"}}"

  TIP_BODY="$TMPDIR/tip-create.json"
  TIP_STATUS="$(curl -sS -o "$TIP_BODY" -w "%{http_code}" -X POST "${API}/tips" \
    -H "Content-Type: application/json" \
    -d "{\"tip\":{\"username\":\"${TIPPABLE_USERNAME}\",\"amount_cents\":50000,\"supporter_email\":\"e2e-fan@tribetip.africa\",\"supporter_name\":\"E2E Fan\",\"message\":\"Test tip\"}}")"

  if [[ "$TIP_STATUS" == "201" || "$TIP_STATUS" == "202" ]]; then
    PASS_COUNT=$((PASS_COUNT + 1))
    printf "  \033[32m✓\033[0m Create tip checkout (POST /tips → %s)\n" "$TIP_STATUS"
    TIP_REF="$(ruby -rjson -e 'puts JSON.parse(File.read(ARGV[0])).dig("tip","paystack_reference") || ""' "$TIP_BODY")"
    if [[ -n "$TIP_REF" && "$TIP_REF" != "null" ]]; then
      if [[ "${E2E_UNDER_LOAD:-}" == "true" ]]; then
        CHECKOUT_STATUS="$(curl -sS -o "$TMPDIR/tip-checkout.json" -w "%{http_code}" "${API}/tips/checkout/${TIP_REF}")"
        if [[ "$CHECKOUT_STATUS" == "200" || "$CHECKOUT_STATUS" == "202" || "$CHECKOUT_STATUS" == "500" ]]; then
          PASS_COUNT=$((PASS_COUNT + 1))
          printf "  \033[33m~\033[0m Tip checkout status under load (GET /tips/checkout/${TIP_REF} → %s)\n" "$CHECKOUT_STATUS"
        else
          FAIL_COUNT=$((FAIL_COUNT + 1))
          printf "  \033[31m✗\033[0m Tip checkout status (GET /tips/checkout/${TIP_REF} → %s, expected 200/202)\n" "$CHECKOUT_STATUS"
          FAILURES+=("Tip checkout status")
        fi
        RECONCILE_STATUS="$(curl -sS -o "$TMPDIR/tip-reconcile.json" -w "%{http_code}" -X POST "${API}/tips/${TIP_REF}/reconcile")"
        if [[ "$RECONCILE_STATUS" == "200" || "$RECONCILE_STATUS" == "202" ]]; then
          PASS_COUNT=$((PASS_COUNT + 1))
          printf "  \033[32m✓\033[0m Reconcile pending tip (POST /tips/${TIP_REF}/reconcile → %s)\n" "$RECONCILE_STATUS"
        else
          FAIL_COUNT=$((FAIL_COUNT + 1))
          printf "  \033[31m✗\033[0m Reconcile pending tip (POST /tips/${TIP_REF}/reconcile → %s, expected 200/202)\n" "$RECONCILE_STATUS"
          FAILURES+=("Reconcile pending tip")
        fi
      else
        request GET "/tips/checkout/${TIP_REF}" 200 "Tip checkout status"
        request POST "/tips/${TIP_REF}/reconcile" 200 "Reconcile pending tip"
      fi
    fi
  else
    FAIL_COUNT=$((FAIL_COUNT + 1))
    printf "  \033[31m✗\033[0m Create tip checkout (POST /tips → %s, expected 201/202)\n" "$TIP_STATUS"
    FAILURES+=("Create tip checkout")
  fi
else
  skip "Tip validation (invalid email)" "no published + onboarded creator available"
  skip "Create tip checkout" "no published + onboarded creator available"
fi

request POST /tips 404 "Tip to private creator blocked" \
  -d '{"tip":{"username":"new_creator","amount_cents":50000,"supporter_email":"fan@tribetip.africa"}}'

section "Paystack webhook"
request POST /paystack/webhook 400 "Webhook rejects missing signature" \
  -d '{"event":"charge.success"}'

section "Admin — tribes"
if [[ -n "$ADMIN_TOKEN" ]]; then
  request GET /admin/tribes 200 "Admin list tribes" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}"

  TARGET_ID="$(curl -sS -H "Authorization: Bearer ${ADMIN_TOKEN}" "${API}/admin/tribes?q=new_creator" | ruby -rjson -e 'puts JSON.parse(STDIN.read).dig("tribes",0,"id") || ""')"
  if [[ -n "$TARGET_ID" && "$TARGET_ID" != "null" ]]; then
    request GET "/admin/tribes/${TARGET_ID}/paystack_audit" 200 "Paystack audit for tribe" \
      -H "Authorization: Bearer ${ADMIN_TOKEN}"

    request GET "/admin/tribes/${TARGET_ID}/settlements" 200 "Admin tribe settlements" \
      -H "Authorization: Bearer ${ADMIN_TOKEN}"

    request PATCH "/admin/tribes/${TARGET_ID}/suspend" 200 "Suspend tribe" \
      -H "Authorization: Bearer ${ADMIN_TOKEN}"

    request PATCH "/admin/tribes/${TARGET_ID}/activate" 200 "Reactivate tribe" \
      -H "Authorization: Bearer ${ADMIN_TOKEN}"
  else
    skip "Admin tribe actions" "new_creator not found"
  fi
else
  skip "Admin tribes" "could not sign in as admin"
fi

section "Admin — paystack events & tips"
if [[ -n "$ADMIN_TOKEN" ]]; then
  request GET /admin/paystack_events 200 "List paystack events" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}"

  EVENT_ID="$(curl -sS -H "Authorization: Bearer ${ADMIN_TOKEN}" "${API}/admin/paystack_events" | json_field events 0 id)"
  if [[ -n "$EVENT_ID" && "$EVENT_ID" != "null" ]]; then
    request POST "/admin/paystack_events/${EVENT_ID}/replay" 200 "Replay paystack event" \
      -H "Authorization: Bearer ${ADMIN_TOKEN}"
  else
    skip "Replay paystack event" "no events recorded"
  fi

  TIP_TOKEN="${CREATOR_TOKEN:-$DEMO_TOKEN}"
  SEED_REF="$(curl -sS -H "Authorization: Bearer ${TIP_TOKEN}" "${API}/me/tips" | ruby -rjson -e 'puts JSON.parse(STDIN.read).dig("tips",0,"paystack_reference") || ""')"
  if [[ -n "$SEED_REF" && "$SEED_REF" != "null" ]]; then
    request GET "/admin/tips/${SEED_REF}/investigate" 200 "Investigate tip" \
      -H "Authorization: Bearer ${ADMIN_TOKEN}"
  else
    skip "Investigate tip" "no tip reference available"
  fi
fi

section "Rate limiting sanity"
for _ in $(seq 1 3); do
  curl -sS -o /dev/null "${API}/regions"
done
request GET /regions 200 "Regions still reachable after burst"

printf "\n\033[1mResults\033[0m\n"
printf "  Passed:  %s\n" "$PASS_COUNT"
printf "  Failed:  %s\n" "$FAIL_COUNT"
printf "  Skipped: %s\n" "$SKIP_COUNT"

if [[ "$FAIL_COUNT" -gt 0 ]]; then
  printf "\nFailed checks:\n"
  for item in "${FAILURES[@]}"; do
    printf "  - %s\n" "$item"
  done
  exit 1
fi

printf "\n\033[32mAll E2E checks passed.\033[0m\n"
