/// <reference path="../pb_data/types.d.ts" />
migrate(
  (app) => {
    const competitions = app.findCollectionByNameOrId("competitions");

    const collection = new Collection({
      "name": "entries",
      "type": "base",
      "listRule": "status = \"approved\" || submitter = @request.auth.id",
      "viewRule": "status = \"approved\" || submitter = @request.auth.id",
      "createRule": "@request.auth.id != \"\" && @request.auth.verified = true",
      "updateRule": "submitter = @request.auth.id && status = \"draft\"",
      "deleteRule": "submitter = @request.auth.id && status = \"draft\"",
      "fields": [
        {
          "cascadeDelete": true,
          "collectionId": competitions.id,
          "hidden": false,
          "id": "rel_competition",
          "maxSelect": 1,
          "minSelect": 0,
          "name": "competition",
          "presentable": false,
          "required": true,
          "system": false,
          "type": "relation"
        },
        {
          "cascadeDelete": false,
          "collectionId": "_pb_users_auth_",
          "hidden": false,
          "id": "rel_submitter",
          "maxSelect": 1,
          "minSelect": 0,
          "name": "submitter",
          "presentable": false,
          "required": true,
          "system": false,
          "type": "relation"
        },
        {
          "autogeneratePattern": "",
          "hidden": false,
          "id": "text_title",
          "max": 0,
          "min": 1,
          "name": "title",
          "pattern": "",
          "presentable": true,
          "primaryKey": false,
          "required": true,
          "system": false,
          "type": "text"
        },
        {
          "autogeneratePattern": "",
          "hidden": false,
          "id": "text_description",
          "max": 0,
          "min": 0,
          "name": "description",
          "pattern": "",
          "presentable": false,
          "primaryKey": false,
          "required": false,
          "system": false,
          "type": "text"
        },
        {
          "hidden": false,
          "id": "file_images",
          "maxSelect": 10,
          "maxSize": 10485760,
          "mimeTypes": ["image/jpeg", "image/png", "image/webp"],
          "name": "images",
          "presentable": false,
          "protected": false,
          "required": true,
          "system": false,
          "thumbs": ["400x300", "800x600"],
          "type": "file"
        },
        {
          "hidden": false,
          "id": "number_cover_index",
          "max": null,
          "min": 0,
          "name": "cover_image_index",
          "onlyInt": true,
          "presentable": false,
          "required": false,
          "system": false,
          "type": "number"
        },
        {
          "hidden": false,
          "id": "select_status",
          "maxSelect": 1,
          "name": "status",
          "presentable": false,
          "required": true,
          "system": false,
          "type": "select",
          "values": ["draft", "submitted", "approved", "rejected"]
        },
        {
          "hidden": false,
          "id": "date_submitted_at",
          "max": "",
          "min": "",
          "name": "submitted_at",
          "presentable": false,
          "required": false,
          "system": false,
          "type": "date"
        },
        {
          "autogeneratePattern": "",
          "hidden": false,
          "id": "text_reviewer_note",
          "max": 0,
          "min": 0,
          "name": "reviewer_note",
          "pattern": "",
          "presentable": false,
          "primaryKey": false,
          "required": false,
          "system": false,
          "type": "text"
        }
      ],
      "indexes": [
        "CREATE INDEX `idx_entries_competition` ON `entries` (`competition`)",
        "CREATE INDEX `idx_entries_submitter` ON `entries` (`submitter`)",
        "CREATE INDEX `idx_entries_status` ON `entries` (`status`)"
      ]
    });
    app.save(collection);
  },
  (app) => {
    const col = app.findCollectionByNameOrId("entries");
    app.delete(col);
  }
);
