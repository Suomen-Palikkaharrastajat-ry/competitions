let
  ci =
    { pkgs, ... }:
    let
      hpkgs = pkgs.haskell.packages.ghc96.override {
        overrides = import ./overrides.nix { inherit pkgs; };
      };
      npmTools = pkgs.callPackage ./pkgs/npm-tools.nix { };
      competitionPackage = hpkgs.callCabal2nix "competition" ./statics { };
      competitionCommand = pkgs.writeShellScriptBin "competition-nix" ''
        exec ${competitionPackage}/bin/competition "$@"
      '';
    in
    {
      languages.elm.enable = true;

      languages.haskell.enable = true;
      languages.haskell.package = pkgs.haskell.packages.ghc96.ghc;
      languages.haskell.lsp.enable = false;
      languages.haskell.stack.enable = false;

      dotenv.disableHint = true;

      env.NODE_PATH = "${npmTools}/lib/node_modules";
      env.KEYCLOAK_ISSUER_URL = "http://127.0.0.1:8080/auth/realms/competitions";
      env.KEYCLOAK_CLIENT_ID = "competitions";
      env.KEYCLOAK_CLIENT_SECRET = "competitions-dev-secret";
      env.KEYCLOAK_PROVIDER_NAME = "oidc";
      env.VITE_KEYCLOAK_PROVIDER_NAME = "oidc";
      env.COMPETITION_NIX = "${competitionCommand}/bin/competition-nix";

      packages = [
        competitionCommand
        npmTools
        pkgs.cabal-install
        pkgs.caddy
        pkgs.elmPackages.elm-review
        pkgs.go
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
      env.KEYCLOAK_ISSUER_URL = "http://127.0.0.1:8080/auth/realms/competitions";
      env.KEYCLOAK_CLIENT_ID = "competitions";
      env.KEYCLOAK_CLIENT_SECRET = "competitions-dev-secret";
      env.KEYCLOAK_PROVIDER_NAME = "oidc";
      env.VITE_KEYCLOAK_PROVIDER_NAME = "oidc";

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
          --http=0.0.0.0:8090 \
          --dev
      '';

      # ── Keycloak local OIDC fixture ─────────────────────────────────────────────
      services.keycloak.enable = true;
      services.keycloak.initialAdminPassword = "admin";
      services.keycloak.database.type = "dev-mem";
      services.keycloak.realms.competitions = {
        path = "./keycloak/competitions-realm.json";
        import = true;
        export = false;
      };
      services.keycloak.settings = {
        http-enabled = true;
        http-host = "0.0.0.0";
        http-port = 8081;
        http-relative-path = "/auth";
        hostname = "http://127.0.0.1:8080/auth";
        hostname-strict = false;
        proxy-headers = "xforwarded";
        features = "scripts";
      };

      # ── Elm / Vite dev server ────────────────────────────────────────────────────
      processes.elm-dev.exec =
        "cd elm-app && vite --host 0.0.0.0";

      # ── Mailpit (local SMTP + web UI) ────────────────────────────────────────────
      processes.mailpit.exec =
        "mailpit --smtp 0.0.0.0:1025 --listen 0.0.0.0:8025 --webroot /mailpit";

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
        echo "    Keycloak:         http://127.0.0.1:8080/auth/"
        echo "    Mailpit UI:       http://127.0.0.1:8080/mailpit/"
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
