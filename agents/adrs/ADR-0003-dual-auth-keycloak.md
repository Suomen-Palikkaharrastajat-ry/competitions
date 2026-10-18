# ADR-0003: Dual Auth Collections With Keycloak-First Login

**Status:** Accepted, amended by ADR-0006 (`keycloak_users` is the shared production `users`; no Go wrapper)
**Date:** 2026-05-04

---

## Context

The platform needs to support two authentication paths:

- organization-managed users through Keycloak OIDC
- local users through PocketBase email OTP

PocketBase supports multiple auth collections and OAuth2/OIDC, but enforcing "Keycloak wins" needs server-side hooks (PocketBase JSVM hooks in `pb_hooks/`, run by the stock binary; ADR-0006).

## Decision

PocketBase remains the data source of truth, but domain records no longer point directly at an auth collection. They point at `profiles`.

- `users` (the shared production members collection; originally a separate `keycloak_users`, see ADR-0006) is the auth collection for Keycloak OIDC only.
- `local_users` is an auth collection for email OTP only.
- `profiles` is the shared domain identity collection.
- `entries.submitter` and `reviews.reviewer` relate to `profiles`.
- Both auth collections duplicate `profile_id`, `display_name`, and `is_reviewer` so PocketBase access rules can authorize requests from either auth collection.

The backend is the stock `pocketbase` binary, run with `--migrationsDir pb_migrations --hooksDir pb_hooks` (ADR-0006).

## Auth Rules

1. Local OTP request normalizes the email address.
2. If a matching normalized email exists as a verified member in `users`, the OTP request fails with `409 keycloak_required`.
3. If no matching Keycloak record exists, the backend creates or links a `local_users` record and a `profiles` record, then sends OTP.
4. OTP verification checks Keycloak again. A stale OTP is rejected if a matching verified `users` record appeared after the OTP was issued.
5. Keycloak OAuth login creates or links the matching `profiles` record, only for a verified member (OAuth2 verifies a member whose email is the one Keycloak returned), and never re-links a profile that belongs to another member.
6. If a matching `local_users` record exists, Keycloak login marks it `keycloak_blocked`.
7. Keycloak always wins once the email exists as a verified member in `users`.

## Consequences

- ADR-0002's earlier "OTP only" wording is superseded by this ADR.
- No password authentication is introduced for participants or reviewers.
- Production schema changes still belong in `pb_migrations/`; local fixture records stay in `pb_migrations_dev/`.
- `pb_migrations_dev/` may seed local and Keycloak shadow users for development, but it must never be applied to production data.
- Any future domain relation to "the current user" should relate to `profiles`, not `local_users`, `keycloak_users`, or legacy `users`.
