# US-002: Browse Open Competitions

**As a participant,** I want to see a list of currently open competitions so that I can decide which one to enter.

## Acceptance Criteria

- [ ] Given I am logged in, when I open the dashboard, then I see a card for each competition with `status = "open"`.
- [ ] Given a competition card, I can see: title, theme, cover image (or placeholder), and the submission deadline.
- [ ] Given a competition is nearing its deadline (within 7 days), when I view the card, then the deadline is displayed in red (`#C91A09`) to signal urgency.
- [ ] Given there are no open competitions, when I open the dashboard, then I see a message "Ei avoimia kilpailuja juuri nyt."
- [ ] Given I click "Osallistu →" on a competition card, then I am taken to the entry submission form for that competition.
- [ ] Given I have already submitted the maximum number of entries for a competition, when I view that competition's card, then the "Osallistu" button is disabled or hidden, and a note shows "Olet käyttänyt kaikki osallistumispaikkasi tässä kilpailussa."
- [ ] Given a competition has voting enabled and its voting period is running (`voting_start_date <= now < voting_end_date`), when I open the dashboard, then it is listed under "Äänestys käynnissä" with the last day of voting and an "Äänestä" button leading to `#/aanestys/<id>`.

## Notes

- Competitions with `status = "draft"` are never shown to participants.
- Competitions with an active voting period are displayed under "Äänestys käynnissä" (ADR-0007, US-012).
- Past finished competitions may be shown in a separate "Päättyneet kilpailut" section (optional, MVP can omit).
