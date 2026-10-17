// Entry status and image limit validation.
//
// Given a participant creates or updates an entry
// When the entry is submitted or approved
// Then the status change must be allowed, and the competition's image limits
// (min/max counts) must hold.

// The helpers live in lib/: a handler runs in an isolated context and cannot
// see this file's top-level functions.

onRecordCreateRequest((e) => {
  require(`${__hooks}/lib/entry_status.js`).validateEntryStatus(e);
  return require(`${__hooks}/lib/entry_limits.js`).validateEntryImageLimits(e);
}, "entries");

onRecordUpdateRequest((e) => {
  require(`${__hooks}/lib/entry_status.js`).validateEntryStatus(e);
  return require(`${__hooks}/lib/entry_limits.js`).validateEntryImageLimits(e);
}, "entries");
