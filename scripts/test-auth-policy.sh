#!/usr/bin/env bash
# Smoke-test the Keycloak-first auth policy on the shared PocketBase (ADR-0006).
#
# Given Keycloak members in the shared `users` collection and email-only
#       participants in `local_users`
# When either signs in, reads or writes the shared events and locations
# Then a member's email cannot get an OTP, an email participant can, and only
#      members see unpublished events or write events, and nobody gives
#      themselves the reviewer flag.
set -euo pipefail

ROOT="${ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
read -r -a PB_BIN <<< "${POCKETBASE:-pocketbase}"
PB_DIR="$(mktemp -d)"
PB_LOG="$(mktemp)"
MAILPIT_LOG="$(mktemp)"
PB_PORT="${PB_PORT:-18090}"
MAILPIT_PORT="${MAILPIT_PORT:-18025}"
SMTP_PORT="${SMTP_PORT:-11025}"

cleanup() {
  rm -f "/tmp/keycloak-required-body.$$" "/tmp/local-otp-body.$$"
  if [ -n "${PB_PID:-}" ]; then
    # Stop any child process of the server too.
    pkill -P "$PB_PID" >/dev/null 2>&1 || true
    kill "$PB_PID" >/dev/null 2>&1 || true
    wait "$PB_PID" >/dev/null 2>&1 || true
  fi
  if [ -n "${MAILPIT_PID:-}" ]; then
    kill "$MAILPIT_PID" >/dev/null 2>&1 || true
    wait "$MAILPIT_PID" >/dev/null 2>&1 || true
  fi
  rm -rf "$PB_DIR"
  rm -f "$PB_LOG" "$MAILPIT_LOG"
}
trap cleanup EXIT

cd "$ROOT"

"${PB_BIN[@]}" migrate up --dir "$PB_DIR" --migrationsDir ./pb_migrations >/dev/null
"${PB_BIN[@]}" migrate up --dir "$PB_DIR" --migrationsDir ./pb_migrations_dev >/dev/null
"${PB_BIN[@]}" superuser upsert auth-policy@example.test auth-policy-password-123 --dir "$PB_DIR" >/dev/null

mailpit --smtp "127.0.0.1:$SMTP_PORT" --listen "127.0.0.1:$MAILPIT_PORT" >"$MAILPIT_LOG" 2>&1 &
MAILPIT_PID=$!

KEYCLOAK_ISSUER_URL=http://127.0.0.1:8080/auth/realms/competitions \
"${PB_BIN[@]}" serve --automigrate=false --migrationsDir ./pb_migrations --hooksDir ./pb_hooks --dir "$PB_DIR" --http "127.0.0.1:$PB_PORT" >"$PB_LOG" 2>&1 &
PB_PID=$!

for _ in $(seq 1 80); do
  if curl -fs "http://127.0.0.1:$PB_PORT/api/health" >/dev/null 2>&1; then
    break
  fi
  sleep 0.25
done

curl -fsS "http://127.0.0.1:$PB_PORT/api/health" >/dev/null

status="$(
  curl -sS -o "/tmp/keycloak-required-body.$$" -w "%{http_code}" \
    -H 'Content-Type: application/json' \
    -d '{"email":"keycloak-participant@example.test"}' \
    "http://127.0.0.1:$PB_PORT/api/collections/local_users/request-otp"
)"
if [ "$status" != "409" ] || ! grep -q "keycloak_required" "/tmp/keycloak-required-body.$$"; then
  echo "Expected Keycloak shadow user OTP request to return 409 keycloak_required, got $status" >&2
  cat "/tmp/keycloak-required-body.$$" >&2
  exit 1
fi

status="$(
  curl -sS -o "/tmp/local-otp-body.$$" -w "%{http_code}" \
    -H 'Content-Type: application/json' \
    -d '{"email":"auth-policy-local@example.test"}' \
    "http://127.0.0.1:$PB_PORT/api/collections/local_users/request-otp"
)"
if [ "$status" != "200" ] || ! grep -q "otpId" "/tmp/local-otp-body.$$"; then
  echo "Expected local-only OTP request to return 200 with otpId, got $status" >&2
  cat "/tmp/local-otp-body.$$" >&2
  exit 1
