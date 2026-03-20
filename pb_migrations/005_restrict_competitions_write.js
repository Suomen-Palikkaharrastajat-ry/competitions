/// <reference path="../pb_data/types.d.ts" />
migrate(
  (app) => {
    const col = app.findCollectionByNameOrId("competitions");
    col.createRule = "@request.auth.collectionName = \"users\" && @request.auth.is_reviewer = true";
    col.updateRule = "@request.auth.collectionName = \"users\" && @request.auth.is_reviewer = true";
    col.deleteRule = "@request.auth.collectionName = \"users\" && @request.auth.is_reviewer = true";
    app.save(col);
  },
  (app) => {
    const col = app.findCollectionByNameOrId("competitions");
    col.createRule = "@request.auth.collectionName = \"users\" && @request.auth.verified = true";
    col.updateRule = "@request.auth.collectionName = \"users\" && @request.auth.verified = true";
    col.deleteRule = "@request.auth.collectionName = \"users\" && @request.auth.verified = true";
    app.save(col);
  }
);
