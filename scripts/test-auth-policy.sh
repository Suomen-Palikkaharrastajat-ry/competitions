#!/usr/bin/env bash
set -euo pipefail

ROOT="${ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
read -r -a PB_BIN <<< "${POCKETBASE:-env GOFLAGS=-mod=mod go run ./cmd/competition-pocketbase}"
PB_DIR="$(mktemp -d)"
PB_LOG="$(mktemp)"
MAILPIT_LOG="$(mktemp)"
PB_PORT="${PB_PORT:-18090}"
MAILPIT_PORT="${MAILPIT_PORT:-18025}"
SMTP_PORT="${SMTP_PORT:-11025}"

cleanup() {
  rm -f "/tmp/keycloak-required-body.$$" "/tmp/local-otp-body.$$"
  if [ -n "${PB_PID:-}" ]; then
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

PB_MIGRATIONS_DIR=./pb_migrations "${PB_BIN[@]}" migrate up --dir "$PB_DIR" >/dev/null
PB_MIGRATIONS_DIR=./pb_migrations_dev "${PB_BIN[@]}" migrate up --dir "$PB_DIR" >/dev/null

mailpit --smtp "127.0.0.1:$SMTP_PORT" --listen "127.0.0.1:$MAILPIT_PORT" >"$MAILPIT_LOG" 2>&1 &
MAILPIT_PID=$!

PB_MIGRATIONS_DIR=./pb_migrations \
PB_HOOKS_DIR=./pb_hooks \
KEYCLOAK_ISSUER_URL=http://127.0.0.1:8081/realms/competitions \
"${PB_BIN[@]}" serve --dir "$PB_DIR" --http "127.0.0.1:$PB_PORT" >"$PB_LOG" 2>&1 &
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

echo "pb-test-auth-policy: PASS"
