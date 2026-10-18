# US-010: Manage Entries

**As an admin (reviewer),** I want to see a competition's entries and approve, reject or reset them, so that the competition's entries are settled.

## Acceptance Criteria

- [ ] Given I open "Osallistumiset" for a competition, then I see every entry of it, drafts included, with the submitter's name, status, image count and published review count.
- [ ] Given an entry is submitted, then I can approve or reject it.
- [ ] Given an entry is approved, then I can reset it to submitted.
- [ ] Given an entry is rejected, then I can reset it to submitted.
- [ ] Given an entry has too few images to be approved, when I approve it, then the server refuses and I am told the status could not be changed.
- [ ] Given I see an entry, then I see its description and all its images.
- [ ] Given the competition has voting enabled, when I open "Osallistumiset", then I see the live vote tally: total ballots cast, the ranked places (with points, 8-5-3-2-1), and any entries excluded from results due to mandatory voting rule (`voting_required`).

## Notes

- The admin never sends `competition` or `submitter` when changing an entry.
- Reject is the only red action.
- Live vote count is visible only to reviewers/admins (`#/admin/osallistumiset/<competitionId>`, ADR-0007).
