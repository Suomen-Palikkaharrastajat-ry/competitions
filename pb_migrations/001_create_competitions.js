/// <reference path="../pb_data/types.d.ts" />
migrate(
  (app) => {
    const collection = new Collection({
      "name": "competitions",
      "type": "base",
      "listRule": "",
      "viewRule": "",
      "createRule": "@request.auth.collectionName = \"users\" && @request.auth.verified = true",
      "updateRule": "@request.auth.collectionName = \"users\" && @request.auth.verified = true",
      "deleteRule": "@request.auth.collectionName = \"users\" && @request.auth.verified = true",
      "fields": [
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
          "id": "text_slug",
          "max": 0,
          "min": 1,
          "name": "slug",
          "pattern": "^[a-z0-9-]+$",
          "presentable": false,
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
          "autogeneratePattern": "",
          "hidden": false,
          "id": "text_theme",
          "max": 0,
          "min": 0,
          "name": "theme",
          "pattern": "",
          "presentable": false,
          "primaryKey": false,
          "required": false,
          "system": false,
          "type": "text"
        },
        {
          "autogeneratePattern": "",
          "hidden": false,
          "id": "text_rules",
          "max": 0,
          "min": 0,
          "name": "rules",
          "pattern": "",
          "presentable": false,
          "primaryKey": false,
          "required": false,
          "system": false,
          "type": "text"
        },
        {
          "hidden": false,
          "id": "date_start",
          "max": "",
          "min": "",
          "name": "start_date",
          "presentable": false,
          "required": true,
          "system": false,
          "type": "date"
        },
        {
          "hidden": false,
          "id": "date_end",
          "max": "",
          "min": "",
          "name": "end_date",
          "presentable": false,
          "required": true,
          "system": false,
          "type": "date"
        },
        {
          "hidden": false,
          "id": "date_judging_end",
          "max": "",
          "min": "",
          "name": "judging_end_date",
          "presentable": false,
          "required": false,
          "system": false,
          "type": "date"
        },
        {
          "hidden": false,
          "id": "file_cover_image",
          "maxSelect": 1,
          "maxSize": 5242880,
          "mimeTypes": ["image/jpeg", "image/png", "image/webp"],
          "name": "cover_image",
          "presentable": false,
          "protected": false,
          "required": false,
          "system": false,
          "thumbs": null,
          "type": "file"
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
          "values": ["draft", "open", "closed", "judging", "finished"]
        },
        {
          "hidden": false,
          "id": "number_max_entries",
          "max": null,
          "min": null,
          "name": "max_entries_per_user",
          "onlyInt": true,
          "presentable": false,
          "required": false,
          "system": false,
          "type": "number"
        }
      ],
      "indexes": [
        "CREATE UNIQUE INDEX `idx_competitions_slug` ON `competitions` (`slug`)"
      ]
    });
    app.save(collection);
  },
  (app) => {
    const col = app.findCollectionByNameOrId("competitions");
    app.delete(col);
  }
);
