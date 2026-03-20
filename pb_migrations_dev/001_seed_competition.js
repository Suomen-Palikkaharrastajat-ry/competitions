// @ts-nocheck
// DEV SEED — do not run in production
// Creates one open competition for local development and testing.
migrate(
  (app) => {
    const col = app.findCollectionByNameOrId("competitions");
    const comp = new Record(col, {
      title: "Testikipailu 2026",
      slug: "testikipailu-2026",
      theme: "Space",
      status: "open",
      start_date: "2026-01-01 00:00:00.000Z",
      end_date: "2026-12-31 00:00:00.000Z",
    });
    app.save(comp);
  },
  (app) => {
    try {
      const col = app.findCollectionByNameOrId("competitions");
      const records = app.findRecordsByFilter(
        col.id,
        'slug = "testikipailu-2026"',
        "",
        1,
        0
      );
      records.forEach((r) => app.delete(r));
    } catch (_) {}
  }
);
