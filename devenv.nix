let
  ci =
    { pkgs, ... }:
    let
      hpkgs = pkgs.haskell.packages.ghc96.override {
        overrides = import ./overrides.nix { inherit pkgs; };
      };
      npmTools = pkgs.callPackage ./pkgs/npm-tools.nix { };
      competitionPackage = hpkgs.callCabal2nix "competition" ./. { };
      competitionCommand = pkgs.writeShellScriptBin "competition-nix" ''
        exec ${competitionPackage}/bin/competition "$@"
      '';
    in
    {
      overlays = [ (import ./overlays.nix) ];

      languages.elm.enable = true;

      languages.haskell.enable = true;
      languages.haskell.package = pkgs.haskell.packages.ghc96.ghc;
      languages.haskell.lsp.enable = false;
      languages.haskell.stack.enable = false;

      dotenv.disableHint = true;

      env.NODE_PATH = "${npmTools}/lib/node_modules";
      env.KEYCLOAK_ISSUER_URL = "http://127.0.0.1:8081/realms/competitions";
      env.KEYCLOAK_CLIENT_ID = "competitions";
      env.KEYCLOAK_CLIENT_SECRET = "competitions-dev-secret";
      env.KEYCLOAK_PROVIDER_NAME = "oidc";
      env.VITE_KEYCLOAK_PROVIDER_NAME = "oidc";
      env.COMPETITION_NIX = "${competitionCommand}/bin/competition-nix";

      packages = [
        competitionCommand
        npmTools
        pkgs.cabal-install
        pkgs.nodejs_22
        hpkgs.hlint
        hpkgs.fourmolu
      ];

      enterShell = ''
        ln -sfn "${npmTools}/lib/node_modules" node_modules
        ln -sfn "${npmTools}/lib/node_modules" elm-app/node_modules
      '';
    };

  shell =
    { pkgs, ... }:
    let
      npmTools = pkgs.callPackage ./pkgs/npm-tools.nix { };
    in
    {
      # Pin PocketBase to the production backend version. See overlays.nix.
      overlays = [ (import ./overlays.nix) ];

      languages.elm.enable = true;

      languages.haskell.enable = true;
      languages.haskell.package = pkgs.haskell.packages.ghc96.ghc;
      languages.haskell.lsp.enable = false;
      languages.haskell.stack.enable = false;

      dotenv.enable = true;

      env.NODE_PATH = "${npmTools}/lib/node_modules";

      packages = with pkgs; [
        caddy
        entr
        git
        go
        keycloak
        mailpit
        nodejs_22
        openssl
        pkg-config
        pocketbase
        treefmt
        zlib
        elmPackages.elm-review
        elmPackages.elm-json
        haskell.packages.ghc96.hlint
        haskell.packages.ghc96.fourmolu
        npmTools
      ];

      # ── PocketBase local instance ────────────────────────────────────────────────
      processes.pocketbase.exec = ''
        env GOFLAGS=-mod=mod PB_MIGRATIONS_DIR="$DEVENV_ROOT/pb_migrations" go run "$DEVENV_ROOT/cmd/competition-pocketbase" migrate up --dir="$DEVENV_ROOT/.devenv/state/pocketbase/data" &&
        env GOFLAGS=-mod=mod PB_MIGRATIONS_DIR="$DEVENV_ROOT/pb_migrations_dev" go run "$DEVENV_ROOT/cmd/competition-pocketbase" migrate up --dir="$DEVENV_ROOT/.devenv/state/pocketbase/data" &&
        env GOFLAGS=-mod=mod PB_MIGRATIONS_DIR="$DEVENV_ROOT/pb_migrations" PB_HOOKS_DIR="$DEVENV_ROOT/pb_hooks" go run "$DEVENV_ROOT/cmd/competition-pocketbase" serve \
          --dir="$DEVENV_ROOT/.devenv/state/pocketbase/data" \
          --http=127.0.0.1:8090 \
          --dev
      '';

      # ── Keycloak local OIDC fixture ─────────────────────────────────────────────
      processes.keycloak.exec = ''
        export KC_BOOTSTRAP_ADMIN_USERNAME=admin
        export KC_BOOTSTRAP_ADMIN_PASSWORD=admin
        export KEYCLOAK_ADMIN=admin
        export KEYCLOAK_ADMIN_PASSWORD=admin
        mkdir -p "$DEVENV_ROOT/.devenv/state/keycloak"
        keycloak import \
          --file "$DEVENV_ROOT/keycloak/competitions-realm.json" \
          --override true \
          --db=dev-file \
          --db-url="jdbc:h2:file:$DEVENV_ROOT/.devenv/state/keycloak/keycloakdb" || true
        keycloak start-dev \
          --http-host=127.0.0.1 \
          --http-port=8081 \
          --db=dev-file \
          --db-url="jdbc:h2:file:$DEVENV_ROOT/.devenv/state/keycloak/keycloakdb" \
          --features=scripts \
          --hostname-strict=false
      '';

      # ── Elm / Vite dev server ────────────────────────────────────────────────────
      processes.elm-dev.exec =
        "cd elm-app && vite --host 0.0.0.0";

      # ── Mailpit (local SMTP + web UI) ────────────────────────────────────────────
      processes.mailpit.exec =
        "mailpit --smtp 127.0.0.1:1025 --listen 127.0.0.1:8025";

      # ── Caddy reverse proxy ──────────────────────────────────────────────────────
      processes.caddy.exec =
        "caddy run --config ./Caddyfile --adapter caddyfile";

      enterShell = ''
        ln -sfn "${npmTools}/lib/node_modules" node_modules
        ln -sfn "${npmTools}/lib/node_modules" elm-app/node_modules

        echo ""
        echo "── competitions dev environment ─────────────────────"
        echo "  GHC:    $(ghc --version)"
        echo "  Cabal:  $(cabal --version | head -1)"
        echo "  Elm:    $(elm --version)"
        echo "  Node:   $(node --version)"
        echo "  Vite:   $(vite --version)"
        echo ""
        echo "  make gallery-run        — build gallery (requires devenv up)"
        echo "  make test               — run Haskell tests"
        echo "  make elm-test           — run Elm tests"
        echo "  devenv up               — start all services"
        echo "    App:              http://127.0.0.1:8080/"
        echo "    PocketBase admin: http://127.0.0.1:8080/_/"
        echo "    Mailpit UI:       http://127.0.0.1:8080/mailpit/"
        echo "    Keycloak:         http://127.0.0.1:8081/"
        echo ""
        echo "  Copy .env.example → .env and fill in POCKETBASE_API_KEY"
        echo ""
      '';
    };
in
{
  profiles.shell.module = {
    imports = [ shell ];
  };

  profiles.ci.module = {
    imports = [ ci ];
  };
}
