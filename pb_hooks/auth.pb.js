// Dual-auth policy for the competition platform.
//
// Given local OTP and Keycloak OIDC auth collections
// When a login request is processed
// Then Keycloak-linked emails always win over local OTP accounts.

onRecordRequestOTPRequest((e) => {
  const auth = require(`${__hooks}/lib/auth_helpers.js`);
  const body = e.requestInfo().body || {};
  const email = auth.normalizeEmail(body.email);

  if (auth.keycloakExistsForEmail(email)) {
    return e.json(409, {
      code: "keycloak_required",
      message: "This email must sign in with Keycloak."
    });
  }

  const local = auth.ensureLocalUser(email);
  auth.ensureLocalProfile(local);
  e.record = local;

  return e.next();
}, "local_users");

onRecordAuthWithOTPRequest((e) => {
  const auth = require(`${__hooks}/lib/auth_helpers.js`);
  const email = auth.normalizeEmail(e.record && e.record.get("email"));

  if (auth.keycloakExistsForEmail(email) || !!e.record.get("keycloak_blocked")) {
    return e.json(409, {
      code: "keycloak_required",
      message: "This email must sign in with Keycloak."
    });
  }

  auth.ensureLocalProfile(e.record);
  return e.next();
}, "local_users");

onRecordAuthWithOAuth2Request((e) => {
  const auth = require(`${__hooks}/lib/auth_helpers.js`);
  const result = e.next();
  auth.ensureKeycloakProfile(e.record);
  return result;
}, "keycloak_users");

onRecordAfterUpdateSuccess((e) => {
  const auth = require(`${__hooks}/lib/auth_helpers.js`);
  const profile = e.record;
  const localId = profile.get("local_user");
  const keycloakId = profile.get("keycloak_user");

  if (localId) {
    try {
      auth.syncAuthFromProfile($app.findRecordById("local_users", localId), profile);
    } catch (_) {}
  }

  if (keycloakId) {
    try {
      auth.syncAuthFromProfile($app.findRecordById("keycloak_users", keycloakId), profile);
    } catch (_) {}
  }
}, "profiles");
