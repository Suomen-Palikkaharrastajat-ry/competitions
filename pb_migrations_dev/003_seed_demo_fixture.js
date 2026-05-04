// @ts-nocheck
// DEV SEED - do not run in production.
// Given the schema migrations have run
// When local dev fixture migrations are applied
// Then the Elm SPA and Haskell gallery have realistic demo data.

const demoPng = [
  137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, 1, 0,
  0, 0, 1, 8, 6, 0, 0, 0, 31, 21, 196, 137, 0, 0, 0, 13, 73, 68, 65, 84, 120,
  156, 99, 248, 207, 192, 240, 31, 0, 5, 0, 1, 255, 137, 153, 61, 29, 0, 0, 0,
  0, 73, 69, 78, 68, 174, 66, 96, 130
];

function findFirstByData(app, collectionName, field, value) {
  try {
    return app.findFirstRecordByData(collectionName, field, value);
  } catch (_) {
    return null;
  }
}

function createRecord(app, collectionName, data) {
  const collection = app.findCollectionByNameOrId(collectionName);
  const record = new Record(collection);
  Object.keys(data).forEach((key) => record.set(key, data[key]));
  app.save(record);
  return record;
}

function findProfileByEmail(app, email) {
  try {
    return app.findFirstRecordByFilter(
      "profiles",
      "normalized_email = {:email}",
      { email: String(email).trim().toLowerCase() }
    );
  } catch (_) {
    return null;
  }
}

function createUser(app, email, displayName, isReviewer) {
  const normalized = String(email).trim().toLowerCase();
  let user = null;
  try {
    user = app.findAuthRecordByEmail("local_users", normalized);
  } catch (_) {}

  if (!user) {
    user = new Record(app.findCollectionByNameOrId("local_users"));
    user.set("email", normalized);
    user.setRandomPassword();
  }

  user.set("emailVisibility", true);
  user.set("verified", true);
  user.set("display_name", displayName);
  user.set("is_reviewer", isReviewer);
  user.set("keycloak_blocked", false);
  app.save(user);

  let profile = findProfileByEmail(app, normalized);
  if (!profile) {
    profile = new Record(app.findCollectionByNameOrId("profiles"));
    profile.set("email", normalized);
    profile.set("normalized_email", normalized);
  }
  profile.set("display_name", displayName);
  profile.set("is_reviewer", isReviewer);
  profile.set("auth_source", "local");
  profile.set("local_user", user.id);
  app.save(profile);

  user.set("profile_id", profile.id);
  app.save(user);
  return profile;
}

function createCompetition(app, slug, data) {
  const existing = findFirstByData(app, "competitions", "slug", slug);
  if (existing) {
    return existing;
  }

  return createRecord(app, "competitions", {
    title: data.title,
    slug: slug,
    description: data.description,
    theme: data.theme,
    rules: data.rules,
    status: data.status,
    start_date: data.start_date,
    end_date: data.end_date,
    judging_end_date: data.judging_end_date,
    max_entries_per_user: data.max_entries_per_user
  });
}

function createEntry(app, markerTitle, data) {
  const existing = findFirstByData(app, "entries", "title", markerTitle);
  if (existing) {
    return existing;
  }

  const record = new Record(app.findCollectionByNameOrId("entries"));
  record.set("competition", data.competition.id);
  record.set("submitter", data.submitter.id);
  record.set("title", markerTitle);
  record.set("description", data.description);
  record.set("cover_image_index", 0);
  record.set("status", data.status);
  if (data.submitted_at) {
    record.set("submitted_at", data.submitted_at);
  }
  if (data.reviewer_note) {
    record.set("reviewer_note", data.reviewer_note);
  }
  record.set("images", [
    $filesystem.fileFromBytes(demoPng, data.imageName)
  ]);
  app.save(record);
  return record;
}

function createReview(app, entry, reviewer, data) {
  const existing = app.findRecordsByFilter(
    "reviews",
    "entry = {:entry} && reviewer = {:reviewer}",
    "",
    1,
    0,
    { entry: entry.id, reviewer: reviewer.id }
  );

  if (existing.length > 0) {
    return existing[0];
  }

  return createRecord(app, "reviews", {
    entry: entry.id,
    reviewer: reviewer.id,
    score_theme: data.score_theme,
    score_originality: data.score_originality,
    score_technique: data.score_technique,
    score_presentation: data.score_presentation,
    comment: data.comment,
    is_published: data.is_published
  });
}

