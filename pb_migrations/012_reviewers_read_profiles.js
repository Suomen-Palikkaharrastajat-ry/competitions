/// <reference path="../pb_data/types.d.ts" />
// Reviewers see who submitted an entry: the review queue expands
// entries.submitter (a profile), which only the profile's owner could read.
migrate((app) => {
  const profiles = app.findCollectionByNameOrId("profiles");
  profiles.listRule = "id = @request.auth.profile_id || @request.auth.is_reviewer = true";
  profiles.viewRule = "id = @request.auth.profile_id || @request.auth.is_reviewer = true";
  app.save(profiles);
}, (app) => {
  const profiles = app.findCollectionByNameOrId("profiles");
  profiles.listRule = "id = @request.auth.profile_id";
  profiles.viewRule = "id = @request.auth.profile_id";
  app.save(profiles);
});
