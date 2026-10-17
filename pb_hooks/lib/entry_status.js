// Entry status rules for participants, required by entries.pb.js.
//
// The collection rules decide who may change an entry and whether a submitted
// entry is still editable (migration 013). These checks decide which status a
// participant may set: a draft may be saved or submitted while the competition
// is open, and nothing else changes status. Reviewers and superusers are not
// checked here.

const { relationId } = require(`${__hooks}/lib/entry_limits.js`);

function rejectStatus(message) {
  throw new BadRequestError(message);
}

// The competition accepts entries: its status is "open" and its end_date has
// not passed. (The app lists only open competitions; this keeps the API to it.)
function competitionIsOpen(record) {
  const competitionId = relationId(record.get("competition"));
  if (!competitionId) {
    return false;
  }
  try {
    $app.findFirstRecordByFilter("competitions", "id = {:id} && status = \"open\" && end_date > @now", { id: competitionId });
    return true;
  } catch (_) {
    return false;
  }
}

// Throws a 400 when a participant may not write this entry.
function validateEntryStatus(e) {
  const auth = e.auth;
  if (!auth || auth.collection().name === "_superusers" || auth.get("is_reviewer") === true) {
    return;
  }

  const record = e.record;
  const profileId = String(auth.get("profile_id") || "");

  // A participant creates or moves entries only for themselves, and never
  // moves a saved entry to another competition or another profile.
  if (record.isNew()) {
    if (relationId(record.get("submitter")) !== profileId) {
      rejectStatus("Osallistuja on väärin");
    }
  } else {
    const original = record.original();
    if (relationId(record.get("competition")) !== relationId(original.get("competition"))) {
      rejectStatus("Osallistumista ei voi siirtää toiseen kilpailuun");
    }
    if (relationId(record.get("submitter")) !== relationId(original.get("submitter"))) {
      rejectStatus("Osallistumisen omistajaa ei voi vaihtaa");
    }
  }

  const to = String(record.get("status") || "");
  const from = record.isNew() ? "" : String(record.original().get("status") || "");

  if (from === to) {
    return;
  }

  if ((from === "" || from === "draft") && to === "draft") {
    return;
  }

  if ((from === "" || from === "draft") && to === "submitted") {
    if (!competitionIsOpen(record)) {
      rejectStatus("Kilpailun ilmoittautumisaika on umpeutunut");
    }
    return;
  }

  rejectStatus("Osallistumisen tilaa ei voi muuttaa");
}

module.exports = {
  validateEntryStatus
};
