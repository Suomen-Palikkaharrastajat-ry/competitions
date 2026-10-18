#!/usr/bin/env bash
# Smoke-test who may use the in-app admin (pb_migrations/1792266036_competitions_schema.js): reviewers manage
# competitions and entries; nobody but a superuser deletes a competition.
#
# Given a participant, two reviewers and a superuser
# When each writes competitions, entries and reviews
# Then reviewers may create and change competitions and set entry status,
#      participants may not, nobody but a superuser may delete a competition,
#      and a reviewer may not change another reviewer's review.
set -euo pipefail

ROOT="${ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
read -r -a PB_BIN <<< "${POCKETBASE:-pocketbase}"
PB_DIR="$(mktemp -d)"
PB_LOG="$(mktemp)"
WORK="$(mktemp -d)"
PB_PORT="${PB_PORT:-18093}"
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
"${PB_BIN[@]}" superuser upsert admin-policy@example.test admin-policy-password-123 --dir "$PB_DIR" >/dev/null

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
    -d '{"identity":"admin-policy@example.test","password":"admin-policy-password-123"}' \
    "$API/collections/_superusers/auth-with-password" | json '["token"]'
)"
admin=(-H "Authorization: $ADMIN")

# A participant, two reviewers. Tokens come from superuser impersonation, so
# the rules apply to them as they would in use.
# new_user EMAIL IS_REVIEWER -> sets USER_TOKEN and PROFILE_ID
PASSWORD="admin-policy-unused-password-123"
new_user() {
  PROFILE_ID="$(
    curl -fsS "${admin[@]}" -H 'Content-Type: application/json' \
      -d "{\"email\":\"$1\",\"normalized_email\":\"$1\",\"auth_source\":\"local\",\"display_name\":\"$1\",\"is_reviewer\":$2}" \
      "$API/collections/profiles/records" | json '["id"]'
  )"
  local user_id
  user_id="$(
    curl -fsS "${admin[@]}" -H 'Content-Type: application/json' \
      -d "{\"email\":\"$1\",\"verified\":true,\"profile_id\":\"$PROFILE_ID\",\"is_reviewer\":$2,\"password\":\"$PASSWORD\",\"passwordConfirm\":\"$PASSWORD\"}" \
      "$API/collections/local_users/records" | json '["id"]'
  )"
  USER_TOKEN="$(
    curl -fsS "${admin[@]}" -X POST "$API/collections/local_users/impersonate/$user_id" | json '["token"]'
  )"
}

new_user participant@example.test false
PARTICIPANT_TOKEN="$USER_TOKEN"
PARTICIPANT_PROFILE="$PROFILE_ID"
new_user reviewer@example.test true
REVIEWER_TOKEN="$USER_TOKEN"
REVIEWER_PROFILE="$PROFILE_ID"
new_user second-reviewer@example.test true
SECOND_REVIEWER_TOKEN="$USER_TOKEN"

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

# Competitions: reviewers write, participants do not.
COMP_JSON='{"title":"Admin policy","slug":"admin-policy-%s","start_date":"2026-01-01 00:00:00.000Z","end_date":"2099-01-01 00:00:00.000Z","status":"open","min_images_per_entry":0,"max_images_per_entry":2}'
status="$(request "$REVIEWER_TOKEN" competitions POST "" "$(printf "$COMP_JSON" one)")"
expect "reviewer creates competition" 200 "$status"
COMPETITION="$(json '["id"]' <"$WORK/body")"

status="$(request "$REVIEWER_TOKEN" competitions PATCH "/$COMPETITION" '{"title":"Renamed by reviewer"}')"
expect "reviewer updates competition" 200 "$status"

status="$(request "$PARTICIPANT_TOKEN" competitions POST "" "$(printf "$COMP_JSON" two)")"
expect "participant creates competition" "40[03]" "$status"

status="$(request "$PARTICIPANT_TOKEN" competitions PATCH "/$COMPETITION" '{"title":"Hacked"}')"
expect "participant updates competition" "40[034]" "$status"

# Deleting a competition takes its entries and reviews with it: superusers only.
status="$(request "$REVIEWER_TOKEN" competitions DELETE "/$COMPETITION" '')"
expect "reviewer deletes competition" "40[34]" "$status"

# Entries: reviewers set any status; participants may not approve.
status="$(request "$PARTICIPANT_TOKEN" entries POST "" "{\"competition\":\"$COMPETITION\",\"submitter\":\"$PARTICIPANT_PROFILE\",\"title\":\"Entry\",\"status\":\"submitted\"}")"
expect "participant submits entry" 200 "$status"
ENTRY="$(json '["id"]' <"$WORK/body")"

for target in approved rejected draft submitted; do
  status="$(request "$REVIEWER_TOKEN" entries PATCH "/$ENTRY" "{\"status\":\"$target\"}")"
  expect "reviewer sets entry to $target" 200 "$status"
done

status="$(request "$PARTICIPANT_TOKEN" entries PATCH "/$ENTRY" '{"status":"approved"}')"
expect "participant approves own entry" "400" "$status"

# Reviews: a reviewer writes their own review and cannot change another's.
status="$(request "$REVIEWER_TOKEN" reviews POST "" "{\"entry\":\"$ENTRY\",\"reviewer\":\"$REVIEWER_PROFILE\",\"scores\":{\"theme\":3,\"originality\":3,\"technique\":3,\"presentation\":3},\"comment\":\"ok\",\"is_published\":false}")"
expect "reviewer writes own review" 200 "$status"
REVIEW="$(json '["id"]' <"$WORK/body")"

status="$(request "$SECOND_REVIEWER_TOKEN" reviews PATCH "/$REVIEW" '{"is_published":true}')"
expect "second reviewer changes another review" "40[34]" "$status"

# A participant cannot change another participant's entry (US-011).
new_user other-participant@example.test false
OTHER_PARTICIPANT_TOKEN="$USER_TOKEN"
status="$(request "$OTHER_PARTICIPANT_TOKEN" entries PATCH "/$ENTRY" '{"title":"Stolen"}')"
expect "other participant changes an entry" "40[34]" "$status"

# A superuser deletes a competition (and so its entries and reviews).
status="$(
  curl -sS -o "$WORK/body" -w "%{http_code}" "${admin[@]}" -X DELETE "$API/collections/competitions/records/$COMPETITION"
)"
expect "superuser deletes competition" 204 "$status"

echo "pb-test-admin-policy: PASS"
