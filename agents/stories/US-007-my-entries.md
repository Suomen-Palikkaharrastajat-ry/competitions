# US-007: View My Entries

**As a participant,** I want to see all my submitted entries and their current status, so that I know whether my entry has been approved and can view published review scores.

## Acceptance Criteria

- [ ] Given I am logged in, when I click "Omat osallistumiset" in the navigation, then I see all entries I have created across all competitions.
- [ ] Given one of my entries is a draft, I see a "Luonnos" badge and a "Muokkaa" button.
- [ ] Given one of my entries has `status = "submitted"`, I see a "Lähetetty" badge. I can open it from the list, and it has an edit button until the competition's end_date has passed.
- [ ] Given I click the title of one of my entries in "Omat osallistumiset", then I see its own page with the title, competition, status, description, images and published review scores.
- [ ] Given I edit a submitted entry before the competition's end_date and save, then the changes are saved, the entry stays `submitted`, and a "Muutokset tallennettu." notice is shown.
- [ ] Given the competition's end_date has passed, when I open a submitted entry, then I see no edit button, and the server refuses changes to it.
- [ ] Given one of my entries has `status = "approved"`, I see a "Hyväksytty" badge.
- [ ] Given one of my entries has `status = "rejected"`, I see a "Hylätty" badge.
- [ ] Given a reviewer has published a review for my entry (`is_published = true`), when I view that entry, then I can see the total score and the reviewer's comment.
- [ ] Given I have no entries, when I open "Omat osallistumiset", then I see an empty state message with a link to browse competitions.

## Notes

- Entry scores visible to submitter: only published reviews. Unpublished reviews are never shown to the submitter.
- Editing a submitted entry is allowed until the competition's `end_date` (not `judging_end_date`). Drafts stay editable. A participant cannot approve, reject or return an entry to draft; the server enforces this (`pb_migrations/013`, `pb_hooks/lib/entry_status.js`, `scripts/test-entry-edit-policy.sh`).
- Routes: `#/omat` (list), `#/omat/<id>` (own page), `#/omat/<id>/muokkaa` (edit form; reloading it opens the participation page).
- The entry list is sorted by creation date, newest first.
