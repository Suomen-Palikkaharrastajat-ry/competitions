/// <reference path="../pb_data/types.d.ts" />
// A participant may edit a submitted entry until the competition's end_date,
// as well as a draft. Reviewers may still change any entry. Status transitions
// are checked by pb_hooks/lib/entry_status.js.
migrate(
  (app) => {
    const entries = app.findCollectionByNameOrId("entries");
    entries.updateRule = "@request.auth.is_reviewer = true || (submitter = @request.auth.profile_id && (status = \"draft\" || (status = \"submitted\" && competition.status = \"open\" && competition.end_date > @now)))";
    app.save(entries);
  },
  (app) => {
    const entries = app.findCollectionByNameOrId("entries");
    entries.updateRule = "@request.auth.is_reviewer = true || (submitter = @request.auth.profile_id && status = \"draft\")";
    app.save(entries);
  }
);