fi

API="http://127.0.0.1:$PB_PORT/api"
BODY="/tmp/auth-policy-body.$$"
json() { python3 -c "import json,sys; print(json.load(sys.stdin)$1)"; }
fail() {
  echo "$1" >&2
  cat "$BODY" >&2 || true
  echo >&2
  exit 1
}
expect() {
  # expect LABEL WANT_CODE_REGEX GOT
  case "$3" in
    $2) ;;
    *) fail "$1: expected $2, got $3" ;;
  esac
}
# request TOKEN METHOD PATH [JSON] -> HTTP status, body in $BODY
request() {
  local auth=()
  [ -z "$1" ] || auth=(-H "Authorization: $1")
  curl -sS -o "$BODY" -w "%{http_code}" "${auth[@]}" -H 'Content-Type: application/json' \
    -X "$2" ${4:+-d "$4"} "$API$3"
}

ADMIN="$(
  curl -fsS -H 'Content-Type: application/json' \
    -d '{"identity":"auth-policy@example.test","password":"auth-policy-password-123"}' \
    "$API/collections/_superusers/auth-with-password" | json '["token"]'
)"
impersonate() {
  curl -fsS -H "Authorization: $ADMIN" -X POST "$API/collections/$1/impersonate/$2" | json '["token"]'
}
MEMBER_ID="$(curl -fsS -H "Authorization: $ADMIN" "$API/collections/users/records?filter=(email='keycloak-participant@example.test')" | json '["items"][0]["id"]')"
LOCAL_ID="$(curl -fsS -H "Authorization: $ADMIN" "$API/collections/local_users/records?filter=(email='auth-policy-local@example.test')" | json '["items"][0]["id"]')"
MEMBER="$(impersonate users "$MEMBER_ID")"
LOCAL="$(impersonate local_users "$LOCAL_ID")"

EVENT_JSON="{\"title\":\"%s\",\"start_date\":\"2026-11-01 10:00:00.000Z\",\"end_date\":\"2026-11-01 16:00:00.000Z\",\"state\":\"%s\",\"created_by\":\"$MEMBER_ID\",\"updated_by\":\"$MEMBER_ID\"}"
# The events hook stamps created_by with the caller, so a member creates it.
status="$(request "$MEMBER" POST /collections/events/records "$(printf "$EVENT_JSON" Draft draft)")"
expect "member creates a draft event" 200 "$status"
DRAFT="$(json '["id"]' <"$BODY")"

# Unpublished events are for members only.
status="$(request "$MEMBER" GET "/collections/events/records/$DRAFT")"
expect "member reads a draft event" 200 "$status"
status="$(request "$LOCAL" GET "/collections/events/records/$DRAFT")"
expect "email participant reads a draft event" 404 "$status"
status="$(request "" GET "/collections/events/records/$DRAFT")"
expect "guest reads a draft event" 404 "$status"

# Only members write events and locations.
status="$(request "$LOCAL" POST /collections/events/records "$(printf "$EVENT_JSON" "By email participant" pending)")"
expect "email participant creates an event" 400 "$status"
status="$(request "$LOCAL" PATCH "/collections/events/records/$DRAFT" '{"state":"published"}')"
expect "email participant publishes an event" 404 "$status"
status="$(request "$LOCAL" POST /collections/locations/records "{\"title\":\"Shop\",\"state\":\"pending\",\"point\":{\"lon\":24.9,\"lat\":60.2},\"created_by\":\"$MEMBER_ID\",\"updated_by\":\"$MEMBER_ID\"}")"
expect "email participant creates a location" 400 "$status"

