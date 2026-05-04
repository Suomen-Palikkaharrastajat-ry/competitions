/// <reference path="../pb_data/types.d.ts" />
migrate(
  (app) => {
    const issuer = $os.getenv("KEYCLOAK_ISSUER_URL") || "http://127.0.0.1:8080/auth/realms/competitions";
    const keycloakUsers = app.findCollectionByNameOrId("keycloak_users");

    keycloakUsers.oauth2.enabled = true;
    keycloakUsers.passwordAuth.enabled = false;
    keycloakUsers.otp.enabled = false;
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
    const issuer = "http://127.0.0.1:8081/realms/competitions";
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
