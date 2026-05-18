/// <reference path="../pb_data/types.d.ts" />
migrate(
  (app) => {
    const competitions = app.findCollectionByNameOrId("competitions");

    competitions.fields.add(new NumberField({
      "id": "number_min_images",
      "name": "min_images_per_entry",
      "min": 0,
      "max": 10,
      "onlyInt": true,
      "required": false,
      "hidden": false,
      "system": false,
      "presentable": false
    }));

    competitions.fields.add(new NumberField({
      "id": "number_max_images",
      "name": "max_images_per_entry",
      "min": 0,
      "max": 10,
      "onlyInt": true,
      "required": false,
      "hidden": false,
      "system": false,
      "presentable": false
    }));

    app.save(competitions);

    const entries = app.findCollectionByNameOrId("entries");
    const images = entries.fields.getByName("images");
    images.required = false;
    app.save(entries);
  },
  (app) => {
    const competitions = app.findCollectionByNameOrId("competitions");
    competitions.fields.removeByName("min_images_per_entry");
    competitions.fields.removeByName("max_images_per_entry");
    app.save(competitions);

    const entries = app.findCollectionByNameOrId("entries");
    const images = entries.fields.getByName("images");
    images.required = true;
    app.save(entries);
  }
);
