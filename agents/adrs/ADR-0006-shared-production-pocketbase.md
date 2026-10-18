# ADR-0006: Competitions on the Shared Production PocketBase

**Status:** Accepted
**Date:** 2026-10-17
**Amends:** ADR-0001 (the custom Go binary), ADR-0003 (`keycloak_users`)

---

## Context

The organisation already runs one PocketBase (`data.palikkaharrastajat.fi`,
copy in the gitignored `pocketbase/`). It is the stock prebuilt binary, updated
with `./pocketbase update`, at 0.40.x. It holds:

- `users`: the members, OIDC only (the organisation's Keycloak, provider
  `oidc`; password and OTP disabled; `username` mapped from Keycloak).
- `events` and `locations`, written by members (`created_by`/`updated_by`
  relate to `users`, stamped by `pb_hooks/events.pb.js` and
  `pb_hooks/locations.pb.js`).

The competitions platform was built against its own PocketBase: a Go wrapper
binary, a separate `keycloak_users` collection with its own OIDC client, and
migrations 001–015 that also changed and converted `users`. None of that was
ever deployed with real data.

## Decision

1. **One PocketBase.** The competitions schema is added to the production
   PocketBase. `pb_migrations/` starts from production's
   `1792266035_collections_snapshot.js` (already applied there, carries no
   provider secrets); the competitions migrations follow it with later
   timestamps. The old 001–015 are squashed into
   `1792266036_competitions_schema.js`.
2. **Stock PocketBase.** The repository runs the same stock binary as
   production (built from source in `overlays.nix`, with
   `--migrationsDir`/`--hooksDir`). The Go wrapper is removed.
3. **Members are `users`.** The production `users` collection replaces
   `keycloak_users`. It only gains `profile_id`, `display_name` and
   `is_reviewer`. Members sign up only through Keycloak
   (`@request.context = "oauth2"`): a REST sign-up with someone's email would
   lock that email participant out of OTP. Neither create nor update may set
   `profile_id` or `is_reviewer`.
4. **Email participants are `local_users`** (OTP only), as in ADR-0003. The
   Keycloak-first rules of ADR-0003 hold, with `users` in place of
   `keycloak_users`. `profiles.keycloak_user` relates to `users`.
5. **Events and locations are members-only.** Their rules require
   `@request.auth.collectionName = "users"` instead of
   `@request.auth.id != ""`, so an OTP participant cannot read unpublished
   records or write them (`1792266037_members_only_events_locations.js`).
6. **A member's profile is linked before the auth response.** The `users`
   `onRecordAuthRequest` hook creates or links the member's profile, so even
   the first login answers with `profile_id`, and every refresh brings the
   reviewer flag from the profile (writing only what changed). Only a
   *verified* member is linked: OAuth2 lets the client choose the email of a
   new record (`createData`) and verifies it only when it is the email
   Keycloak returned, so an unverified record must not take over that email's
   profile, and the hook never sets `verified` itself. A profile linked to
   another member is never re-linked, and a profile's email cannot be changed
   by its owner. A member login never fails because of competitions: a
   failure is only logged.
7. **The production OIDC provider is configured in production**, not in
   migrations. Local development sets the local Keycloak on `users` in
   `pb_migrations_dev/006_keycloak_issuer_localhost.js`.

## Consequences

- `make pb-test-production-baseline` checks that the migrations apply on the
  snapshot and revert to it exactly; with
  `PB_PRODUCTION_COPY=pocketbase/pb_data` it checks a copy of the production
  data too. `make pb-test-auth-policy` checks the members-only rules.
- Every member who signs in to any app on this PocketBase gets a `profiles`
  record.
- Deploying means copying `pb_migrations/` and the competitions hooks to the
  production `pb_migrations/` and `pb_hooks/`. Production's dead
  `submission.pb.js` (no such collection; it uses the removed `$app.dao()`) is
  not part of the repository and should be removed there. Its old dead
  `votes.pb.js` is replaced by the repository's ballot hook (ADR-0007).
- The stock binary writes a migration file for every collection change made
  through the API or the admin UI (`--automigrate`, default on). That is kept
  for local development (`make pb-dev`, `devenv up`), where schema changes are
  authored; the test scripts pass `--automigrate=false`.
- A local `.devenv/state/pocketbase` made by the old migrations must be
  deleted once; the squashed migrations do not apply on top of it.
- Upgrading PocketBase: bump `overlays.nix` after production, then run the
  PocketBase smoke tests.
