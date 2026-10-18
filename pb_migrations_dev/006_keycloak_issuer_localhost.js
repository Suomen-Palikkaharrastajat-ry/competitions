// @ts-nocheck
// DEV ONLY — point the members' OIDC provider on `users` at the local Keycloak.
// Production configures its own provider (the organisation's Keycloak) in the
// admin UI; the collections snapshot carries no providers or secrets.
// The issuer uses the host name the browser uses (localhost): Keycloak's
// hostname is localhost, so an auth session started on 127.0.0.1 is not sent
// back on localhost and login fails with "Restart login cookie not found".
migrate(
  (app) => {
    const issuer = $os.getenv("KEYCLOAK_ISSUER_URL") || "http://localhost:8080/auth/realms/competitions";
    const users = app.findCollectionByNameOrId("users");

    users.oauth2.enabled = true;
    users.oauth2.providers = [
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
    app.save(users);
  },
  (app) => {
    const users = app.findCollectionByNameOrId("users");
    users.oauth2.providers = [];
    app.save(users);
  }
);
