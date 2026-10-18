# US-012: Vote for the Best Entries

**As a signed-in user,** I want to rank my five favourite entries of a competition during its voting period, so that the competition gets a public vote result next to the reviewers' ranking.

**As an organiser,** I want to enable voting per competition, require participants to vote, and see the live count, so that I no longer count emailed votes by hand.

## Acceptance Criteria

- [ ] Given a competition with voting enabled and its voting period running, when I open the dashboard, then it is listed under "Äänestys käynnissä" with the last day of voting and an "Äänestä" button.
- [ ] Given I open the vote page, then every approved entry of the competition is shown with its first image, title and a "Valitse" button.
- [ ] Given I choose entries, then they fill the places 1.–5. in the order I chose them, each with its first image and points (8, 5, 3, 2, 1).
- [ ] Given five entries are chosen, then the other entries cannot be chosen.
- [ ] Given entries are on my ballot, then I can move each up or down and remove it, with buttons that work from the keyboard.
- [ ] Given I click "Tallenna ääni" with at least one entry, then my ballot is saved; when I come back, it is shown for changing.
- [ ] Given the voting period has not started or has ended, when I try to save, then the server refuses the ballot and I see its reason.
- [ ] Given an entry on my stored ballot is no longer approved, when I open the vote page, then it is taken off my ballot and I am asked to save again.
- [ ] Given voting is required, then the vote page says that a participant who does not vote gets no place in the vote result.
- [ ] Given I am an organiser (reviewer), when I edit a competition, then I can enable voting, require it, and set its start and end days.
- [ ] Given I am an organiser, when I open a voting competition's entries, then I see the number of ballots, the places and points, and the entries left out because their submitter did not vote.
- [ ] Given the voting period has ended, when the gallery is built, then the competition shows "Yleisöäänestys" with places and points. Ballots are never shown.

## Notes

- Any signed-in user may vote, members and OTP participants alike, for any approved entry, their own included (ADR-0007).
- Only the voter and reviewers can read a ballot.
- Voting and reviews are independent: a competition can have either or both.
- Pro and Casual series are separate competitions.
