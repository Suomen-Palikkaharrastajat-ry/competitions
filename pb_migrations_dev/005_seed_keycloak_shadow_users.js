// @ts-nocheck
// DEV SEED - do not run in production.
// Given local Keycloak fixture users exist in the Keycloak realm
// When the PocketBase dev fixture is applied
// Then matching users (Keycloak members)/profile records exist so Keycloak-first OTP blocking is testable.

function upsertKeycloakUser(app, email, displayName, isReviewer) {
  const normalized = String(email).trim().toLowerCase();
  let user = null;
  try {
    user = app.findAuthRecordByEmail("users", normalized);
  } catch (_) {}

  if (!user) {
    user = new Record(app.findCollectionByNameOrId("users"));
    user.set("email", normalized);
    user.setRandomPassword();
  }

  user.set("emailVisibility", true);
  user.set("verified", true);
  user.set("display_name", displayName);
  user.set("is_reviewer", isReviewer);
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
  profile.set("is_reviewer", isReviewer);
  profile.set("auth_source", "keycloak");
  profile.set("keycloak_user", user.id);
  app.save(profile);

  user.set("profile_id", profile.id);
  app.save(user);
}

migrate(
  (app) => {
    upsertKeycloakUser(app, "keycloak-participant@example.test", "Keycloak Participant", false);
    upsertKeycloakUser(app, "keycloak-reviewer@example.test", "Keycloak Reviewer", true);
  },
  (app) => {
    ["keycloak-participant@example.test", "keycloak-reviewer@example.test"].forEach((email) => {
      const normalized = String(email).trim().toLowerCase();
      try {
        app.delete(app.findFirstRecordByFilter(
          "profiles",
          "normalized_email = {:email}",
          { email: normalized }
        ));
      } catch (_) {}
      try {
        app.delete(app.findAuthRecordByEmail("users", normalized));
      } catch (_) {}
    });
  }
);
