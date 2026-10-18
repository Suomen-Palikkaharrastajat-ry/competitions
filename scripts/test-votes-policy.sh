#!/usr/bin/env bash
# Smoke-test the ranked voting rules (votes collection + pb_hooks/votes.pb.js).
#
# Given a competition whose voting period is running, with approved entries
# When signed-in users cast, change, read and withdraw ballots
# Then a ballot ranks 1 to 5 distinct approved entries of that competition,
#      once per voter, only during the voting period, and only the voter and
#      reviewers can read it.
set -euo pipefail

ROOT="${ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
read -r -a PB_BIN <<< "${POCKETBASE:-pocketbase}"
PB_DIR="$(mktemp -d)"
PB_LOG="$(mktemp)"
WORK="$(mktemp -d)"
PB_PORT="${PB_PORT:-18097}"
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
"${PB_BIN[@]}" superuser upsert votes-policy@example.test votes-policy-password-123 --dir "$PB_DIR" >/dev/null

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
    -d '{"identity":"votes-policy@example.test","password":"votes-policy-password-123"}' \
    "$API/collections/_superusers/auth-with-password" | json '["token"]'
)"
admin=(-H "Authorization: $ADMIN")

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

create() {
  # create COLLECTION JSON -> id, as the superuser
  curl -fsS "${admin[@]}" -H 'Content-Type: application/json' -d "$2" \
    "$API/collections/$1/records" | json '["id"]'
}

# A local user with a profile, impersonated by a superuser so the collection
# rules apply. Prints "PROFILE_ID TOKEN".
PASSWORD="votes-policy-unused-password-123"
user() {
  # user NAME IS_REVIEWER
  local profile local_user token
  profile="$(create profiles "{\"email\":\"$1@example.test\",\"normalized_email\":\"$1@example.test\",\"auth_source\":\"local\",\"display_name\":\"$1\",\"is_reviewer\":$2}")"
  local_user="$(create local_users "{\"email\":\"$1@example.test\",\"verified\":true,\"profile_id\":\"$profile\",\"is_reviewer\":$2,\"password\":\"$PASSWORD\",\"passwordConfirm\":\"$PASSWORD\"}")"
  token="$(curl -fsS "${admin[@]}" -X POST "$API/collections/local_users/impersonate/$local_user" | json '["token"]')"
  echo "$profile $token"
}

read -r VOTER VOTER_TOKEN <<< "$(user voter false)"
read -r OTHER OTHER_TOKEN <<< "$(user other false)"
read -r REVIEWER REVIEWER_TOKEN <<< "$(user reviewer true)"

competition() {
  # competition SLUG VOTING_ENABLED VOTING_START VOTING_END
  create competitions "{\"title\":\"$1\",\"slug\":\"$1\",\"start_date\":\"2026-01-01 00:00:00.000Z\",\"end_date\":\"2026-02-01 00:00:00.000Z\",\"status\":\"closed\",\"voting_enabled\":$2,\"voting_start_date\":\"$3\",\"voting_end_date\":\"$4\"}"
}
entry() {
  # entry COMPETITION STATUS
  create entries "{\"competition\":\"$1\",\"submitter\":\"$OTHER\",\"title\":\"Entry\",\"status\":\"$2\"}"
}

PAST="2026-01-01 00:00:00.000Z"
LAST_WEEK="2026-02-01 00:00:00.000Z"
FUTURE="2099-01-01 00:00:00.000Z"

OPEN="$(competition voting-open true "$PAST" "$FUTURE")"
NOT_STARTED="$(competition voting-not-started true "$FUTURE" "2099-02-01 00:00:00.000Z")"
ENDED="$(competition voting-ended true "$PAST" "$LAST_WEEK")"
DISABLED="$(competition voting-disabled false "$PAST" "$FUTURE")"

E1="$(entry "$OPEN" approved)"
E2="$(entry "$OPEN" approved)"
E3="$(entry "$OPEN" approved)"
E4="$(entry "$OPEN" approved)"
E5="$(entry "$OPEN" approved)"
E6="$(entry "$OPEN" approved)"
SUBMITTED="$(entry "$OPEN" submitted)"
ELSEWHERE="$(entry "$NOT_STARTED" approved)"
ENDED_ENTRY="$(entry "$ENDED" approved)"
DISABLED_ENTRY="$(entry "$DISABLED" approved)"

