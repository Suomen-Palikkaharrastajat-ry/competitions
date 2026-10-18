// Review score validation, required by reviews.pb.js.
//
// PocketBase runs each hook handler in its own isolated context, so this
// helper is loaded with require() inside the handler.
//
// The criteria themselves are configured in config.toml, which the server does
// not read; here a score is only checked for shape: a criterion id, and a
// whole number from 1 to 5.

const CRITERION_ID = /^[a-z][a-z0-9_]{0,39}$/;

function isObject(value) {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

// A JSON field reaches the hook as a wrapped raw value: String() gives its JSON
// text, which parses to the scores. Anything that is not JSON gives null.
function parseScores(raw) {
  try {
    return JSON.parse(String(raw));
  } catch (_) {
    return null;
  }
}

function validateReviewScores(e) {
  const scores = parseScores(e.record.get("scores"));
  const ids = isObject(scores) ? Object.keys(scores) : [];

  const valid =
    ids.length > 0 &&
    ids.every((id) => CRITERION_ID.test(id) && Number.isInteger(scores[id]) && scores[id] >= 1 && scores[id] <= 5);

  if (!valid) {
    return e.json(400, {
      code: "validation_failed",
      message: "Jokaisen arviointikriteerin pisteen on oltava kokonaisluku 1–5",
    });
  }

  return e.next();
}

module.exports = {
  validateReviewScores
};
