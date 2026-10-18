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

// Sets the values that differ and saves the record only when one did.
function saveChanges(record, values) {
  let changed = false;
  Object.keys(values).forEach((key) => {
    if (record.get(key) !== values[key]) {
      record.set(key, values[key]);
      changed = true;
    }
  });
  if (changed) {
    $app.save(record);
  }
  return changed;
}

function syncAuthFromProfile(authRecord, profile) {
  const values = {
    profile_id: profile.id,
    display_name: profile.get("display_name") || "",
    is_reviewer: !!profile.get("is_reviewer")
  };
  // An OTP login proves the email. A member's `verified` belongs to OAuth2,
  // which sets it only when the email is the one Keycloak returned.
  if (authRecord.collection().name === "local_users") {
    values.verified = true;
  }
  saveChanges(authRecord, values);
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
    // No name from the email: the app asks a new local user to choose one
    // ("Valitse näyttönimi", US-008).
    profile.set("display_name", local.get("display_name") || "");
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

function memberExists(id) {
  try {
    $app.findRecordById("users", id);
    return true;
  } catch (_) {
    return false;
  }
}

// Links a member (the shared `users`) to the profile of their email, or
// creates one. Returns the profile, or null when the member is not linked.
function ensureKeycloakProfile(record) {
  // An unverified member's email was chosen by the client (OAuth2 createData),
  // not proven by Keycloak: it must not take over that email's profile.
  if (!record.verified()) {
    return null;
  }
  const email = normalizeEmail(record.get("email"));
  if (!email) {
    return null;
  }

  let profile = findProfileByEmail(email);
  if (profile) {
    const linked = profile.get("keycloak_user");
    if (linked && linked !== record.id && memberExists(linked)) {
      // Another member's profile: never re-link it.
      return null;
    }
  } else {
    profile = new Record($app.findCollectionByNameOrId("profiles"));
    profile.set("email", email);
    profile.set("normalized_email", email);
    profile.set("display_name", record.get("display_name") || displayNameFromEmail(email));
    profile.set("is_reviewer", !!record.get("is_reviewer"));
  }

  const local = findAuthByEmail("local_users", email);
  const values = { auth_source: "keycloak", keycloak_user: record.id };
  if (local) {
    values.local_user = local.id;
    saveChanges(local, { keycloak_blocked: true });
  }
  if (profile.isNew()) {
    Object.keys(values).forEach((key) => profile.set(key, values[key]));
    $app.save(profile);
  } else {
    saveChanges(profile, values);
  }

  syncAuthFromProfile(record, profile);
  return profile;
}

// Only a verified member counts: OAuth2 verifies a member whose email is the
// one Keycloak returned.
function keycloakExistsForEmail(email) {
  const member = findAuthByEmail("users", normalizeEmail(email));
  return !!member && member.verified();
}

module.exports = {
  ensureKeycloakProfile,
  ensureLocalProfile,
  ensureLocalUser,
  keycloakExistsForEmail,
  normalizeEmail,
  syncAuthFromProfile
};