ballot() {
  # ballot COMPETITION VOTER RANKING_JSON
  echo "{\"competition\":\"$1\",\"voter\":\"$2\",\"ranking\":$3}"
}

# Given voting is running, when the voter ranks two entries
status="$(request "$VOTER_TOKEN" votes POST "" "$(ballot "$OPEN" "$VOTER" "[\"$E1\",\"$E2\"]")")"
expect "ballot of two entries" 200 "$status"
VOTE="$(json '["id"]' <"$WORK/body")"

# Then a second ballot of the same voter is refused
status="$(request "$VOTER_TOKEN" votes POST "" "$(ballot "$OPEN" "$VOTER" "[\"$E3\"]")")"
expect "second ballot in the same competition" 400 "$status"

revise() {
  request "$VOTER_TOKEN" votes PATCH "/$VOTE" "{\"ranking\":$1}"
}

# When the ranking is too long, empty, repeats an entry or is not a list
status="$(revise "[\"$E1\",\"$E2\",\"$E3\",\"$E4\",\"$E5\",\"$E6\"]")"
expect "six entries" 400 "$status"
status="$(revise '[]')"
expect "no entries" 400 "$status"
status="$(revise "[\"$E1\",\"$E1\"]")"
expect "the same entry twice" 400 "$status"
status="$(revise "{\"1\":\"$E1\"}")"
expect "ranking as an object" 400 "$status"

# When the ranking names an entry that is not approved, or of another competition
status="$(revise "[\"$SUBMITTED\"]")"
expect "entry not approved" 400 "$status"
status="$(revise "[\"$ELSEWHERE\"]")"
expect "entry of another competition" 400 "$status"

# When the ballot is moved to another competition or to another voter
status="$(request "$VOTER_TOKEN" votes PATCH "/$VOTE" "{\"competition\":\"$DISABLED\",\"ranking\":[\"$DISABLED_ENTRY\"]}")"
expect "ballot moved to another competition" 400 "$status"
status="$(request "$VOTER_TOKEN" votes PATCH "/$VOTE" "{\"voter\":\"$OTHER\"}")"
expect "ballot given to another voter" 400 "$status"

# Then a full ranking of five is accepted
status="$(revise "[\"$E5\",\"$E4\",\"$E3\",\"$E2\",\"$E1\"]")"
expect "five entries" 200 "$status"

# A ballot is cast only for oneself, and only when signed in
status="$(request "$OTHER_TOKEN" votes POST "" "$(ballot "$OPEN" "$VOTER" "[\"$E1\"]")")"
expect "ballot in another voter's name" 400 "$status"
status="$(request "" votes POST "" "$(ballot "$OPEN" "$VOTER" "[\"$E1\"]")")"
expect "ballot without signing in" 400 "$status"

# Ballots are secret: only the voter and reviewers read them
status="$(request "$OTHER_TOKEN" votes GET "?filter=competition%3D%22$OPEN%22" "")"
expect "other user lists ballots" 200 "$status"
[ "$(json '["totalItems"]' <"$WORK/body")" = "0" ] || fail "another user sees the voter's ballot"
status="$(request "$OTHER_TOKEN" votes PATCH "/$VOTE" "{\"ranking\":[\"$E1\"]}")"
expect "other user changes the ballot" 404 "$status"
status="$(request "$VOTER_TOKEN" votes GET "/$VOTE" "")"
expect "voter reads own ballot" 200 "$status"
status="$(request "$REVIEWER_TOKEN" votes GET "?filter=competition%3D%22$OPEN%22" "")"
expect "reviewer lists ballots" 200 "$status"
[ "$(json '["totalItems"]' <"$WORK/body")" = "1" ] || fail "the reviewer does not see the ballot"

# Nobody else changes or withdraws a ballot, not even a reviewer
status="$(request "$REVIEWER_TOKEN" votes PATCH "/$VOTE" "{\"ranking\":[\"$E1\"]}")"
expect "reviewer changes another's ballot" 404 "$status"
status="$(request "$REVIEWER_TOKEN" votes DELETE "/$VOTE" "")"
expect "reviewer withdraws another's ballot" 404 "$status"

