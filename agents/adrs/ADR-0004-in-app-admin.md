# ADR-0004: In-App Admin

**Status:** Accepted
**Date:** 2026-10-17

---

## Context

Competition management, entry approval and review publishing were done in the
PocketBase admin UI (`/_/`). Reviewers were sent there through a link, and most
of the admin's work needs no superuser access. Reviewers already hold the
rights the admin needs: `is_reviewer` lets them create and change competitions
and set entry status (migrations 007, 013, 014).

## Decision

1. The app has an admin area for reviewers: `#/admin` (competitions),
   `#/admin/kilpailut/<id>` and `#/admin/kilpailut/uusi` (create and edit),
   `#/admin/osallistumiset/<competitionId>` (entries of one competition).
2. Admin = reviewer for now. A separate `is_admin` flag is a later decision
   (see the consequences).
3. Deleting a competition is superuser-only (migration 014): deleting cascades
   to entries and reviews. Superusers keep the PocketBase admin UI at `/_/` for
   that and for roles, linked from the admin home.
4. Competition dates are entered as days (`YYYY-MM-DD`) and stored at midnight
   UTC. Helsinki-time entry is a later step.
5. The status lifecycle is `draft → open → closed → judging → finished`. The
   admin moves one step at a time; there is no server-side lifecycle hook yet.
6. Access is enforced by PocketBase rules. The app's check on the route only
   hides pages.

This supersedes the consequence in ADR-0001 that the PocketBase admin UI is the
management interface, and the admin responsibilities listed for the PocketBase
component in ADR-0002.

## Consequences

- Reviewers need no PocketBase login to run a competition.
- Reviewers can change any competition and any entry's status through the API.
  An `is_admin` flag (its own migration) would narrow that later.
- Publishing another reviewer's review is not in the admin yet; reviewers can
  publish only their own (migration 007).
