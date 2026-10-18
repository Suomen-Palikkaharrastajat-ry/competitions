#!/usr/bin/env bash
set -euo pipefail

ROOT="${ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
cd "$ROOT"

require_literal() {
  local file="$1"
  local literal="$2"
  if ! grep -Fq "$literal" "$file"; then
    echo "Missing expected config in $file: $literal" >&2
    exit 1
  fi
}

reject_literal() {
  local file="$1"
  local literal="$2"
  if grep -Fq "$literal" "$file"; then
    echo "Found stale direct-service config in $file: $literal" >&2
    exit 1
  fi
}

# Given the local stack is reverse-proxied through Caddy
# When validating the Caddyfile
# Then /auth, /_/, /api, /mailpit, and / have explicit routes.
caddy validate --config ./Caddyfile --adapter caddyfile >/dev/null
require_literal Caddyfile "handle /auth*"
require_literal Caddyfile "handle /mailpit*"
require_literal Caddyfile "handle /_*"
require_literal Caddyfile "handle /api/*"
require_literal Caddyfile "reverse_proxy 127.0.0.1:8081"
require_literal Caddyfile "reverse_proxy 127.0.0.1:8090"
require_literal Caddyfile "reverse_proxy 127.0.0.1:8025"
require_literal Caddyfile "reverse_proxy 127.0.0.1:5173"

# Given Keycloak runs behind /auth
# When inspecting devenv.nix
# Then issuer, hostname, relative path, and forwarded headers use the proxied URL.
require_literal devenv.nix 'env.KEYCLOAK_ISSUER_URL = "http://127.0.0.1:8080/auth/realms/competitions";'
require_literal devenv.nix 'http-enabled = true;'
require_literal devenv.nix 'http-relative-path = "/auth";'
require_literal devenv.nix 'hostname = "http://127.0.0.1:8080/auth";'
require_literal devenv.nix 'proxy-headers = "xforwarded";'
reject_literal devenv.nix 'env.KEYCLOAK_ISSUER_URL = "http://127.0.0.1:8081/realms/competitions";'

# Given PocketBase OAuth uses Keycloak
# When inspecting realm and migration config
# Then redirect URIs and provider endpoints use the proxied URLs.
require_literal keycloak/competitions-realm.json '"http://127.0.0.1:8080/api/oauth2-redirect"'
require_literal keycloak/competitions-realm.json '"http://127.0.0.1:8080"'
reject_literal keycloak/competitions-realm.json '"http://127.0.0.1:8090/api/oauth2-redirect"'
reject_literal keycloak/competitions-realm.json '"http://127.0.0.1:8090"'
require_literal pb_migrations_dev/006_keycloak_issuer_localhost.js "http://localhost:8080/auth/realms/competitions"

# Given production configures its own Keycloak provider on the shared users
# When inspecting the production migrations
# Then none of them carries an OAuth2 provider or a client secret.
for migration in pb_migrations/*.js; do
  reject_literal "$migration" "clientSecret"
  reject_literal "$migration" "competitions-dev-secret"
done

echo "test-dev-proxy-config: PASS"