migrate(
  (app) => {
    const participant = createUser(
      app,
      "participant@example.test",
      "Demo Participant",
      false
    );
    const reviewer = createUser(
      app,
      "reviewer@example.test",
      "Demo Reviewer",
      true
    );

    const openCompetition = createCompetition(app, "avaruusasema-2026", {
      title: "Avaruusasema 2026",
      description: "Rakenna oma LEGO avaruusaseman moduuli.",
      theme: "Avaruusasema",
      rules: "Yksi paakuva ja enintaan kymmenen lisakuvaa per osallistuminen.",
      status: "open",
      start_date: "2026-01-01 00:00:00.000Z",
      end_date: "2026-12-31 23:59:59.000Z",
      judging_end_date: "2027-01-15 23:59:59.000Z",
      max_entries_per_user: 3
    });

    const finishedCompetition = createCompetition(app, "talvikaupunki-2025", {
      title: "Talvikaupunki 2025",
      description: "Valmis demokilpailu staattisen gallerian testaamiseen.",
      theme: "Talvikaupunki",
      rules: "Valmiit tyot naytetaan julkisessa galleriassa.",
      status: "finished",
      start_date: "2025-01-01 00:00:00.000Z",
      end_date: "2025-02-28 23:59:59.000Z",
      judging_end_date: "2025-03-15 23:59:59.000Z",
      max_entries_per_user: 2
    });

    const draftEntry = createEntry(app, "Demo Draft Rover", {
      competition: openCompetition,
      submitter: participant,
      description: "Luonnos osallistujan muokattavaksi.",
      status: "draft",
      submitted_at: "",
      reviewer_note: "",
      imageName: "demo-draft-rover.png"
    });

    const submittedEntry = createEntry(app, "Demo Submitted Station", {
      competition: openCompetition,
      submitter: participant,
      description: "Lahetetty tyo arviointijonon testaamiseen.",
      status: "submitted",
      submitted_at: "2026-02-01 12:00:00.000Z",
      reviewer_note: "",
      imageName: "demo-submitted-station.png"
    });

    const approvedEntry = createEntry(app, "Demo Approved Skyline", {
      competition: finishedCompetition,
      submitter: participant,
      description: "Hyvaksytty tyo galleriaa ja pisteita varten.",
      status: "approved",
      submitted_at: "2025-02-01 12:00:00.000Z",
      reviewer_note: "",
      imageName: "demo-approved-skyline.png"
    });

    const rejectedEntry = createEntry(app, "Demo Rejected Outpost", {
      competition: openCompetition,
      submitter: participant,
      description: "Hylatty tyo statuksen ja arviointinakyminen testaamiseen.",
      status: "rejected",
      submitted_at: "2026-02-02 12:00:00.000Z",
      reviewer_note: "Demo: puuttuva paakuva.",
      imageName: "demo-rejected-outpost.png"
    });

    createReview(app, approvedEntry, reviewer, {
      score_theme: 5,
      score_originality: 4,
      score_technique: 5,
      score_presentation: 4,
      comment: "Vahva tunnelma ja selkea esittely.",
      is_published: true
    });

    createReview(app, submittedEntry, reviewer, {
      score_theme: 3,
      score_originality: 3,
      score_technique: 3,
      score_presentation: 3,
      comment: "Tallennettu mutta ei julkaistu demoarvio.",
      is_published: false
    });

    // Keep references alive for migration validation in older JS runtimes.
    [draftEntry, rejectedEntry].forEach((record) => record.id);
  },
  (app) => {
    [
      "Demo Draft Rover",
      "Demo Submitted Station",
      "Demo Approved Skyline",
      "Demo Rejected Outpost"
    ].forEach((title) => {
      const record = findFirstByData(app, "entries", "title", title);
      if (record) {
        app.delete(record);
      }
    });

    ["avaruusasema-2026", "talvikaupunki-2025"].forEach((slug) => {
      const record = findFirstByData(app, "competitions", "slug", slug);
      if (record) {
        app.delete(record);
      }
    });

    ["participant@example.test", "reviewer@example.test"].forEach((email) => {
      try {
        const profile = findProfileByEmail(app, email);
        if (profile) {
          app.delete(profile);
        }
        app.delete(app.findAuthRecordByEmail("local_users", email));
      } catch (_) {}
    });
  }
);
