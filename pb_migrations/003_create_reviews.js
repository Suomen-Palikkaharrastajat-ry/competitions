/// <reference path="../pb_data/types.d.ts" />
migrate(
  (app) => {
    const entries = app.findCollectionByNameOrId("entries");

    const collection = new Collection({
      "name": "reviews",
      "type": "base",
      "listRule": "reviewer = @request.auth.id || is_published = true",
      "viewRule": "reviewer = @request.auth.id || is_published = true",
      "createRule": "@request.auth.id != \"\" && @request.auth.verified = true",
      "updateRule": "reviewer = @request.auth.id",
      "deleteRule": "reviewer = @request.auth.id",
      "fields": [
        {
          "cascadeDelete": true,
          "collectionId": entries.id,
          "hidden": false,
          "id": "rel_entry",
          "maxSelect": 1,
          "minSelect": 0,
          "name": "entry",
          "presentable": false,
          "required": true,
          "system": false,
          "type": "relation"
        },
        {
          "cascadeDelete": false,
          "collectionId": "_pb_users_auth_",
          "hidden": false,
          "id": "rel_reviewer",
          "maxSelect": 1,
          "minSelect": 0,
          "name": "reviewer",
          "presentable": false,
          "required": true,
          "system": false,
          "type": "relation"
        },
        {
          "hidden": false,
          "id": "number_score_theme",
          "max": 5,
          "min": 1,
          "name": "score_theme",
          "onlyInt": true,
          "presentable": false,
          "required": true,
          "system": false,
          "type": "number"
        },
        {
          "hidden": false,
          "id": "number_score_originality",
          "max": 5,
          "min": 1,
          "name": "score_originality",
          "onlyInt": true,
          "presentable": false,
          "required": true,
          "system": false,
          "type": "number"
        },
        {
          "hidden": false,
          "id": "number_score_technique",
          "max": 5,
          "min": 1,
          "name": "score_technique",
          "onlyInt": true,
          "presentable": false,
          "required": true,
          "system": false,
          "type": "number"
        },
        {
          "hidden": false,
          "id": "number_score_presentation",
          "max": 5,
          "min": 1,
          "name": "score_presentation",
          "onlyInt": true,
          "presentable": false,
          "required": true,
          "system": false,
          "type": "number"
        },
        {
          "autogeneratePattern": "",
          "hidden": false,
          "id": "text_comment",
          "max": 0,
          "min": 0,
          "name": "comment",
          "pattern": "",
          "presentable": false,
          "primaryKey": false,
          "required": false,
          "system": false,
          "type": "text"
        },
        {
          "hidden": false,
          "id": "bool_is_published",
          "name": "is_published",
          "presentable": false,
          "required": false,
          "system": false,
          "type": "bool"
        }
      ],
      "indexes": [
        "CREATE UNIQUE INDEX `idx_reviews_entry_reviewer` ON `reviews` (`entry`, `reviewer`)"
      ]
    });
    app.save(collection);
  },
  (app) => {
    const col = app.findCollectionByNameOrId("reviews");
    app.delete(col);
  }
);
