/// <reference path="../pb_data/types.d.ts" />
// The competitions schema on top of the shared production PocketBase
// (1792266035_collections_snapshot.js: users, events, locations).
//
// Given the production `users` collection holds the Keycloak (OIDC) members
// When the competitions schema is added
// Then `users` only gains the profile link and the reviewer flag, email-only
//      participants get their own OTP collection `local_users`, and all
//      competition data relates to the shared `profiles` (ADR-0006).
migrate(
  (app) => {
    // ── users: the existing Keycloak members collection ─────────────────────
    const users = app.findCollectionByNameOrId("users");
    users.fields.add(new TextField({ "id": "text_users_profile_id", "name": "profile_id" }));
    users.fields.add(new TextField({ "id": "text_users_display_name", "name": "display_name" }));
    users.fields.add(new BoolField({ "id": "bool_users_is_reviewer", "name": "is_reviewer" }));
    users.indexes.push("CREATE UNIQUE INDEX `idx_users_profile_id` ON `users` (`profile_id`) WHERE `profile_id` != ''");
    // Members sign up only through Keycloak (OAuth2 runs the create rule as an
    // internal request): a REST sign-up with someone's email would lock that
    // email participant out of OTP. Nobody gives themselves a profile or the
    // reviewer flag.
    users.createRule = "@request.context = \"oauth2\" && @request.body.profile_id:isset = false && @request.body.is_reviewer:isset = false";
    users.updateRule = "id = @request.auth.id && @request.body.profile_id:isset = false && @request.body.is_reviewer:isset = false";
    app.save(users);

    // ── competitions ─────────────────────────────────────────────────────────
    const competitions = new Collection({
      "name": "competitions",
      "type": "base",
      "listRule": "",
      "viewRule": "",
      "createRule": "@request.auth.is_reviewer = true",
      "updateRule": "@request.auth.is_reviewer = true",
      // Deleting a competition removes its entries and reviews (cascade), so
      // only a superuser may do it, from the PocketBase admin UI.
      "deleteRule": null,
      "fields": [
        { "id": "text_title", "name": "title", "type": "text", "required": true, "presentable": true, "min": 1 },
        { "id": "text_slug", "name": "slug", "type": "text", "required": true, "min": 1, "pattern": "^[a-z0-9-]+$" },
        { "id": "text_description", "name": "description", "type": "text" },
        { "id": "text_theme", "name": "theme", "type": "text" },
        { "id": "text_rules", "name": "rules", "type": "text" },
        { "id": "date_start", "name": "start_date", "type": "date", "required": true },
        { "id": "date_end", "name": "end_date", "type": "date", "required": true },
        { "id": "date_judging_end", "name": "judging_end_date", "type": "date" },
        { "id": "file_cover_image", "name": "cover_image", "type": "file", "maxSelect": 1, "maxSize": 5242880, "mimeTypes": ["image/jpeg", "image/png", "image/webp"] },
        { "id": "select_status", "name": "status", "type": "select", "required": true, "maxSelect": 1, "values": ["draft", "open", "closed", "judging", "finished"] },
        { "id": "number_max_entries", "name": "max_entries_per_user", "type": "number", "onlyInt": true },
        { "id": "number_min_images", "name": "min_images_per_entry", "type": "number", "onlyInt": true, "min": 0, "max": 10 },
        { "id": "number_max_images", "name": "max_images_per_entry", "type": "number", "onlyInt": true, "min": 0, "max": 10 }
      ],
      "indexes": [
        "CREATE UNIQUE INDEX `idx_competitions_slug` ON `competitions` (`slug`)"
      ]
    });
    app.save(competitions);

    // ── local_users: email-only participants (OTP) ───────────────────────────
    const localUsers = new Collection({
      "name": "local_users",
      "type": "auth",
      "listRule": null,
      "viewRule": "id = @request.auth.id",
      "createRule": null,
      "updateRule": "id = @request.auth.id && @request.body.is_reviewer:isset = false && @request.body.profile_id:isset = false && @request.body.keycloak_blocked:isset = false",
      "deleteRule": null,
      "fields": [
        { "id": "text_local_profile_id", "name": "profile_id", "type": "text" },
        { "id": "text_local_display", "name": "display_name", "type": "text", "presentable": true },
        { "id": "bool_local_reviewer", "name": "is_reviewer", "type": "bool" },
        { "id": "bool_local_blocked", "name": "keycloak_blocked", "type": "bool" }
      ],
      "indexes": [
        "CREATE UNIQUE INDEX `idx_local_users_profile_id` ON `local_users` (`profile_id`) WHERE `profile_id` != ''"
      ]
    });
    localUsers.otp.enabled = true;
    localUsers.otp.duration = 600;
    localUsers.otp.length = 6;
    localUsers.passwordAuth.enabled = false;
    localUsers.oauth2.enabled = false;
    app.save(localUsers);

    // ── profiles: the domain identity of a member or an email participant ────
    const profiles = new Collection({
      "name": "profiles",
      "type": "base",
      // Reviewers see who submitted an entry (the review queue expands
      // entries.submitter).
      "listRule": "id = @request.auth.profile_id || @request.auth.is_reviewer = true",
      "viewRule": "id = @request.auth.profile_id || @request.auth.is_reviewer = true",
      "createRule": null,
      "updateRule": "id = @request.auth.profile_id && @request.body.is_reviewer:isset = false && @request.body.auth_source:isset = false && @request.body.local_user:isset = false && @request.body.keycloak_user:isset = false && @request.body.email:isset = false && @request.body.normalized_email:isset = false",
      "deleteRule": null,
      "fields": [
        { "id": "email_profile_email", "name": "email", "type": "email", "required": true, "presentable": true },
        { "id": "text_profile_norm_email", "name": "normalized_email", "type": "text", "required": true, "min": 1 },
        { "id": "text_profile_display", "name": "display_name", "type": "text", "presentable": true },
        { "id": "bool_profile_reviewer", "name": "is_reviewer", "type": "bool" },
        { "id": "select_profile_source", "name": "auth_source", "type": "select", "required": true, "maxSelect": 1, "values": ["local", "keycloak"] },
        { "id": "rel_profile_local", "name": "local_user", "type": "relation", "collectionId": localUsers.id, "maxSelect": 1 },
        // The Keycloak member account: a record of the shared `users` collection.
        { "id": "rel_profile_keycloak", "name": "keycloak_user", "type": "relation", "collectionId": users.id, "maxSelect": 1 }
      ],
      "indexes": [
        "CREATE UNIQUE INDEX `idx_profiles_normalized_email` ON `profiles` (`normalized_email`)",
        "CREATE UNIQUE INDEX `idx_profiles_local_user` ON `profiles` (`local_user`) WHERE `local_user` != ''",
        "CREATE UNIQUE INDEX `idx_profiles_keycloak_user` ON `profiles` (`keycloak_user`) WHERE `keycloak_user` != ''"
      ]
    });
    app.save(profiles);

    // ── entries ──────────────────────────────────────────────────────────────
    const entries = new Collection({
      "name": "entries",
      "type": "base",
      "listRule": "status = \"approved\" || submitter = @request.auth.profile_id || @request.auth.is_reviewer = true",
      "viewRule": "status = \"approved\" || submitter = @request.auth.profile_id || @request.auth.is_reviewer = true",
      "createRule": "@request.auth.profile_id != \"\" && @request.auth.verified = true",
      // A participant edits a draft, or a submitted entry until the deadline.
      "updateRule": "@request.auth.is_reviewer = true || (submitter = @request.auth.profile_id && (status = \"draft\" || (status = \"submitted\" && competition.status = \"open\" && competition.end_date > @now)))",
      "deleteRule": "submitter = @request.auth.profile_id && status = \"draft\"",
      "fields": [
        { "id": "rel_competition", "name": "competition", "type": "relation", "required": true, "collectionId": competitions.id, "cascadeDelete": true, "maxSelect": 1 },
        { "id": "text_title", "name": "title", "type": "text", "required": true, "presentable": true, "min": 1 },
        { "id": "text_description", "name": "description", "type": "text" },
        { "id": "file_images", "name": "images", "type": "file", "maxSelect": 10, "maxSize": 10485760, "mimeTypes": ["image/jpeg", "image/png", "image/webp"], "thumbs": ["400x300", "800x600"] },
        { "id": "number_cover_index", "name": "cover_image_index", "type": "number", "onlyInt": true, "min": 0 },
        { "id": "select_status", "name": "status", "type": "select", "required": true, "maxSelect": 1, "values": ["draft", "submitted", "approved", "rejected"] },
        { "id": "date_submitted_at", "name": "submitted_at", "type": "date" },
        { "id": "text_reviewer_note", "name": "reviewer_note", "type": "text" },
        { "id": "rel_submitter_profile", "name": "submitter", "type": "relation", "required": true, "collectionId": profiles.id, "maxSelect": 1 },
        { "id": "autodate_entries_created", "name": "created", "type": "autodate", "onCreate": true, "onUpdate": false },
        { "id": "autodate_entries_updated", "name": "updated", "type": "autodate", "onCreate": true, "onUpdate": true }
      ],
      "indexes": [
        "CREATE INDEX `idx_entries_competition` ON `entries` (`competition`)",
        "CREATE INDEX `idx_entries_status` ON `entries` (`status`)",
        "CREATE INDEX `idx_entries_submitter` ON `entries` (`submitter`)"
      ]
    });
    app.save(entries);

    // ── reviews ──────────────────────────────────────────────────────────────
    const reviews = new Collection({
      "name": "reviews",
      "type": "base",
      "listRule": "reviewer = @request.auth.profile_id || is_published = true || @request.auth.is_reviewer = true",
      "viewRule": "reviewer = @request.auth.profile_id || is_published = true || @request.auth.is_reviewer = true",
      "createRule": "@request.auth.profile_id != \"\" && @request.auth.verified = true && @request.auth.is_reviewer = true",
      "updateRule": "reviewer = @request.auth.profile_id",
      "deleteRule": "reviewer = @request.auth.profile_id",
      "fields": [
        { "id": "rel_entry", "name": "entry", "type": "relation", "required": true, "collectionId": entries.id, "cascadeDelete": true, "maxSelect": 1 },
        { "id": "text_comment", "name": "comment", "type": "text" },
        { "id": "bool_is_published", "name": "is_published", "type": "bool" },
        { "id": "rel_reviewer_profile", "name": "reviewer", "type": "relation", "required": true, "collectionId": profiles.id, "maxSelect": 1 },
        // { criterion id: whole-number score 1-5 }, validated by pb_hooks/reviews.pb.js.
        { "id": "json_scores", "name": "scores", "type": "json", "maxSize": 2000 }
      ],
      "indexes": [
        "CREATE UNIQUE INDEX `idx_reviews_entry_reviewer` ON `reviews` (`entry`, `reviewer`)"
      ]
    });
    app.save(reviews);
  },
  (app) => {
    ["reviews", "entries", "profiles", "local_users", "competitions"].forEach((name) => {
      app.delete(app.findCollectionByNameOrId(name));
    });

    const users = app.findCollectionByNameOrId("users");
    users.fields.removeById("text_users_profile_id");
    users.fields.removeById("text_users_display_name");
    users.fields.removeById("bool_users_is_reviewer");
    users.indexes = users.indexes.filter((idx) => !String(idx).includes("idx_users_profile_id"));
    users.createRule = "";
    users.updateRule = "id = @request.auth.id";
    app.save(users);
  }
);
