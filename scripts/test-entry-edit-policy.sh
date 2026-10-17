#!/usr/bin/env bash
# Smoke-test who may change an entry, and when (pb_migrations/013, pb_hooks/lib/entry_status.js).
#
# Given a participant who owns entries in a competition
# When they edit a draft, a submitted entry, or change its status, before and after the deadline
# Then drafts stay editable, a submitted entry is editable only before the
#      competition's end_date, status may only go draft -> submitted, and
#      reviewers may still change status.
set -euo pipefail

ROOT="${ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
read -r -a PB_BIN <<< "${POCKETBASE:-env GOFLAGS=-mod=mod go run ./cmd/competition-pocketbase}"
PB_DIR="$(mktemp -d)"
PB_LOG="$(mktemp)"
WORK="$(mktemp -d)"
PB_PORT="${PB_PORT:-18092}"
API="http://127.0.0.1:$PB_PORT/api"

cleanup() {
  if [ -n "${PB_PID:-}" ]; then
    # `go run` starts the server as a child process; stop it too.
    pkill -P "$PB_PID" >/dev/null 2>&1 || true
    kill "$PB_PID" >/dev/null 2>&1 || true
    wait "$PB_PID" >/dev/null 2>&1 || true
  fi
  rm -rf "$PB_DIR" "$WORK"
  rm -f "$PB_LOG"
}
trap cleanup EXIT

cd "$ROOT"

PB_MIGRATIONS_DIR=./pb_migrations "${PB_BIN[@]}" migrate up --dir "$PB_DIR" >/dev/null
"${PB_BIN[@]}" superuser upsert edit-policy@example.test edit-policy-password-123 --dir "$PB_DIR" >/dev/null

PB_MIGRATIONS_DIR=./pb_migrations \
PB_HOOKS_DIR=./pb_hooks \
"${PB_BIN[@]}" serve --dir "$PB_DIR" --http "127.0.0.1:$PB_PORT" >"$PB_LOG" 2>&1 &
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
    -d '{"identity":"edit-policy@example.test","password":"edit-policy-password-123"}' \
    "$API/collections/_superusers/auth-with-password" | json '["token"]'
)"
admin=(-H "Authorization: $ADMIN")

# A participant is a local user linked to a profile. Entries are submitted by
# the profile; the token comes from superuser impersonation, so the rules apply
# to the participant as they would in use.
# The local user record needs a password to be created; participants sign in
# with OTP, so it is never used to log in.
PASSWORD="edit-policy-unused-password-123"

# new_user EMAIL IS_REVIEWER -> sets USER_TOKEN and PROFILE_ID
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

new_user owner@example.test false
OWNER_TOKEN="$USER_TOKEN"
OWNER_PROFILE="$PROFILE_ID"
new_user other@example.test false
OTHER_TOKEN="$USER_TOKEN"
OTHER_PROFILE="$PROFILE_ID"
new_user reviewer@example.test true
REVIEWER_TOKEN="$USER_TOKEN"

COMPETITION="$(
  curl -fsS "${admin[@]}" -H 'Content-Type: application/json' \
    -d '{"title":"Edit policy","slug":"edit-policy","start_date":"2026-01-01 00:00:00.000Z","end_date":"2099-01-01 00:00:00.000Z","status":"open","min_images_per_entry":0,"max_images_per_entry":2}' \
    "$API/collections/competitions/records" | json '["id"]'
)"

fail() {
  echo "$1" >&2
  cat "$WORK/body" >&2
  echo >&2
  tail -20 "$PB_LOG" >&2 || true
  exit 1
}

# request TOKEN METHOD PATH JSON -> HTTP status, body in $WORK/body
request() {
  curl -sS -o "$WORK/body" -w "%{http_code}" -H "Authorization: $1" -H 'Content-Type: application/json' \
    -X "$2" -d "$4" "$API/collections/entries/records$3"
}

# create STATUS -> new entry id in $ENTRY_ID
create() {
  local status
  status="$(request "$OWNER_TOKEN" POST "" "{\"competition\":\"$COMPETITION\",\"submitter\":\"$OWNER_PROFILE\",\"title\":\"Entry\",\"status\":\"$1\"}")"
  [ "$status" = "200" ] || fail "Expected creating a $1 entry to be accepted, got $status"
  ENTRY_ID="$(json '["id"]' <"$WORK/body")"
}

# A draft stays editable and can be submitted while the competition is open.
create draft
DRAFT="$ENTRY_ID"
status="$(request "$OWNER_TOKEN" PATCH "/$DRAFT" '{"title":"Renamed draft"}')"
[ "$status" = "200" ] || fail "Expected a draft to be editable, got $status"
status="$(request "$OWNER_TOKEN" PATCH "/$DRAFT" '{"status":"submitted"}')"
[ "$status" = "200" ] || fail "Expected a draft to be submitted before the deadline, got $status"

# A submitted entry stays editable and keeps its status; the participant
# cannot approve it or return it to draft.
status="$(request "$OWNER_TOKEN" PATCH "/$DRAFT" '{"title":"Edited after submitting"}')"
[ "$status" = "200" ] || fail "Expected a submitted entry to be editable before the deadline, got $status"
status="$(request "$OWNER_TOKEN" PATCH "/$DRAFT" '{"status":"approved"}')"
[ "$status" = "400" ] ||
  fail "Expected a participant setting status to approved to be rejected, got $status"
