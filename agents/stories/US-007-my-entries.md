# US-007: View My Entries

**As a participant,** I want to see all my submitted entries and their current status, so that I know whether my entry has been approved and can view published review scores.

## Acceptance Criteria

- [ ] Given I am logged in, when I click "Omat osallistumiset" in the navigation, then I see all entries I have created across all competitions.
- [ ] Given one of my entries is a draft, I see a "Luonnos" badge and a "Muokkaa" button.
- [ ] Given one of my entries has `status = "submitted"`, I see a "Lähetetty" badge and no edit button.
- [ ] Given one of my entries has `status = "approved"`, I see a "Hyväksytty" badge.
- [ ] Given one of my entries has `status = "rejected"`, I see a "Hylätty" badge.
- [ ] Given a reviewer has published a review for my entry (`is_published = true`), when I view that entry, then I can see the total score and the reviewer's comment.
- [ ] Given I have no entries, when I open "Omat osallistumiset", then I see an empty state message with a link to browse competitions.

## Notes

- Entry scores visible to submitter: only published reviews. Unpublished reviews are never shown to the submitter.
- The entry list is sorted by creation date, newest first.
