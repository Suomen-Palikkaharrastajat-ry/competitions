// @ts-nocheck
// DEV SEED - do not run in production.
// Given the demo users and the voting schema (ADR-0007)
// When local dev fixture migrations are applied
// Then a competition with a running vote has approved entries to rank, and
//      some ballots for the admin's vote count.

const demoPng = [
  137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, 1, 0,
  0, 0, 1, 8, 6, 0, 0, 0, 31, 21, 196, 137, 0, 0, 0, 13, 73, 68, 65, 84, 120,
  156, 99, 248, 207, 192, 240, 31, 0, 5, 0, 1, 255, 137, 153, 61, 29, 0, 0, 0,
  0, 73, 69, 78, 68, 174, 66, 96, 130
];

const SLUG = "kesakisa-2026";

const ENTRIES = [
  { title: "Demo Vote Lighthouse", email: "participant@example.test", image: "demo-vote-lighthouse.png" },
  { title: "Demo Vote Windmill", email: "johndoe@example.com", image: "demo-vote-windmill.png" },
  { title: "Demo Vote Harbour", email: "janedoe@example.com", image: "demo-vote-harbour.png" },
  { title: "Demo Vote Ferry", email: "johndoe@example.com", image: "demo-vote-ferry.png" }
];

function profileByEmail(app, email) {
  return app.findFirstRecordByFilter("profiles", "normalized_email = {:email}", { email: email });
}

migrate(
  (app) => {
    let competition = null;
    try {
      competition = app.findFirstRecordByData("competitions", "slug", SLUG);
    } catch (_) {
      competition = new Record(app.findCollectionByNameOrId("competitions"));
      competition.set("title", "Kesäkisa 2026");
      competition.set("slug", SLUG);
      competition.set("description", "Demokilpailu yleisöäänestyksen testaamiseen.");
      competition.set("theme", "Kesä");
      competition.set("status", "closed");
      competition.set("start_date", "2026-01-01 00:00:00.000Z");
      competition.set("end_date", "2026-02-01 00:00:00.000Z");
      competition.set("voting_enabled", true);
      competition.set("voting_required", true);
      competition.set("voting_start_date", "2026-02-01 00:00:00.000Z");
      competition.set("voting_end_date", "2099-01-01 00:00:00.000Z");
      app.save(competition);
    }

    const entries = ENTRIES.map((data) => {
      try {
        return app.findFirstRecordByData("entries", "title", data.title);
      } catch (_) {}
      const record = new Record(app.findCollectionByNameOrId("entries"));
      record.set("competition", competition.id);
      record.set("submitter", profileByEmail(app, data.email).id);
      record.set("title", data.title);
      record.set("description", "Hyväksytty työ äänestystä varten.");
      record.set("cover_image_index", 0);
      record.set("status", "approved");
      record.set("submitted_at", "2026-01-15 12:00:00.000Z");
      record.set("images", [$filesystem.fileFromBytes(demoPng, data.image)]);
      app.save(record);
      return record;
    });

    // John and the reviewer have voted; the demo participant and Jane have
    // not, so the admin's count shows their entries left out.
    [
      { email: "johndoe@example.com", ranking: [entries[2], entries[0]] },
      { email: "reviewer@example.test", ranking: [entries[0], entries[3], entries[1], entries[2]] }
    ].forEach((ballot) => {
      const voter = profileByEmail(app, ballot.email);
      const existing = app.findRecordsByFilter(
        "votes",
        "competition = {:competition} && voter = {:voter}",
        "",
        1,
        0,
        { competition: competition.id, voter: voter.id }
      );
      if (existing.length > 0) {
        return;
      }
      const record = new Record(app.findCollectionByNameOrId("votes"));
      record.set("competition", competition.id);
      record.set("voter", voter.id);
      record.set("ranking", ballot.ranking.map((entry) => entry.id));
      app.save(record);
    });
  },
  (app) => {
    try {
      // Deleting the competition removes its entries and ballots (cascade).
      app.delete(app.findFirstRecordByData("competitions", "slug", SLUG));
    } catch (_) {}
  }
);