# Nobody gives themselves the reviewer flag or another profile.
# Control: the member may change an ordinary field of the same record, so the
# 404s below come from the rule, not from a wrong id.
status="$(request "$MEMBER" PATCH "/collections/users/records/$MEMBER_ID" '{"name":"Member"}')"
expect "member changes own name" 200 "$status"
status="$(request "$MEMBER" PATCH "/collections/users/records/$MEMBER_ID" '{"is_reviewer":true}')"
expect "member sets own reviewer flag" 404 "$status"
status="$(request "$MEMBER" PATCH "/collections/users/records/$MEMBER_ID" '{"profile_id":"someoneelse1234"}')"
expect "member sets own profile id" 404 "$status"
status="$(request "" POST /collections/users/records '{"email":"sneaky@example.test","password":"sneaky-password-123","passwordConfirm":"sneaky-password-123","is_reviewer":true}')"
expect "guest signs up as a reviewer" 400 "$status"
status="$(request "$LOCAL" PATCH "/collections/local_users/records/$LOCAL_ID" '{"display_name":"Local"}')"
expect "email participant changes own display name" 200 "$status"
status="$(request "$LOCAL" PATCH "/collections/local_users/records/$LOCAL_ID" '{"is_reviewer":true}')"
expect "email participant sets own reviewer flag" 404 "$status"
# A member's first login already answers with the linked profile.
# Given a member of the shared users without a competitions profile (e.g. one
#       who has only used the events app)
# When they sign in (impersonation runs the same auth hooks as OAuth2)
# Then the auth response carries the profile and a display name.
status="$(request "$ADMIN" POST /collections/users/records '{"email":"events-member@example.test","username":"eventsmember","password":"unused-password-123","passwordConfirm":"unused-password-123","verified":true}')"
expect "superuser creates an events-only member" 200 "$status"
EVENTS_MEMBER_ID="$(json '["id"]' <"$BODY")"
status="$(request "$ADMIN" POST "/collections/users/impersonate/$EVENTS_MEMBER_ID")"
expect "events-only member signs in" 200 "$status"
profile_id="$(json '["record"]["profile_id"]' <"$BODY")"
display_name="$(json '["record"]["display_name"]' <"$BODY")"
[ -n "$profile_id" ] || fail "Expected the first login response to carry the member's profile_id"
[ -n "$display_name" ] || fail "Expected the first login response to carry a display name"
status="$(request "$ADMIN" GET "/collections/profiles/records/$profile_id")"
expect "the member's profile exists" 200 "$status"
[ "$(json '["keycloak_user"]' <"$BODY")" = "$EVENTS_MEMBER_ID" ] || fail "Expected the profile to link the member"
[ "$(json '["auth_source"]' <"$BODY")" = "keycloak" ] || fail "Expected a keycloak profile"

# Signing in again writes nothing: the member's record is already linked.
before="$(curl -fsS -H "Authorization: $ADMIN" "$API/collections/users/records/$EVENTS_MEMBER_ID" | json '["updated"]')"
status="$(request "$ADMIN" POST "/collections/users/impersonate/$EVENTS_MEMBER_ID")"
expect "events-only member signs in again" 200 "$status"
after="$(curl -fsS -H "Authorization: $ADMIN" "$API/collections/users/records/$EVENTS_MEMBER_ID" | json '["updated"]')"
[ "$before" = "$after" ] || fail "Expected a repeated sign-in not to rewrite the member ($before -> $after)"

# Only a Keycloak sign-in creates a member: no sign-up through the REST API.
# Given anyone may POST to users with any email
# When the email belongs to an email participant
# Then the participant would be locked out of OTP (keycloak_required), so the
#      create must fail.
status="$(request "" POST /collections/users/records '{"email":"auth-policy-local@example.test","password":"squatter-password-123","passwordConfirm":"squatter-password-123"}')"
expect "guest signs up a member through the API" 400 "$status"

