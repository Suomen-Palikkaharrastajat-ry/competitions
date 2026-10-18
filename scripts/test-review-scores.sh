#!/usr/bin/env bash
# Smoke-test the review score validation (pb_hooks/reviews.pb.js).
#
# Given a reviewer and an entry in an open competition
# When a review is created or updated with scores
# Then whole-number scores from 1 to 5, keyed by criterion id, are accepted
#      (whatever the criteria are), and anything else is rejected with
#      validation_failed.
set -euo pipefail

ROOT="${ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
read -r -a PB_BIN <<< "${POCKETBASE:-pocketbase}"
PB_DIR="$(mktemp -d)"
PB_LOG="$(mktemp)"
WORK="$(mktemp -d)"
PB_PORT="${PB_PORT:-18096}"
API="http://127.0.0.1:$PB_PORT/api"

# Stop the server, and whatever else still listens
# on the test port as well.
stop_pb() {
  if [ -n "${PB_PID:-}" ]; then
    kill "$PB_PID" >/dev/null 2>&1 || true
    wait "$PB_PID" >/dev/null 2>&1 || true
  fi
  for pid in $(ss -ltnp 2>/dev/null | grep ":$PB_PORT " | grep -o 'pid=[0-9]*' | cut -d= -f2 | sort -u); do
    kill "$pid" >/dev/null 2>&1 || true
  done
  sleep 1
}

cleanup() {
  stop_pb
  rm -rf "$PB_DIR" "$WORK"
  rm -f "$PB_LOG"
}
trap cleanup EXIT

cd "$ROOT"

"${PB_BIN[@]}" migrate up --dir "$PB_DIR" --migrationsDir ./pb_migrations >/dev/null
"${PB_BIN[@]}" superuser upsert review-scores@example.test review-scores-password-123 --dir "$PB_DIR" >/dev/null

"${PB_BIN[@]}" serve --automigrate=false --migrationsDir ./pb_migrations --hooksDir ./pb_hooks --dir "$PB_DIR" --http "127.0.0.1:$PB_PORT" >"$PB_LOG" 2>&1 &
PB_PID=$!

for _ in $(seq 1 80); do
  if curl -fs "$API/health" >/dev/null 2>&1; then
    break
  fi
  sleep 0.25
done
curl -fsS "$API/health" >/dev/null

json() { python3 -c "import json,sys; print(json.load(sys.stdin)$1)"; }

ADMIN="$(
  curl -fsS -H 'Content-Type: application/json' \
    -d '{"identity":"review-scores@example.test","password":"review-scores-password-123"}' \
    "$API/collections/_superusers/auth-with-password" | json '["token"]'
)"
admin=(-H "Authorization: $ADMIN")

# A reviewer, as impersonated by a superuser, so the collection rules apply.
PASSWORD="review-scores-unused-password-123"
REVIEWER_PROFILE="$(
  curl -fsS "${admin[@]}" -H 'Content-Type: application/json' \
    -d '{"email":"reviewer@example.test","normalized_email":"reviewer@example.test","auth_source":"local","display_name":"Reviewer","is_reviewer":true}' \
    "$API/collections/profiles/records" | json '["id"]'
)"
REVIEWER_USER="$(
  curl -fsS "${admin[@]}" -H 'Content-Type: application/json' \
    -d "{\"email\":\"reviewer@example.test\",\"verified\":true,\"profile_id\":\"$REVIEWER_PROFILE\",\"is_reviewer\":true,\"password\":\"$PASSWORD\",\"passwordConfirm\":\"$PASSWORD\"}" \
    "$API/collections/local_users/records" | json '["id"]'
)"
REVIEWER_TOKEN="$(
  curl -fsS "${admin[@]}" -X POST "$API/collections/local_users/impersonate/$REVIEWER_USER" | json '["token"]'
)"

fail() {
  echo "$1" >&2
  cat "$WORK/body" >&2 || true
  echo >&2
  tail -20 "$PB_LOG" >&2 || true
  exit 1
}

# request TOKEN COLLECTION METHOD PATH JSON -> HTTP status, body in $WORK/body
request() {
  curl -sS -o "$WORK/body" -w "%{http_code}" -H "Authorization: $1" -H 'Content-Type: application/json' \
    -X "$3" -d "$5" "$API/collections/$2/records$4"
}

expect() {
  # expect LABEL WANT_CODE_REGEX GOT
  case "$3" in
    $2) ;;
    *) fail "$1: expected $2, got $3" ;;
  esac
}

COMPETITION="$(
  curl -fsS "${admin[@]}" -H 'Content-Type: application/json' \
    -d '{"title":"Review scores","slug":"review-scores","start_date":"2026-01-01 00:00:00.000Z","end_date":"2099-01-01 00:00:00.000Z","status":"open"}' \
    "$API/collections/competitions/records" | json '["id"]'
)"
ENTRY="$(
  curl -fsS "${admin[@]}" -H 'Content-Type: application/json' \
    -d "{\"competition\":\"$COMPETITION\",\"submitter\":\"$REVIEWER_PROFILE\",\"title\":\"Entry\",\"status\":\"draft\"}" \
    "$API/collections/entries/records" | json '["id"]'
)"

# A review is created once; every later case changes it, so a rejected
# change is a validation failure and not a duplicate review.
revise() {
  # revise SCORES_JSON -> PATCH the review with these scores as the reviewer
  request "$REVIEWER_TOKEN" reviews PATCH "/$REVIEW" "{\"scores\":$1}"
}

# Given the current criteria (config.toml), created as a review
status="$(request "$REVIEWER_TOKEN" reviews POST "" "{\"entry\":\"$ENTRY\",\"reviewer\":\"$REVIEWER_PROFILE\",\"scores\":{\"theme\":4,\"originality\":3,\"technique\":5,\"presentation\":4},\"comment\":\"\",\"is_published\":false}")"
expect "four current criteria, whole numbers 1-5" 200 "$status"
REVIEW="$(json '["id"]' <"$WORK/body")"

# Given other criterion ids, since criteria are configured, not fixed
status="$(revise '{"clarity":1,"humour":5}')"
expect "other criterion ids" 200 "$status"

# When a score is out of range, fractional, or not a number
status="$(revise '{"theme":6}')"
expect "score above 5" 400 "$status"
status="$(revise '{"theme":0}')"
expect "score below 1" 400 "$status"
status="$(revise '{"theme":3.5}')"
expect "fractional score" 400 "$status"
status="$(revise '{"theme":"4"}')"
expect "score as text" 400 "$status"

# When there are no scores at all, or the scores are not an object
status="$(revise '{}')"
expect "no scores" 400 "$status"
status="$(revise '[4,4,4,4]')"
expect "scores as a list" 400 "$status"
status="$(revise '4')"
expect "scores as a number" 400 "$status"

# When a criterion id is not a plain identifier
status="$(revise '{"Theme fit":4}')"
expect "criterion id with a space" 400 "$status"

# Then a valid change is accepted again, and a fresh review is still validated
status="$(revise '{"theme":2,"originality":2,"technique":2,"presentation":2}')"
expect "valid scores after rejected ones" 200 "$status"
status="$(request "$REVIEWER_TOKEN" reviews POST "" "{\"entry\":\"$ENTRY\",\"reviewer\":\"$REVIEWER_PROFILE\",\"scores\":{\"theme\":9},\"comment\":\"\",\"is_published\":false}")"
expect "invalid score on a new review" 400 "$status"

echo "pb-test-review-scores: PASS"
