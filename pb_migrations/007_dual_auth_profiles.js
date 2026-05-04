/// <reference path="../pb_data/types.d.ts" />
migrate(
  (app) => {
    function normalizeEmail(email) {
      return String(email || "").trim().toLowerCase();
    }

    function relationId(value) {
      if (!value) {
        return "";
      }
      if (Array.isArray(value)) {
        return value.length > 0 ? String(value[0]) : "";
      }
      return String(value);
    }

    function allRecords(collectionName) {
      const records = [];
      let offset = 0;
      while (true) {
        const page = app.findRecordsByFilter(collectionName, "", "", 500, offset);
        if (page.length === 0) {
          break;
        }
        page.forEach((record) => records.push(record));
        offset += page.length;
      }
      return records;
    }

    const localUsers = new Collection({
      "name": "local_users",
      "type": "auth",
      "listRule": null,
      "viewRule": "id = @request.auth.id",
      "createRule": null,
      "updateRule": "id = @request.auth.id && @request.body.is_reviewer:isset = false && @request.body.profile_id:isset = false && @request.body.keycloak_blocked:isset = false",
      "deleteRule": null,
      "fields": [
        { "id": "text_local_profile_id", "name": "profile_id", "type": "text", "required": false, "hidden": false, "system": false, "presentable": false, "autogeneratePattern": "", "pattern": "", "min": 0, "max": 0, "primaryKey": false },
        { "id": "text_local_display", "name": "display_name", "type": "text", "required": false, "hidden": false, "system": false, "presentable": true, "autogeneratePattern": "", "pattern": "", "min": 0, "max": 0, "primaryKey": false },
        { "id": "bool_local_reviewer", "name": "is_reviewer", "type": "bool", "required": false, "hidden": false, "system": false, "presentable": false },
        { "id": "bool_local_blocked", "name": "keycloak_blocked", "type": "bool", "required": false, "hidden": false, "system": false, "presentable": false }
      ],
      "indexes": [
        "CREATE UNIQUE INDEX `idx_local_users_profile_id` ON `local_users` (`profile_id`) WHERE `profile_id` != ''"
      ]
    });
    localUsers.otp.enabled = true;
    localUsers.otp.duration = 600;
    localUsers.otp.length = 6;
    localUsers.passwordAuth.enabled = false;
    app.save(localUsers);

    const keycloakUsers = new Collection({
      "name": "keycloak_users",
      "type": "auth",
      "listRule": null,
      "viewRule": "id = @request.auth.id",
      "createRule": null,
      "updateRule": "id = @request.auth.id && @request.body.is_reviewer:isset = false && @request.body.profile_id:isset = false",
      "deleteRule": null,
      "fields": [
        { "id": "text_keycloak_profile_id", "name": "profile_id", "type": "text", "required": false, "hidden": false, "system": false, "presentable": false, "autogeneratePattern": "", "pattern": "", "min": 0, "max": 0, "primaryKey": false },
        { "id": "text_keycloak_display", "name": "display_name", "type": "text", "required": false, "hidden": false, "system": false, "presentable": true, "autogeneratePattern": "", "pattern": "", "min": 0, "max": 0, "primaryKey": false },
        { "id": "bool_keycloak_reviewer", "name": "is_reviewer", "type": "bool", "required": false, "hidden": false, "system": false, "presentable": false }
      ],
      "indexes": [
        "CREATE UNIQUE INDEX `idx_keycloak_users_profile_id` ON `keycloak_users` (`profile_id`) WHERE `profile_id` != ''"
      ]
    });
    keycloakUsers.oauth2.enabled = true;
    keycloakUsers.passwordAuth.enabled = false;
    keycloakUsers.otp.enabled = false;
    keycloakUsers.oauth2.providers = [
      {
        "name": $os.getenv("KEYCLOAK_PROVIDER_NAME") || "oidc",
        "displayName": "Keycloak",
        "clientId": $os.getenv("KEYCLOAK_CLIENT_ID") || "competitions",
        "clientSecret": $os.getenv("KEYCLOAK_CLIENT_SECRET") || "competitions-dev-secret",
        "authURL": ($os.getenv("KEYCLOAK_ISSUER_URL") || "http://127.0.0.1:8081/realms/competitions") + "/protocol/openid-connect/auth",
        "tokenURL": ($os.getenv("KEYCLOAK_ISSUER_URL") || "http://127.0.0.1:8081/realms/competitions") + "/protocol/openid-connect/token",
        "userInfoURL": ($os.getenv("KEYCLOAK_ISSUER_URL") || "http://127.0.0.1:8081/realms/competitions") + "/protocol/openid-connect/userinfo",
        "pkce": true
      }
    ];
    app.save(keycloakUsers);

    const profiles = new Collection({
      "name": "profiles",
      "type": "base",
      "listRule": "id = @request.auth.profile_id",
      "viewRule": "id = @request.auth.profile_id",
      "createRule": null,
      "updateRule": "id = @request.auth.profile_id && @request.body.is_reviewer:isset = false && @request.body.auth_source:isset = false && @request.body.local_user:isset = false && @request.body.keycloak_user:isset = false",
      "deleteRule": null,
      "fields": [
        { "id": "email_profile_email", "name": "email", "type": "email", "required": true, "hidden": false, "system": false, "presentable": true, "exceptDomains": [], "onlyDomains": [] },
        { "id": "text_profile_norm_email", "name": "normalized_email", "type": "text", "required": true, "hidden": false, "system": false, "presentable": false, "autogeneratePattern": "", "pattern": "", "min": 1, "max": 0, "primaryKey": false },
        { "id": "text_profile_display", "name": "display_name", "type": "text", "required": false, "hidden": false, "system": false, "presentable": true, "autogeneratePattern": "", "pattern": "", "min": 0, "max": 0, "primaryKey": false },
        { "id": "bool_profile_reviewer", "name": "is_reviewer", "type": "bool", "required": false, "hidden": false, "system": false, "presentable": false },
        { "id": "select_profile_source", "name": "auth_source", "type": "select", "required": true, "hidden": false, "system": false, "presentable": false, "maxSelect": 1, "values": ["local", "keycloak"] },
        { "id": "rel_profile_local", "name": "local_user", "type": "relation", "required": false, "hidden": false, "system": false, "presentable": false, "collectionId": localUsers.id, "cascadeDelete": false, "minSelect": 0, "maxSelect": 1 },
        { "id": "rel_profile_keycloak", "name": "keycloak_user", "type": "relation", "required": false, "hidden": false, "system": false, "presentable": false, "collectionId": keycloakUsers.id, "cascadeDelete": false, "minSelect": 0, "maxSelect": 1 }
      ],
      "indexes": [
        "CREATE UNIQUE INDEX `idx_profiles_normalized_email` ON `profiles` (`normalized_email`)",
        "CREATE UNIQUE INDEX `idx_profiles_local_user` ON `profiles` (`local_user`) WHERE `local_user` != ''",
        "CREATE UNIQUE INDEX `idx_profiles_keycloak_user` ON `profiles` (`keycloak_user`) WHERE `keycloak_user` != ''"
      ]
    });
    app.save(profiles);

    const profileByLegacyUserId = {};
    try {
      allRecords("users").forEach((legacyUser) => {
        const email = normalizeEmail(legacyUser.get("email"));
        if (!email) {
          return;
        }

        const local = new Record(localUsers);
        local.set("email", email);
        local.set("emailVisibility", legacyUser.get("emailVisibility"));
        local.set("verified", legacyUser.get("verified"));
        local.set("display_name", legacyUser.get("display_name") || "");
        local.set("is_reviewer", legacyUser.get("is_reviewer") || false);
        local.set("keycloak_blocked", false);
        local.setRandomPassword();
        app.save(local);

        const profile = new Record(profiles);
        profile.set("email", email);
        profile.set("normalized_email", email);
        profile.set("display_name", legacyUser.get("display_name") || "");
        profile.set("is_reviewer", legacyUser.get("is_reviewer") || false);
        profile.set("auth_source", "local");
        profile.set("local_user", local.id);
        app.save(profile);

        local.set("profile_id", profile.id);
        app.save(local);
        profileByLegacyUserId[legacyUser.id] = profile.id;
      });
    } catch (_) {}

    let entries = app.findCollectionByNameOrId("entries");
    entries.fields.add(new RelationField({
      "id": "rel_submitter_tmp",
      "name": "submitter_profile_tmp",
      "collectionId": profiles.id,
      "cascadeDelete": false,
      "minSelect": 0,
      "maxSelect": 1,
      "required": false
    }));
    app.save(entries);
    allRecords("entries").forEach((record) => {
      const oldSubmitter = relationId(record.get("submitter"));
      const profileId = profileByLegacyUserId[oldSubmitter];
      if (profileId) {
        record.set("submitter_profile_tmp", profileId);
        app.save(record);
      }
    });

    entries = app.findCollectionByNameOrId("entries");
    entries.fields.removeByName("submitter");
    entries.indexes = entries.indexes.filter((idx) => !String(idx).includes("idx_entries_submitter"));
    entries.listRule = null;
    entries.viewRule = null;
    entries.createRule = null;
    entries.updateRule = null;
    entries.deleteRule = null;
    app.save(entries);

    entries = app.findCollectionByNameOrId("entries");
    entries.fields.add(new RelationField({
      "id": "rel_submitter_profile",
      "name": "submitter",
      "collectionId": profiles.id,
      "cascadeDelete": false,
      "minSelect": 0,
      "maxSelect": 1,
      "required": true
    }));
    app.save(entries);
    allRecords("entries").forEach((record) => {
      const profileId = relationId(record.get("submitter_profile_tmp"));
      if (profileId) {
        record.set("submitter", profileId);
        app.save(record);
      }
    });

    entries = app.findCollectionByNameOrId("entries");
    entries.fields.removeByName("submitter_profile_tmp");
    entries.indexes = entries.indexes.filter((idx) => !String(idx).includes("idx_entries_submitter"));
    entries.indexes.push("CREATE INDEX `idx_entries_submitter` ON `entries` (`submitter`)");
    entries.listRule = "status = \"approved\" || submitter = @request.auth.profile_id || @request.auth.is_reviewer = true";
    entries.viewRule = "status = \"approved\" || submitter = @request.auth.profile_id || @request.auth.is_reviewer = true";
    entries.createRule = "@request.auth.profile_id != \"\" && @request.auth.verified = true";
    entries.updateRule = "@request.auth.is_reviewer = true || (submitter = @request.auth.profile_id && status = \"draft\")";
    entries.deleteRule = "submitter = @request.auth.profile_id && status = \"draft\"";
    app.save(entries);

    let reviews = app.findCollectionByNameOrId("reviews");
    reviews.fields.add(new RelationField({
      "id": "rel_reviewer_tmp",
      "name": "reviewer_profile_tmp",
      "collectionId": profiles.id,
      "cascadeDelete": false,
      "minSelect": 0,
      "maxSelect": 1,
      "required": false
    }));
    app.save(reviews);
    allRecords("reviews").forEach((record) => {
      const oldReviewer = relationId(record.get("reviewer"));
      const profileId = profileByLegacyUserId[oldReviewer];
      if (profileId) {
        record.set("reviewer_profile_tmp", profileId);
        app.save(record);
      }
    });

    reviews = app.findCollectionByNameOrId("reviews");
    reviews.fields.removeByName("reviewer");
    reviews.indexes = reviews.indexes.filter((idx) => !String(idx).includes("reviewer"));
    reviews.listRule = null;
    reviews.viewRule = null;
    reviews.createRule = null;
    reviews.updateRule = null;
    reviews.deleteRule = null;
    app.save(reviews);

    reviews = app.findCollectionByNameOrId("reviews");
    reviews.fields.add(new RelationField({
      "id": "rel_reviewer_profile",
      "name": "reviewer",
      "collectionId": profiles.id,
      "cascadeDelete": false,
      "minSelect": 0,
      "maxSelect": 1,
      "required": true
    }));
    app.save(reviews);
    allRecords("reviews").forEach((record) => {
      const profileId = relationId(record.get("reviewer_profile_tmp"));
      if (profileId) {
        record.set("reviewer", profileId);
        app.save(record);
      }
    });

    reviews = app.findCollectionByNameOrId("reviews");
    reviews.fields.removeByName("reviewer_profile_tmp");
    reviews.indexes = reviews.indexes.filter((idx) => !String(idx).includes("reviewer"));
    reviews.indexes.push("CREATE UNIQUE INDEX `idx_reviews_entry_reviewer` ON `reviews` (`entry`, `reviewer`)");
    reviews.listRule = "reviewer = @request.auth.profile_id || is_published = true || @request.auth.is_reviewer = true";
    reviews.viewRule = "reviewer = @request.auth.profile_id || is_published = true || @request.auth.is_reviewer = true";
    reviews.createRule = "@request.auth.profile_id != \"\" && @request.auth.verified = true && @request.auth.is_reviewer = true";
    reviews.updateRule = "reviewer = @request.auth.profile_id";
    reviews.deleteRule = "reviewer = @request.auth.profile_id";
    app.save(reviews);

    const competitions = app.findCollectionByNameOrId("competitions");
    competitions.createRule = "@request.auth.is_reviewer = true";
    competitions.updateRule = "@request.auth.is_reviewer = true";
    competitions.deleteRule = "@request.auth.is_reviewer = true";
    app.save(competitions);
  },
  (app) => {
    const users = app.findCollectionByNameOrId("_pb_users_auth_");

    const entries = app.findCollectionByNameOrId("entries");
    entries.fields.removeByName("submitter");
    entries.fields.add(new RelationField({
      "id": "rel_submitter",
      "name": "submitter",
      "collectionId": users.id,
      "cascadeDelete": false,
      "minSelect": 0,
      "maxSelect": 1,
      "required": true
    }));
    entries.listRule = "status = \"approved\" || submitter = @request.auth.id";
    entries.viewRule = "status = \"approved\" || submitter = @request.auth.id";
    entries.createRule = "@request.auth.id != \"\" && @request.auth.verified = true";
    entries.updateRule = "submitter = @request.auth.id && status = \"draft\"";
    entries.deleteRule = "submitter = @request.auth.id && status = \"draft\"";
    app.save(entries);

    const reviews = app.findCollectionByNameOrId("reviews");
    reviews.fields.removeByName("reviewer");
    reviews.fields.add(new RelationField({
      "id": "rel_reviewer",
      "name": "reviewer",
      "collectionId": users.id,
      "cascadeDelete": false,
      "minSelect": 0,
      "maxSelect": 1,
      "required": true
    }));
    reviews.listRule = "reviewer = @request.auth.id || is_published = true";
    reviews.viewRule = "reviewer = @request.auth.id || is_published = true";
    reviews.createRule = "@request.auth.id != \"\" && @request.auth.verified = true";
    reviews.updateRule = "reviewer = @request.auth.id";
    reviews.deleteRule = "reviewer = @request.auth.id";
    app.save(reviews);

    const competitions = app.findCollectionByNameOrId("competitions");
    competitions.createRule = "@request.auth.collectionName = \"users\" && @request.auth.is_reviewer = true";
    competitions.updateRule = "@request.auth.collectionName = \"users\" && @request.auth.is_reviewer = true";
    competitions.deleteRule = "@request.auth.collectionName = \"users\" && @request.auth.is_reviewer = true";
    app.save(competitions);

    ["profiles", "keycloak_users", "local_users"].forEach((name) => {
      try {
        app.delete(app.findCollectionByNameOrId(name));
      } catch (_) {}
    });
  }
);
