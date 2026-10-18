/// <reference path="../pb_data/types.d.ts" />
// Review criteria are configured in config.toml ([app] criteria), so a review
// cannot have one number field per criterion. Its scores move into one JSON
// object keyed by the criterion id: { "theme": 4, "originality": 3, ... }.
// The validation (whole numbers 1–5, one per criterion) is in
// pb_hooks/reviews.pb.js.
//
// The four criteria that existed when this was written become the values here.
const CRITERIA = {
  score_theme: "theme",
  score_originality: "originality",
  score_technique: "technique",
  score_presentation: "presentation",
};

migrate(
  (app) => {
    const reviews = app.findCollectionByNameOrId("reviews");
    reviews.fields.add(new JSONField({
      "id": "json_scores",
      "name": "scores",
      "maxSize": 2000,
      "required": false,
      "presentable": false,
      "hidden": false,
      "system": false
    }));
    app.save(reviews);

    app.findAllRecords("reviews").forEach((record) => {
      const scores = {};
      Object.keys(CRITERIA).forEach((field) => {
        scores[CRITERIA[field]] = Number(record.get(field));
      });
      record.set("scores", scores);
      app.save(record);
    });

    const withoutOld = app.findCollectionByNameOrId("reviews");
    Object.keys(CRITERIA).forEach((field) => withoutOld.fields.removeByName(field));
    app.save(withoutOld);
  },
  (app) => {
    const reviews = app.findCollectionByNameOrId("reviews");
    Object.keys(CRITERIA).forEach((field) => {
      reviews.fields.add(new NumberField({
        "id": "number_" + field,
        "name": field,
        "min": 1,
        "max": 5,
        "onlyInt": true,
        "required": false,
        "presentable": false,
        "system": false,
        "hidden": false
      }));
    });
    app.save(reviews);

    app.findAllRecords("reviews").forEach((record) => {
      const scores = record.get("scores") || {};
      Object.keys(CRITERIA).forEach((field) => {
        record.set(field, Number(scores[CRITERIA[field]]) || 3);
      });
      app.save(record);
    });

    const withOld = app.findCollectionByNameOrId("reviews");
    withOld.fields.removeByName("scores");
    app.save(withOld);
  }
);
