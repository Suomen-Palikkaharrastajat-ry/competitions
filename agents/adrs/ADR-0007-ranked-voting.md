# ADR-0007: Ranked Voting Next to Reviews

**Status:** Accepted
**Date:** 2026-10-18

---

## Context

Competitions are ranked by reviewer scores (ADR-0005). The club also runs
competitions by ranked voting, until now by email: during a voting period every
voter sends their five best entries, the places give 8, 5, 3, 2 and 1 points,
the organiser counts the votes and a board member checks the count. In some
competitions every participant must vote, or their own entry gets no place.
Separate series (e.g. Pro and Casual) are voted on separately.

## Decision

1. **Voting is a competition setting, next to reviews.** `competitions` gains
   `voting_enabled`, `voting_required`, `voting_start_date` and
   `voting_end_date` (`1792266038_competition_voting.js`). A competition can
   have reviews, voting or both; each gives its own ranking and neither
   replaces the other.
2. **A ballot is a `votes` record.** `competition`, `voter` (a profile) and
   `ranking`, a JSON list of 1 to 5 distinct entry ids in preference order. One
   ballot per voter and competition (unique index). The voter may change it, or
   withdraw it, until the voting period ends.
3. **Any signed-in user votes.** Members (`users`) and OTP participants
   (`local_users`) alike, for any approved entry of the competition, their own
   included.
4. **The server enforces the vote.** `pb_hooks/votes.pb.js` accepts a ballot
   only while voting is enabled, the competition is not a draft and
   `voting_start_date <= now < voting_end_date`, and only for approved entries
   of that competition. A ballot cannot move to another competition or voter.
   A superuser may correct a ballot outside the period.
5. **Ballots are secret.** Only the voter and reviewers can read a ballot.
   Reviewers see the live count in the admin (`#/admin/osallistumiset/<id>`);
   the gallery shows only the result, and only after the voting period ends.
6. **Fixed points.** 1st = 8, 2nd = 5, 3rd = 3, 4th = 2, 5th = 1. Equal points
   are broken by the number of first places, then of second places, and so on;
   entries equal in all of these share a place and are listed by title. The
   Elm app (`Voting.tally`)
   and the gallery (`GalleryTypes.rankByVotes`) count the same way.
7. **Required voting.** When `voting_required` is set, an entry whose submitter
   cast no ballot is left out of the vote result. The review ranking is not
   affected.
8. **No series.** A series is a competition of its own. "At most five" covers
   the case of a series with too few entries.

## Consequences

- Voting dates are days stored at midnight UTC (ADR-0004): voting closes when
  the end day begins. To end voting "14.7. at 23:59", set the end day to 15.7.
  The app shows voters the last day ("Äänestä viimeistään 14.7."), and the
  admin field is labelled as the day voting closes. Helsinki-time entry is a
  later step, as for the other dates.
- The vote page drops from a stored ballot the entries that are no longer
  approved, and the voter saves the ballot again.
- The gallery shows a vote result only when it is rebuilt after the voting
  period, with `POCKETBASE_API_KEY` set (ballots need the superuser token). A
  vote without ballots has no result.
- The points and the five places are not configurable yet. Changing them means
  changing `Voting.points`, `votePoints` and the hook's limit together.
- Voting for one's own entry is allowed. Forbidding it is one more check in
  `pb_hooks/lib/vote_ranking.js` (entry submitter ≠ voter) and a filter on the
  vote page.
- An entry rejected after votes were cast drops out of the count; its ballots'
  other choices still count at their places until the voter saves again.
- Production carries a dead `votes.pb.js` (ADR-0006). Deploying this one
  replaces it.
- The prize draw among the voters is not part of the app.
