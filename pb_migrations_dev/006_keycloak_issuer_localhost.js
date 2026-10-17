// @ts-nocheck
// DEV ONLY — point the Keycloak OAuth provider at the host name the browser uses
// (localhost). Keycloak's hostname is localhost, so an auth session started on
// 127.0.0.1 is not sent back on localhost and login fails with
// "Restart login cookie not found". pb_migrations/010 stored the 127.0.0.1 URLs
// before this was known; this fixture migration re-applies them for local dev only.
migrate(
  (app) => {
    const issuer = $os.getenv("KEYCLOAK_ISSUER_URL") || "http://localhost:8080/auth/realms/competitions";
    const keycloakUsers = app.findCollectionByNameOrId("keycloak_users");

    keycloakUsers.oauth2.providers = [
      {
        "name": $os.getenv("KEYCLOAK_PROVIDER_NAME") || "oidc",
        "displayName": "Keycloak",
        "clientId": $os.getenv("KEYCLOAK_CLIENT_ID") || "competitions",
        "clientSecret": $os.getenv("KEYCLOAK_CLIENT_SECRET") || "competitions-dev-secret",
        "authURL": issuer + "/protocol/openid-connect/auth",
        "tokenURL": issuer + "/protocol/openid-connect/token",
        "userInfoURL": issuer + "/protocol/openid-connect/userinfo",
        "pkce": true
      }
    ];
    app.save(keycloakUsers);
  },
  (app) => {
    const issuer = "http://127.0.0.1:8080/auth/realms/competitions";
    const keycloakUsers = app.findCollectionByNameOrId("keycloak_users");

    keycloakUsers.oauth2.providers = [
      {
        "name": $os.getenv("KEYCLOAK_PROVIDER_NAME") || "oidc",
        "displayName": "Keycloak",
        "clientId": $os.getenv("KEYCLOAK_CLIENT_ID") || "competitions",
        "clientSecret": $os.getenv("KEYCLOAK_CLIENT_SECRET") || "competitions-dev-secret",
        "authURL": issuer + "/protocol/openid-connect/auth",
        "tokenURL": issuer + "/protocol/openid-connect/token",
        "userInfoURL": issuer + "/protocol/openid-connect/userinfo",
        "pkce": true
      }
    ];
    app.save(keycloakUsers);
  }
);