status="$(request "$OWNER_TOKEN" PATCH "/$DRAFT" '{"status":"draft"}')"
[ "$status" = "400" ] ||
  fail "Expected a participant returning a submitted entry to draft to be rejected, got $status"

# A reviewer may still change the status.
status="$(request "$REVIEWER_TOKEN" PATCH "/$DRAFT" '{"status":"approved"}')"
[ "$status" = "200" ] || fail "Expected a reviewer to approve a submitted entry, got $status"
status="$(request "$REVIEWER_TOKEN" PATCH "/$DRAFT" '{"status":"submitted"}')"
[ "$status" = "200" ] || fail "Expected a reviewer to set the entry back to submitted, got $status"

# Once the deadline has passed, a submitted entry is locked, a draft stays
# editable, and a draft cannot be submitted any more.
create submitted
SUBMITTED="$ENTRY_ID"
create draft
LATE_DRAFT="$ENTRY_ID"
status="$(
  curl -sS -o "$WORK/body" -w "%{http_code}" "${admin[@]}" -H 'Content-Type: application/json' \
    -X PATCH -d '{"end_date":"2020-06-01 00:00:00.000Z"}' "$API/collections/competitions/records/$COMPETITION"
)"
[ "$status" = "200" ] || fail "Expected closing the competition to be accepted, got $status"

status="$(request "$OWNER_TOKEN" PATCH "/$SUBMITTED" '{"title":"Too late"}')"
[ "$status" = "404" ] || [ "$status" = "403" ] || fail "Expected a submitted entry to be locked after the deadline, got $status"

status="$(request "$OWNER_TOKEN" PATCH "/$LATE_DRAFT" '{"title":"Draft after deadline"}')"
[ "$status" = "200" ] || fail "Expected a draft to stay editable after the deadline, got $status"
status="$(request "$OWNER_TOKEN" PATCH "/$LATE_DRAFT" '{"status":"submitted"}')"
[ "$status" = "400" ] ||
  fail "Expected submitting a draft after the deadline to be rejected, got $status"

# Another participant's entry is never editable.
status="$(request "$OTHER_TOKEN" PATCH "/$DRAFT" '{"title":"Not mine"}')"
[ "$status" = "403" ] || [ "$status" = "404" ] || fail "Expected another participant's entry to be locked, got $status"

# A participant cannot move an entry to another competition or profile, and
# cannot create one for someone else or with a status they may not set.
OTHER_COMPETITION="$(
  curl -fsS "${admin[@]}" -H 'Content-Type: application/json' \
    -d '{"title":"Other","slug":"edit-policy-other","start_date":"2026-01-01 00:00:00.000Z","end_date":"2099-01-01 00:00:00.000Z","status":"open","min_images_per_entry":0,"max_images_per_entry":2}' \
    "$API/collections/competitions/records" | json '["id"]'
)"
create draft
MOVABLE="$ENTRY_ID"
status="$(request "$OWNER_TOKEN" PATCH "/$MOVABLE" "{\"competition\":\"$OTHER_COMPETITION\"}")"
[ "$status" = "400" ] || fail "Expected moving an entry to another competition to be refused, got $status"
status="$(request "$OWNER_TOKEN" PATCH "/$MOVABLE" "{\"submitter\":\"$OTHER_PROFILE\"}")"
[ "$status" = "400" ] || fail "Expected handing an entry to another profile to be refused, got $status"
status="$(request "$OWNER_TOKEN" POST "" "{\"competition\":\"$COMPETITION\",\"submitter\":\"$OTHER_PROFILE\",\"title\":\"Entry\",\"status\":\"draft\"}")"
[ "$status" = "400" ] || fail "Expected creating an entry for another profile to be refused, got $status"
status="$(request "$OWNER_TOKEN" POST "" "{\"competition\":\"$COMPETITION\",\"submitter\":\"$OWNER_PROFILE\",\"title\":\"Entry\",\"status\":\"approved\"}")"
[ "$status" = "400" ] || fail "Expected creating an approved entry to be refused, got $status"

# A competition that is not open takes no submissions, even before its end_date.
PAUSED="$(
  curl -fsS "${admin[@]}" -H 'Content-Type: application/json' \
    -d '{"title":"Paused","slug":"edit-policy-paused","start_date":"2026-01-01 00:00:00.000Z","end_date":"2099-01-01 00:00:00.000Z","status":"closed","min_images_per_entry":0,"max_images_per_entry":2}' \
    "$API/collections/competitions/records" | json '["id"]'
)"
status="$(request "$OWNER_TOKEN" POST "" "{\"competition\":\"$PAUSED\",\"submitter\":\"$OWNER_PROFILE\",\"title\":\"Entry\",\"status\":\"submitted\"}")"
[ "$status" = "400" ] || fail "Expected submitting to a closed competition to be refused, got $status"
create draft
status="$(request "$OWNER_TOKEN" PATCH "/$ENTRY_ID" "{\"competition\":\"$PAUSED\"}")"
[ "$status" = "400" ] || fail "Expected moving a draft into a closed competition to be refused, got $status"

# A superuser is not held to these rules.
status="$(
  curl -sS -o "$WORK/body" -w "%{http_code}" "${admin[@]}" -H 'Content-Type: application/json' \
    -X PATCH -d '{"status":"approved"}' "$API/collections/entries/records/$MOVABLE"
)"
[ "$status" = "200" ] || fail "Expected a superuser to change any entry, got $status"

echo "pb-test-entry-edit-policy: PASS"
