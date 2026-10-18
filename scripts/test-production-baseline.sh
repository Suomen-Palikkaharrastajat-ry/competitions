#!/usr/bin/env bash
# Smoke-test the competitions migrations on top of the shared production
# PocketBase (ADR-0006).
#
# Given the production collections snapshot (users, events, locations)
# When the competitions migrations are applied and then reverted
# Then they apply cleanly, and reverting them leaves the production
#      collections exactly as the snapshot made them.
#
# With PB_PRODUCTION_COPY=path/to/pb_data (a copy of the production pb_data,
# e.g. ./pocketbase/pb_data) the same is checked against that data, which is
# copied first and never changed, and no member or event record is lost.
set -euo pipefail

ROOT="${ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
read -r -a PB_BIN <<< "${POCKETBASE:-pocketbase}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

cd "$ROOT"

SNAPSHOT="$(ls pb_migrations/*_collections_snapshot.js | tail -1)"
COMPETITION_MIGRATIONS="$(find pb_migrations -name '*.js' ! -name "$(basename "$SNAPSHOT")" | wc -l)"

fail() {
  echo "$1" >&2
  exit 1
}

# schema DATA_DIR -> the production collections, ids and timestamps left out
schema() {
  python3 - "$1/data.db" <<'EOF'
import json, sqlite3, sys
db = sqlite3.connect(f"file:{sys.argv[1]}?mode=ro", uri=True)
rows = db.execute(
    "select name, type, listRule, viewRule, createRule, updateRule, deleteRule, fields, indexes, options"
    " from _collections where name in ('users', 'events', 'locations') order by name"
)
for name, kind, *rules, fields, indexes, options in rows:
    options = json.loads(options or "{}")
    # The OAuth2 providers and the token secrets belong to the instance, not to
    # the schema (and must never end up in a log).
    options.get("oauth2", {}).pop("providers", None)
    for value in options.values():
        if isinstance(value, dict):
            value.pop("secret", None)
    print(json.dumps([name, kind, rules, json.loads(fields), sorted(json.loads(indexes)), options], sort_keys=True))
EOF
}

count() {
  python3 -c "import sqlite3,sys; print(sqlite3.connect(f'file:{sys.argv[1]}?mode=ro', uri=True).execute(f'select count(*) from {sys.argv[2]}').fetchone()[0])" "$1/data.db" "$2"
}

# revert DATA_DIR -> reverts the competitions migrations. The CLI asks for
# confirmation on a terminal, so give it one.
revert() {
  printf 'y\n' | script -qec "${PB_BIN[*]} migrate down $COMPETITION_MIGRATIONS --dir $1 --migrationsDir ./pb_migrations" /dev/null >"$WORK/revert.log" 2>&1 || true
  grep -q "Reverted" "$WORK/revert.log" || fail "Expected the competitions migrations to revert, got: $(tail -3 "$WORK/revert.log")"
  ! grep -q "Reverted $(basename "$SNAPSHOT")" "$WORK/revert.log" || fail "The production snapshot must not be reverted"
}

# Fresh database: the snapshot alone, then everything, then revert.
mkdir -p "$WORK/baseline-migrations"
cp "$SNAPSHOT" "$WORK/baseline-migrations/"
"${PB_BIN[@]}" migrate up --dir "$WORK/baseline" --migrationsDir "$WORK/baseline-migrations" >/dev/null
schema "$WORK/baseline" >"$WORK/baseline.schema"

"${PB_BIN[@]}" migrate up --dir "$WORK/fresh" --migrationsDir ./pb_migrations >/dev/null
for collection in competitions entries reviews profiles local_users votes; do
  count "$WORK/fresh" "$collection" >/dev/null || fail "Expected collection $collection"
done
revert "$WORK/fresh"
schema "$WORK/fresh" >"$WORK/fresh.schema"
diff -u "$WORK/baseline.schema" "$WORK/fresh.schema" >&2 ||
  fail "Reverting the competitions migrations must leave the production collections as the snapshot made them"

# A copy of the production data, when given.
if [ -n "${PB_PRODUCTION_COPY:-}" ]; then
  [ -f "$PB_PRODUCTION_COPY/data.db" ] || fail "PB_PRODUCTION_COPY has no data.db: $PB_PRODUCTION_COPY"
  cp -r "$PB_PRODUCTION_COPY" "$WORK/production"
  schema "$WORK/production" >"$WORK/production.schema"
  users="$(count "$WORK/production" users)"
  events="$(count "$WORK/production" events)"
  locations="$(count "$WORK/production" locations)"

  "${PB_BIN[@]}" migrate up --dir "$WORK/production" --migrationsDir ./pb_migrations >"$WORK/production.log" 2>&1 ||
    fail "Migrating the production copy failed: $(grep -v DEBUG "$WORK/production.log" | tail -5)"
  grep -q "Applied $(basename "$SNAPSHOT")" "$WORK/production.log" &&
    fail "The production copy must already have the snapshot applied"
  [ "$(count "$WORK/production" users)" = "$users" ] || fail "Members were lost"
  [ "$(count "$WORK/production" events)" = "$events" ] || fail "Events were lost"
  [ "$(count "$WORK/production" locations)" = "$locations" ] || fail "Locations were lost"

  revert "$WORK/production"
  schema "$WORK/production" >"$WORK/production-reverted.schema"
  diff -u "$WORK/production.schema" "$WORK/production-reverted.schema" >&2 ||
    fail "Reverting must leave the production copy's collections as they were"
  echo "pb-test-production-baseline: production copy ($users members, $events events, $locations locations) OK"
fi

echo "pb-test-production-baseline: PASS"
