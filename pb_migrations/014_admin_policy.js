/// <reference path="../pb_data/types.d.ts" />
// The in-app admin: reviewers create and change competitions. Deleting a
// competition removes its entries and reviews (cascade), so only a superuser
// may do it, from the PocketBase admin UI.
migrate(
  (app) => {
    const competitions = app.findCollectionByNameOrId("competitions");
    competitions.createRule = "@request.auth.is_reviewer = true";
    competitions.updateRule = "@request.auth.is_reviewer = true";
    competitions.deleteRule = null;
    app.save(competitions);
  },
  (app) => {
    const competitions = app.findCollectionByNameOrId("competitions");
    competitions.deleteRule = "@request.auth.is_reviewer = true";
    app.save(competitions);
  }
);
