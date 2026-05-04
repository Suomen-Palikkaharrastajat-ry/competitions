/// <reference path="../pb_data/types.d.ts" />
migrate(
  (app) => {
    app.db()
      .newQuery(`
        UPDATE entries
        SET created = COALESCE(NULLIF(submitted_at, ''), NULLIF(updated, ''), strftime('%Y-%m-%d %H:%M:%fZ'))
        WHERE created = '' OR created IS NULL
      `)
      .execute();

    app.db()
      .newQuery(`
        UPDATE entries
        SET updated = COALESCE(NULLIF(updated, ''), NULLIF(created, ''), strftime('%Y-%m-%d %H:%M:%fZ'))
        WHERE updated = '' OR updated IS NULL
      `)
      .execute();
  },
  (app) => {
    app.db()
      .newQuery("UPDATE entries SET created = '', updated = ''")
      .execute();
  }
);
