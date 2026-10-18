// Review score validation.
//
// Given a reviewer creates or updates a review
// When the scores are not an object of whole-number scores from 1 to 5, keyed
// by criterion id
// Then the server rejects the review with validation_failed.

// The helper lives in lib/: a handler runs in an isolated context and cannot
// see this file's top-level functions.

onRecordCreateRequest((e) => {
  return require(`${__hooks}/lib/review_scores.js`).validateReviewScores(e);
}, "reviews");

onRecordUpdateRequest((e) => {
  return require(`${__hooks}/lib/review_scores.js`).validateReviewScores(e);
}, "reviews");
