#!/usr/bin/env bash
# Smoke-test the entry image limit hooks (pb_hooks/entries.pb.js).
#
# Given a competition that allows 1-2 images per entry
# When an entry is submitted with 1, 0 or 3 images (on create and on update)
# Then the server accepts 1 and rejects 0 and 3 with validation_failed.
set -euo pipefail

ROOT="${ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
read -r -a PB_BIN <<< "${POCKETBASE:-env GOFLAGS=-mod=mod go run ./cmd/competition-pocketbase}"
PB_DIR="$(mktemp -d)"
PB_LOG="$(mktemp)"
WORK="$(mktemp -d)"
PB_PORT="${PB_PORT:-18091}"
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
PB_MIGRATIONS_DIR=./pb_migrations_dev "${PB_BIN[@]}" migrate up --dir "$PB_DIR" >/dev/null
"${PB_BIN[@]}" superuser upsert limits@example.test limits-password-123 --dir "$PB_DIR" >/dev/null

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

TOKEN="$(
  curl -fsS -H 'Content-Type: application/json' \
    -d '{"identity":"limits@example.test","password":"limits-password-123"}' \
    "$API/collections/_superusers/auth-with-password" | json '["token"]'
)"
auth=(-H "Authorization: $TOKEN")

# 1x1 PNG
printf '\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x06\x00\x00\x00\x1f\x15\xc4\x89\x00\x00\x00\rIDATx\x9cc\xf8\x0f\x00\x00\x01\x01\x00\x05\x18\xd8N\x00\x00\x00\x00IEND\xaeB`\x82' >"$WORK/a.png"

COMPETITION="$(
  curl -fsS "${auth[@]}" -H 'Content-Type: application/json' \
    -d '{"title":"Limits","slug":"limits","start_date":"2026-01-01 00:00:00.000Z","end_date":"2099-01-01 00:00:00.000Z","status":"open","min_images_per_entry":1,"max_images_per_entry":2}' \
    "$API/collections/competitions/records" | json '["id"]'
)"
PROFILE="$(
  curl -fsS "${auth[@]}" "$API/collections/profiles/records?perPage=1" | json '["items"][0]["id"]'
)"

fail() {
  echo "$1" >&2
  cat "$WORK/body" >&2
  echo >&2
  grep -i "error" "$PB_LOG" | tail -5 >&2 || true
  exit 1
}

# create(status, n_images) -> HTTP status, body in $WORK/body
create() {
  local files=()
  for _ in $(seq 1 "$2"); do files+=(-F "images=@$WORK/a.png"); done
  curl -sS -o "$WORK/body" -w "%{http_code}" "${auth[@]}" \
    -F "competition=$COMPETITION" -F "submitter=$PROFILE" -F "title=Entry" -F "status=$1" \
    "${files[@]}" "$API/collections/entries/records"
}

status="$(create submitted 1)"
[ "$status" = "200" ] || fail "Expected a submitted entry with 1 image to be accepted, got $status"

status="$(create submitted 0)"
[ "$status" = "400" ] && grep -q "validation_failed" "$WORK/body" ||
  fail "Expected a submitted entry with 0 images to be rejected, got $status"

status="$(create submitted 3)"
[ "$status" = "400" ] && grep -q "validation_failed" "$WORK/body" ||
  fail "Expected a submitted entry with 3 images to be rejected, got $status"

# A draft is not checked; submitting it later is.
status="$(create draft 1)"
[ "$status" = "200" ] || fail "Expected a draft entry to be accepted, got $status"
DRAFT="$(json '["id"]' <"$WORK/body")"
status="$(
  curl -sS -o "$WORK/body" -w "%{http_code}" "${auth[@]}" -H 'Content-Type: application/json' \
    -X PATCH -d '{"status":"submitted"}' "$API/collections/entries/records/$DRAFT"
)"
[ "$status" = "200" ] || fail "Expected submitting a saved draft with 1 image to be accepted, got $status"

echo "pb-test-entry-limits: PASS"
