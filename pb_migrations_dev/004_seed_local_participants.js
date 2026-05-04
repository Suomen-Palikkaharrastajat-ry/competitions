// @ts-nocheck
// DEV SEED - do not run in production.
// Given local users try OTP login with real email addresses
// When the dev fixture is applied
// Then those addresses exist as verified participant accounts.

function upsertParticipant(app, email, displayName) {
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
  user.set("is_reviewer", false);
  user.set("keycloak_blocked", false);
  app.save(user);

  let profile = null;
  try {
    profile = app.findFirstRecordByFilter(
      "profiles",
      "normalized_email = {:email}",
      { email: normalized }
    );
  } catch (_) {}

  if (!profile) {
    profile = new Record(app.findCollectionByNameOrId("profiles"));
    profile.set("email", normalized);
    profile.set("normalized_email", normalized);
  }
  profile.set("display_name", displayName);
  profile.set("is_reviewer", false);
  profile.set("auth_source", "local");
  profile.set("local_user", user.id);
  app.save(profile);

  user.set("profile_id", profile.id);
  app.save(user);
}

migrate(
  (app) => {
    upsertParticipant(app, "johndoe@example.com", "John Doe");
    upsertParticipant(app, "janedoe@example.com", "Jane Doe");
  },
  (app) => {
    ["johndoe@example.com", "janedoe@example.com"].forEach((email) => {
      try {
        const normalized = String(email).trim().toLowerCase();
        try {
          app.delete(app.findFirstRecordByFilter(
            "profiles",
            "normalized_email = {:email}",
            { email: normalized }
          ));
        } catch (_) {}
        app.delete(app.findAuthRecordByEmail("local_users", normalized));
      } catch (_) {}
    });
  }
);
