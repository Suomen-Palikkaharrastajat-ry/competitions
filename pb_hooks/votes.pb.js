// Ballot validation (ADR-0007).
//
// Given a signed-in user casts, changes or withdraws a ballot
// When the competition's voting period is not running, or the ranking is not
// 1 to 5 distinct approved entries of the competition
// Then the server rejects the request with a 400.

// The helper lives in lib/: a handler runs in an isolated context and cannot
// see this file's top-level functions.

onRecordCreateRequest((e) => {
  require(`${__hooks}/lib/vote_ranking.js`).validateVote(e);
  return e.next();
}, "votes");

onRecordUpdateRequest((e) => {
  require(`${__hooks}/lib/vote_ranking.js`).validateVote(e);
  return e.next();
}, "votes");

onRecordDeleteRequest((e) => {
  require(`${__hooks}/lib/vote_ranking.js`).validateVoteDelete(e);
  return e.next();
}, "votes");
