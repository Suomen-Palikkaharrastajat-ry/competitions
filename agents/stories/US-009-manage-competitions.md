# US-009: Manage Competitions

**As an admin (reviewer),** I want to create and edit competitions and move them through their status, so that participants see open competitions at the right time.

## Acceptance Criteria

- [ ] Given I am a reviewer, when I open "Ylläpito", then I see every competition, whatever its status, with its status and dates.
- [ ] Given I am not a reviewer, when I open `#/admin`, then I am sent to the dashboard.
- [ ] Given I click "+ Uusi kilpailu", when I fill in the name, the address name (slug) and the dates and save, then the competition is created.
- [ ] Given a form field is invalid, when I save, then the form keeps my values and each problem is shown in an alert.
- [ ] Given I edit a competition, then its form shows its current values.
- [ ] Given I edit or create a competition, then I can configure ranked voting: toggle "Yleisöäänestys käytössä", set voting start and end dates, and toggle "Osallistujien on äänestettävä" (ADR-0007).
- [ ] Given I edit a competition, when I press "Siirrä tilaan: …", then the status moves to the next or the previous status only, and it is saved at once.
- [ ] Given I want to delete a competition, then I cannot do it here: deleting is superuser-only in PocketBase.
- [ ] Given I need roles or superuser tasks, when I open "Ylläpito", then a link opens the PocketBase admin.

## Notes

- Dates are days stored at midnight UTC. The slug must be unique.
- Image limits are 0–10 and min ≤ max; the number of entries per participant may be left empty for the default.
- Voting settings (ADR-0007): `voting_enabled`, `voting_required`, `voting_start_date`, `voting_end_date`.
- Rules: `pb_migrations/1792266036_competitions_schema.js`, `1792266038_competition_voting.js`; checked by `scripts/test-admin-policy.sh` and `scripts/test-votes-policy.sh`.
