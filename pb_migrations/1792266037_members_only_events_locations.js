/// <reference path="../pb_data/types.d.ts" />
// The shared events and locations are for Keycloak members only.
//
// Given email-only participants sign in to `local_users` with an OTP
// When anyone reads or writes events and locations
// Then only `users` (Keycloak members) see unpublished records or write them;
//      before, `@request.auth.id != ""` matched any auth collection.
migrate(
  (app) => {
    ["events", "locations"].forEach((name) => {
      const collection = app.findCollectionByNameOrId(name);
      const readRule = `// Allow everyone to read published ${name}\n(state != "deleted") && ((state = "published") || (@request.auth.collectionName = "users"))`;
      collection.listRule = readRule;
      collection.viewRule = readRule;
      collection.createRule = "@request.auth.collectionName = \"users\"";
      collection.updateRule = "@request.auth.collectionName = \"users\"";
      app.save(collection);
    });
  },
  (app) => {
    ["events", "locations"].forEach((name) => {
      const collection = app.findCollectionByNameOrId(name);
      const readRule = `// Allow everyone to read published ${name}\n(state != "deleted") && ((state = "published") || (@request.auth.id != ""))`;
      collection.listRule = readRule;
      collection.viewRule = readRule;
      collection.createRule = "@request.auth.id != \"\"";
      collection.updateRule = "@request.auth.id != \"\"";
      app.save(collection);
    });
  }
);
