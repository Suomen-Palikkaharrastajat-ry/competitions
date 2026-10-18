// Ballot validation, required by votes.pb.js (ADR-0007).
//
// PocketBase runs each hook handler in its own isolated context, so this
// helper is loaded with require() inside the handler.
//
// The collection rules decide whose ballot it is. These checks decide whether
// it may be cast: the competition has voting enabled and its voting period is
// running, and the ranking lists 1 to 5 distinct approved entries of that
// competition. A superuser may correct a ballot outside the voting period.

const { relationId } = require(`${__hooks}/lib/entry_limits.js`);

const MAX_RANKS = 5;

function reject(message) {
  throw new BadRequestError(message);
}

function isSuperuser(e) {
  return !!e.auth && e.auth.collection().name === "_superusers";
}

// A JSON field reaches the hook as a wrapped raw value: String() gives its JSON
// text, which parses to the ranking. Anything that is not JSON gives null.
function parseRanking(raw) {
  try {
    return JSON.parse(String(raw));
  } catch (_) {
    return null;
  }
}

function votingIsOpen(competitionId) {
  try {
    $app.findFirstRecordByFilter(
      "competitions",
      "id = {:id} && voting_enabled = true && status != \"draft\" && voting_start_date != \"\" && voting_start_date <= @now && voting_end_date > @now",
      { id: competitionId }
    );
    return true;
  } catch (_) {
    return false;
  }
}

function isApprovedEntryOf(entryId, competitionId) {
  try {
    $app.findFirstRecordByFilter(
      "entries",
      "id = {:id} && competition = {:competition} && status = \"approved\"",
      { id: entryId, competition: competitionId }
    );
    return true;
  } catch (_) {
    return false;
  }
}

// Throws a 400 when the ballot may not be cast or changed.
function validateVote(e) {
  const record = e.record;
  const competitionId = relationId(record.get("competition"));

  if (!record.isNew()) {
    const original = record.original();
    if (competitionId !== relationId(original.get("competition"))) {
      reject("Ääntä ei voi siirtää toiseen kilpailuun");
    }
    if (relationId(record.get("voter")) !== relationId(original.get("voter"))) {
      reject("Äänestäjää ei voi vaihtaa");
    }
  }

  if (!competitionId) {
    reject("Kilpailu on pakollinen");
  }

  if (!isSuperuser(e) && !votingIsOpen(competitionId)) {
    reject("Äänestys ei ole käynnissä");
  }

  const ranking = parseRanking(record.get("ranking"));
  if (!Array.isArray(ranking) || ranking.length < 1 || ranking.length > MAX_RANKS) {
    reject("Valitse 1–5 osallistumista");
  }
  if (!ranking.every((id) => typeof id === "string" && id !== "")) {
    reject("Äänestyslistalla on virheellinen osallistuminen");
  }
  if (new Set(ranking).size !== ranking.length) {
    reject("Sama osallistuminen voi olla listalla vain kerran");
  }
  if (!ranking.every((id) => isApprovedEntryOf(id, competitionId))) {
    reject("Äänestää voi vain kilpailun hyväksyttyjä osallistumisia");
  }
}

// Throws a 400 when the ballot may no longer be withdrawn.
function validateVoteDelete(e) {
  if (!isSuperuser(e) && !votingIsOpen(relationId(e.record.get("competition")))) {
    reject("Äänestys ei ole käynnissä");
  }
}

module.exports = {
  validateVote,
  validateVoteDelete
};
