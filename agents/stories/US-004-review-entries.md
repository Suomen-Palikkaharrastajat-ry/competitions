# US-004: Review and Score Entries

**As a reviewer,** I want to score submitted entries on four criteria and leave a comment, so that the best MOCs are fairly ranked.

## Acceptance Criteria

- [ ] Given I am a reviewer and logged in, when I open "Arvosteltavat", then I see all entries with `status = "submitted"` or `"approved"`.
- [ ] Given I click "Arvioi" on an entry, then a review panel opens showing the entry's images, title, submitter name, and description.
- [ ] Given the review panel is open, I can score each of the four criteria (theme fit, originality, technique, presentation) from 1 to 5 using a star widget.
- [ ] Given I have entered scores, when I look at the total, then it shows the sum of all four scores (max 20).
- [ ] Given I click "Tallenna", when the save succeeds, then the review is stored with `is_published = false` and a success notification is shown.
- [ ] Given I click "Tallenna ja julkaise", when the save succeeds, then `is_published = true` and the review score becomes visible to the submitter.
- [ ] Given I have already reviewed an entry, when I open the review panel again, then my previous scores and comment are pre-filled.
- [ ] Given I click "Hyväksy" on an entry, then the entry status changes to `approved`.
- [ ] Given I click "Hylkää" on an entry, then the entry status changes to `rejected` and it is removed from the main review queue.
- [ ] Given I use the "Ei vielä arvosteltu" filter, then only entries I have not yet reviewed are shown.
- [ ] Given I use the competition filter, then only entries from that competition are shown.

## Notes

- Scores: every configured criterion is scored before saving. The criteria are configured in `config.toml` (`[app] criteria`, ADR-0005); the current four are theme fit, originality, technique and presentation. Default score: 3.
- Unpublished reviews (`is_published = false`) are visible only to the reviewer who wrote them.
- Published reviews are visible to the submitter on their "Omat osallistumiset" page.
- A reviewer may update their review after publishing (re-saves with PATCH).
