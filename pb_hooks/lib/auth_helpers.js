function normalizeEmail(email) {
  return String(email || "").trim().toLowerCase();
}

function findAuthByEmail(collection, email) {
  try {
    return $app.findAuthRecordByEmail(collection, email);
  } catch (_) {
    return null;
  }
}

function findProfileByEmail(email) {
  try {
    return $app.findFirstRecordByFilter(
      "profiles",
      "normalized_email = {:email}",
      { email: normalizeEmail(email) }
    );
  } catch (_) {
    return null;
  }
}

function displayNameFromEmail(email) {
  return String(email || "").split("@")[0] || "";
}

function syncAuthFromProfile(authRecord, profile) {
  authRecord.set("profile_id", profile.id);
  authRecord.set("display_name", profile.get("display_name") || "");
  authRecord.set("is_reviewer", !!profile.get("is_reviewer"));
  authRecord.set("verified", true);
  $app.save(authRecord);
}

function ensureLocalUser(email) {
  const normalized = normalizeEmail(email);
  let local = findAuthByEmail("local_users", normalized);
  if (local) {
    return local;
  }

  local = new Record($app.findCollectionByNameOrId("local_users"));
  local.set("email", normalized);
  local.set("emailVisibility", true);
  local.set("verified", true);
  local.setRandomPassword();
  $app.save(local);
  return local;
}

function ensureLocalProfile(local) {
  const email = normalizeEmail(local.get("email"));
  let profile = findProfileByEmail(email);

  if (!profile) {
    profile = new Record($app.findCollectionByNameOrId("profiles"));
    profile.set("email", email);
    profile.set("normalized_email", email);
    profile.set("display_name", local.get("display_name") || displayNameFromEmail(email));
    profile.set("is_reviewer", !!local.get("is_reviewer"));
    profile.set("auth_source", "local");
  }

  profile.set("local_user", local.id);
  if (profile.get("auth_source") !== "keycloak") {
    profile.set("auth_source", "local");
  }
  $app.save(profile);
  syncAuthFromProfile(local, profile);
  return profile;
}

function ensureKeycloakProfile(record) {
  const email = normalizeEmail(record.get("email"));
  let profile = findProfileByEmail(email);
  const local = findAuthByEmail("local_users", email);

  if (!profile) {
    profile = new Record($app.findCollectionByNameOrId("profiles"));
    profile.set("email", email);
    profile.set("normalized_email", email);
    profile.set("display_name", record.get("display_name") || displayNameFromEmail(email));
    profile.set("is_reviewer", !!record.get("is_reviewer"));
  }

  profile.set("auth_source", "keycloak");
  profile.set("keycloak_user", record.id);
  if (local) {
    profile.set("local_user", local.id);
    local.set("keycloak_blocked", true);
    $app.save(local);
  }

  $app.save(profile);
  syncAuthFromProfile(record, profile);
  return profile;
}

function keycloakExistsForEmail(email) {
  return !!findAuthByEmail("keycloak_users", normalizeEmail(email));
}

module.exports = {
  ensureKeycloakProfile,
  ensureLocalProfile,
  ensureLocalUser,
  keycloakExistsForEmail,
  normalizeEmail,
  syncAuthFromProfile
};
