// Entry image limit validation.
//
// Given a competition with optional per-entry image limits
// When an entry is submitted or approved
// Then the server enforces the configured min/max counts.

// The helpers live in lib/entry_limits.js: a handler runs in an isolated
// context and cannot see this file's top-level functions.

onRecordCreateRequest((e) => {
  return require(`${__hooks}/lib/entry_limits.js`).validateEntryImageLimits(e);
}, "entries");

onRecordUpdateRequest((e) => {
  return require(`${__hooks}/lib/entry_limits.js`).validateEntryImageLimits(e);
}, "entries");
