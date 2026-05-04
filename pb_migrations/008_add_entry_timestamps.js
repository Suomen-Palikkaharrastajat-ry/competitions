/// <reference path="../pb_data/types.d.ts" />
migrate(
  (app) => {
    function hasField(collection, name) {
      try {
        return !!collection.fields.getByName(name);
      } catch (_) {
        return false;
      }
    }

    function allRecords(collectionName) {
      const records = [];
      let offset = 0;
      while (true) {
        const page = app.findRecordsByFilter(collectionName, "", "", 500, offset);
        if (page.length === 0) {
          break;
        }
        page.forEach((record) => records.push(record));
        offset += page.length;
      }
      return records;
    }

    const entries = app.findCollectionByNameOrId("entries");

    if (!hasField(entries, "created")) {
      entries.fields.add(new AutodateField({
        "id": "autodate_entries_created",
        "name": "created",
        "hidden": false,
        "onCreate": true,
        "onUpdate": false,
        "presentable": false,
        "system": false
      }));
    }

    if (!hasField(entries, "updated")) {
      entries.fields.add(new AutodateField({
        "id": "autodate_entries_updated",
        "name": "updated",
        "hidden": false,
        "onCreate": true,
        "onUpdate": true,
        "presentable": false,
        "system": false
      }));
    }

    app.save(entries);

    allRecords("entries").forEach((record) => {
      const fallback = record.get("submitted_at") || new Date().toISOString();
      if (!record.get("created")) {
        record.set("created", fallback);
      }
      if (!record.get("updated")) {
        record.set("updated", fallback);
      }
      app.save(record);
    });
  },
  (app) => {
    const entries = app.findCollectionByNameOrId("entries");
    try {
      entries.fields.removeByName("created");
    } catch (_) {}
    try {
      entries.fields.removeByName("updated");
    } catch (_) {}
    app.save(entries);
  }
);