# An unverified member (OAuth2 createData with someone else's email) is not
# linked to that email's profile, not verified by us, and does not block the
# email participant.
LOCAL_PROFILE="$(curl -fsS -H "Authorization: $ADMIN" "$API/collections/local_users/records/$LOCAL_ID" | json '["profile_id"]')"
[ -n "$LOCAL_PROFILE" ] || fail "Expected the email participant to have a profile"
status="$(request "$ADMIN" POST /collections/users/records '{"email":"auth-policy-local@example.test","password":"unused-password-123","passwordConfirm":"unused-password-123","verified":false}')"
expect "superuser creates an unverified member with a participant's email" 200 "$status"
SQUATTER_ID="$(json '["id"]' <"$BODY")"
status="$(request "$ADMIN" POST "/collections/users/impersonate/$SQUATTER_ID")"
expect "unverified member signs in" 200 "$status"
[ -z "$(json '["record"]["profile_id"]' <"$BODY")" ] || fail "Expected an unverified member not to get the participant's profile"
[ "$(json '["record"]["is_reviewer"]' <"$BODY")" = "False" ] || fail "Expected an unverified member not to become a reviewer"
[ "$(curl -fsS -H "Authorization: $ADMIN" "$API/collections/users/records/$SQUATTER_ID" | json '["verified"]')" = "False" ] ||
  fail "Expected the hook not to verify a member"
[ "$(curl -fsS -H "Authorization: $ADMIN" "$API/collections/local_users/records/$LOCAL_ID" | json '["keycloak_blocked"]')" = "False" ] ||
  fail "Expected an unverified member not to block the email participant"
[ -z "$(curl -fsS -H "Authorization: $ADMIN" "$API/collections/profiles/records/$LOCAL_PROFILE" | json '["keycloak_user"]')" ] ||
  fail "Expected the participant's profile not to link the unverified member"
request "$ADMIN" DELETE "/collections/users/records/$SQUATTER_ID" >/dev/null

# A profile's email is fixed: a participant cannot take over a future
# member's email.
status="$(request "$LOCAL" PATCH "/collections/profiles/records/$LOCAL_PROFILE" '{"email":"future-member@example.test","normalized_email":"future-member@example.test"}')"
expect "participant changes own profile email" 404 "$status"
status="$(request "$LOCAL" PATCH "/collections/profiles/records/$LOCAL_PROFILE" '{"display_name":"Renamed"}')"
expect "participant renames own profile" 200 "$status"

# A member's profile already linked to another member is not taken over.
OTHER_MEMBER_PROFILE="$(curl -fsS -H "Authorization: $ADMIN" "$API/collections/users/records/$MEMBER_ID" | json '["profile_id"]')"
[ -n "$OTHER_MEMBER_PROFILE" ] || fail "Expected the seeded member to have a profile"
MEMBER_EMAIL="keycloak-participant@example.test"
status="$(request "$ADMIN" POST /collections/users/records '{"email":"second-account@example.test","password":"unused-password-123","passwordConfirm":"unused-password-123","verified":true}')"
expect "superuser creates a second member" 200 "$status"
SECOND_ID="$(json '["id"]' <"$BODY")"
status="$(request "$ADMIN" PATCH "/collections/profiles/records/$OTHER_MEMBER_PROFILE" '{"normalized_email":"second-account@example.test"}')"
expect "superuser points a linked profile at another email" 200 "$status"
status="$(request "$ADMIN" POST "/collections/users/impersonate/$SECOND_ID")"
expect "second member signs in" 200 "$status"
[ "$(json '["record"]["profile_id"]' <"$BODY")" != "$OTHER_MEMBER_PROFILE" ] ||
  fail "Expected a profile linked to another member not to be taken over"
[ "$(curl -fsS -H "Authorization: $ADMIN" "$API/collections/profiles/records/$OTHER_MEMBER_PROFILE" | json '["keycloak_user"]')" = "$MEMBER_ID" ] ||
  fail "Expected the profile to stay linked to its member"
status="$(request "$ADMIN" PATCH "/collections/profiles/records/$OTHER_MEMBER_PROFILE" "{\"normalized_email\":\"$MEMBER_EMAIL\"}")"
expect "superuser restores the profile email" 200 "$status"

rm -f "$BODY"

echo "pb-test-auth-policy: PASS"
