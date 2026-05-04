# ADR-0003: Dual Auth Collections With Keycloak-First Login

**Status:** Accepted
**Date:** 2026-05-04

---

## Context

The platform needs to support two authentication paths:

- organization-managed users through Keycloak OIDC
- local users through PocketBase email OTP

PocketBase supports multiple auth collections and OAuth2/OIDC, but enforcing "Keycloak wins" needs server-side hooks. Stock PocketBase is therefore wrapped by the repository's custom Go binary.

## Decision

PocketBase remains the data source of truth, but domain records no longer point directly at an auth collection. They point at `profiles`.

- `keycloak_users` is an auth collection for Keycloak OIDC only.
- `local_users` is an auth collection for email OTP only.
- `profiles` is the shared domain identity collection.
- `entries.submitter` and `reviews.reviewer` relate to `profiles`.
- Both auth collections duplicate `profile_id`, `display_name`, and `is_reviewer` so PocketBase access rules can authorize requests from either auth collection.

The local backend is the `competition-pocketbase` Go binary in `cmd/competition-pocketbase`. It registers JavaScript migrations and hooks from `pb_migrations/` and `pb_hooks/`.

## Auth Rules

1. Local OTP request normalizes the email address.
2. If a matching normalized email exists in `keycloak_users`, the OTP request fails with `409 keycloak_required`.
3. If no matching Keycloak record exists, the backend creates or links a `local_users` record and a `profiles` record, then sends OTP.
4. OTP verification checks Keycloak again. A stale OTP is rejected if a matching `keycloak_users` record appeared after the OTP was issued.
5. Keycloak OAuth login creates or links the matching `profiles` record.
6. If a matching `local_users` record exists, Keycloak login marks it `keycloak_blocked`.
7. Keycloak always wins once the email exists in `keycloak_users`.

## Consequences

- ADR-0002's earlier "OTP only" wording is superseded by this ADR.
- No password authentication is introduced for participants or reviewers.
- Production schema changes still belong in `pb_migrations/`; local fixture records stay in `pb_migrations_dev/`.
- `pb_migrations_dev/` may seed local and Keycloak shadow users for development, but it must never be applied to production data.
- Any future domain relation to "the current user" should relate to `profiles`, not `local_users`, `keycloak_users`, or legacy `users`.
