/// <reference path="../pb_data/types.d.ts" />
migrate(
  (app) => {
    const users = app.findCollectionByNameOrId("_pb_users_auth_");

    // Add competition-platform fields
    users.fields.add(new TextField({
      "id": "text_display_name",
      "name": "display_name",
      "required": false
    }));
    users.fields.add(new BoolField({
      "id": "bool_is_reviewer",
      "name": "is_reviewer",
      "required": false
    }));

    // Enable OTP (6 digits, 10-minute expiry), disable password auth
    users.otp.enabled = true;
    users.otp.duration = 600;
    users.otp.length = 6;
    users.passwordAuth.enabled = false;

    app.save(users);
  },
  (app) => {
    const users = app.findCollectionByNameOrId("_pb_users_auth_");

    users.fields.removeById("text_display_name");
    users.fields.removeById("bool_is_reviewer");

    users.otp.enabled = false;
    users.passwordAuth.enabled = true;

    app.save(users);
  }
);
