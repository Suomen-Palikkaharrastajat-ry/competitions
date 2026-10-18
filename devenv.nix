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
      # Pin PocketBase to the production backend version. See overlays.nix.
      overlays = [ (import ./overlays.nix) ];

      languages.elm.enable = true;

      languages.haskell.enable = true;
      languages.haskell.package = pkgs.haskell.packages.ghc96.ghc;
      languages.haskell.lsp.enable = false;
      languages.haskell.stack.enable = false;

      dotenv.disableHint = true;

      env.NODE_PATH = "${npmTools}/lib/node_modules";
      env.KEYCLOAK_ISSUER_URL = "http://localhost:8080/auth/realms/competitions";
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
        pkgs.mailpit
        pkgs.nodejs_22
        pkgs.pocketbase
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
      env.KEYCLOAK_ISSUER_URL = "http://localhost:8080/auth/realms/competitions";
      env.KEYCLOAK_CLIENT_ID = "competitions";
      env.KEYCLOAK_CLIENT_SECRET = "competitions-dev-secret";
      env.KEYCLOAK_PROVIDER_NAME = "oidc";
      env.VITE_KEYCLOAK_PROVIDER_NAME = "oidc";

      packages = with pkgs; [
        caddy
        entr
        git
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
        curl
      ];

      # ── PocketBase local instance ────────────────────────────────────────────────
      processes.pocketbase.ready.exec = "curl -fsS http://127.0.0.1:8090/api/health";
      processes.pocketbase.ready.initial_delay = 60;
      processes.pocketbase.ready.period = 3;
      processes.pocketbase.exec = ''
        pocketbase migrate up --dir="$DEVENV_ROOT/.devenv/state/pocketbase/data" --migrationsDir="$DEVENV_ROOT/pb_migrations" &&
        pocketbase migrate up --dir="$DEVENV_ROOT/.devenv/state/pocketbase/data" --migrationsDir="$DEVENV_ROOT/pb_migrations_dev" &&
        pocketbase serve \
          --dir="$DEVENV_ROOT/.devenv/state/pocketbase/data" \
          --migrationsDir="$DEVENV_ROOT/pb_migrations" \
          --hooksDir="$DEVENV_ROOT/pb_hooks" \
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
        hostname = "http://localhost:8080/auth";
        hostname-strict = false;
        proxy-headers = "xforwarded";
        features = "scripts";
      };

      # ── Elm / Vite dev server ────────────────────────────────────────────────────
      processes.elm-dev.ready.exec = "curl -fsS http://127.0.0.1:5173/";
      processes.elm-dev.ready.initial_delay = 5;
      processes.elm-dev.exec =
        "cd elm-app && vite --host 0.0.0.0";

      # ── Mailpit (local SMTP + web UI) ────────────────────────────────────────────
      # Ready when the web UI (served under /mailpit, see --webroot) and the SMTP port both accept connections.
      processes.mailpit.ready.exec = "curl -fsS http://127.0.0.1:8025/mailpit/ > /dev/null && bash -c 'exec 3<>/dev/tcp/127.0.0.1/1025'";
      processes.mailpit.ready.period = 2;
      processes.mailpit.exec =
        "mailpit --smtp 0.0.0.0:1025 --listen 0.0.0.0:8025 --webroot /mailpit";

      # ── Caddy reverse proxy ──────────────────────────────────────────────────────
      # Ready once Caddy accepts connections on 8080. Upstream 502s are expected while
      # the other services are still starting, so only a connection failure counts as not ready.
      processes.caddy.ready.exec = "curl -s -o /dev/null -w '%{http_code}' http://localhost:8080/ | grep -qv '^000$'";
      processes.caddy.ready.period = 2;
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
        echo "    App:              http://localhost:8080/"
        echo "    PocketBase admin: http://localhost:8080/_/"
        echo "    Keycloak:         http://localhost:8080/auth/"
        echo "    Mailpit UI:       http://localhost:8080/mailpit/"
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
