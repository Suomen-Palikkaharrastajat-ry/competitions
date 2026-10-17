# US-011: Admin Access

**As a participant,** I want the admin area kept from me, so that only reviewers manage competitions and entries.

## Acceptance Criteria

- [ ] Given I am not a reviewer, then the navigation has no "Ylläpito" link.
- [ ] Given I am not a reviewer, when I open an admin address, then I am sent to the dashboard.
- [ ] Given I am a reviewer, when I reload an admin address, then the same admin page opens.
- [ ] Given I am a participant, when I call PocketBase directly, then I cannot create, change or delete competitions, nor change entries I do not own.

## Notes

- The app's check only hides pages. PocketBase rules (migrations 007, 013, 014) are the security boundary; `scripts/test-admin-policy.sh` checks them.