# The ballot's content does not leak through filters on other collections
status="$(request "$OTHER_TOKEN" competitions GET "?filter=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "votes_via_competition.ranking ~ \"$E5\"")" "")"
expect "other user filters competitions by ballots" 200 "$status"
[ "$(json '["totalItems"]' <"$WORK/body")" = "0" ] || fail "a ballot leaks through a back-relation filter"
status="$(request "$OTHER_TOKEN" entries GET "?filter=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "@collection.votes.ranking ~ id")" "")"
expect "other user filters entries by @collection.votes" "4[0-9][0-9]" "$status"

# An unverified account casts no ballot
UNVERIFIED_PROFILE="$(create profiles '{"email":"unverified@example.test","normalized_email":"unverified@example.test","auth_source":"local","display_name":"unverified"}')"
UNVERIFIED_USER="$(create local_users "{\"email\":\"unverified@example.test\",\"verified\":false,\"profile_id\":\"$UNVERIFIED_PROFILE\",\"password\":\"$PASSWORD\",\"passwordConfirm\":\"$PASSWORD\"}")"
UNVERIFIED_TOKEN="$(curl -fsS "${admin[@]}" -X POST "$API/collections/local_users/impersonate/$UNVERIFIED_USER" | json '["token"]')"
status="$(request "$UNVERIFIED_TOKEN" votes POST "" "$(ballot "$OPEN" "$UNVERIFIED_PROFILE" "[\"$E1\"]")")"
expect "unverified account" 400 "$status"

# A draft competition, or one without a voting end, takes no ballots
DRAFT="$(create competitions "{\"title\":\"voting-draft\",\"slug\":\"voting-draft\",\"start_date\":\"$PAST\",\"end_date\":\"$LAST_WEEK\",\"status\":\"draft\",\"voting_enabled\":true,\"voting_start_date\":\"$PAST\",\"voting_end_date\":\"$FUTURE\"}")"
DRAFT_ENTRY="$(entry "$DRAFT" approved)"
status="$(request "$VOTER_TOKEN" votes POST "" "$(ballot "$DRAFT" "$VOTER" "[\"$DRAFT_ENTRY\"]")")"
expect "draft competition" 400 "$status"
NO_END="$(create competitions "{\"title\":\"voting-no-end\",\"slug\":\"voting-no-end\",\"start_date\":\"$PAST\",\"end_date\":\"$LAST_WEEK\",\"status\":\"closed\",\"voting_enabled\":true,\"voting_start_date\":\"$PAST\"}")"
NO_END_ENTRY="$(entry "$NO_END" approved)"
status="$(request "$VOTER_TOKEN" votes POST "" "$(ballot "$NO_END" "$VOTER" "[\"$NO_END_ENTRY\"]")")"
expect "voting without an end date" 400 "$status"

# Outside the voting period, or without voting, no ballot is cast
status="$(request "$VOTER_TOKEN" votes POST "" "$(ballot "$NOT_STARTED" "$VOTER" "[\"$ELSEWHERE\"]")")"
expect "voting not started" 400 "$status"
status="$(request "$VOTER_TOKEN" votes POST "" "$(ballot "$ENDED" "$VOTER" "[\"$ENDED_ENTRY\"]")")"
expect "voting ended" 400 "$status"
status="$(request "$VOTER_TOKEN" votes POST "" "$(ballot "$DISABLED" "$VOTER" "[\"$DISABLED_ENTRY\"]")")"
expect "voting not enabled" 400 "$status"

# A ballot of an ended vote can no longer be changed or withdrawn by the voter
status="$(request "$ADMIN" votes POST "" "$(ballot "$ENDED" "$VOTER" "[\"$ENDED_ENTRY\"]")")"
expect "superuser records a ballot after the period" 200 "$status"
ENDED_VOTE="$(json '["id"]' <"$WORK/body")"
status="$(request "$VOTER_TOKEN" votes PATCH "/$ENDED_VOTE" "{\"ranking\":[\"$ENDED_ENTRY\"]}")"
expect "voter changes a ballot after the period" 400 "$status"
status="$(request "$VOTER_TOKEN" votes DELETE "/$ENDED_VOTE" "")"
expect "voter withdraws a ballot after the period" 400 "$status"

# While voting runs, the voter may withdraw the ballot
status="$(request "$VOTER_TOKEN" votes DELETE "/$VOTE" "")"
expect "voter withdraws the ballot" 204 "$status"

echo "pb-test-votes-policy: PASS"
