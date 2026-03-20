{
  pkgs,
  inputs,
  ...
}:

let
  stable = import inputs.nixpkgs-stable {
    system = pkgs.stdenv.hostPlatform.system;
    config = {
      allowUnfree = true;
    };
  };

  # Override the GHC 9.6 package set to add htoml-megaparsec, which is
  # not in the standard nixpkgs Haskell package set.
  haskellPackages = stable.haskell.packages.ghc96.override {
    overrides = _self: _super: {
      htoml-megaparsec = _self.callHackageDirect {
        pkg = "htoml-megaparsec";
        ver = "2.1.0.5";
        sha256 = "sha256-9YLTZ2akIu5j2v2BHmT3Mc0fhnsk1CJPmu3CaTuJlXg=";
      } {};
    };
  };

  # GHC bundled with all project dependencies pre-compiled from nixpkgs.
  # This is the nixpkgs best practice: provide packages via nix so that
  # `cabal build` / `cabal test` can find them in GHC's global package db
  # without downloading or compiling anything from Hackage.
  ghcForProject = haskellPackages.ghcWithPackages (ps: with ps; [
    # Library build-depends (from competition.cabal)
    text bytestring directory filepath time containers
    unordered-containers htoml-megaparsec
    http-conduit http-client http-client-tls
    blaze-html blaze-markup tagsoup aeson http-types
    # Test-suite build-depends
    tasty tasty-hunit tasty-quickcheck
  ]);

  shell = { pkgs, ... }: {
    # https://devenv.sh/packages/
    packages = [
      pkgs.elm-land
      pkgs.elmPackages.elm
      pkgs.elmPackages.elm-format
      pkgs.elmPackages.elm-language-server
      pkgs.entr
      pkgs.git
      pkgs.nodejs
      pkgs.openssl
      pkgs.pkg-config
      pkgs.mailpit
      pkgs.pocketbase
      pkgs.treefmt
      pkgs.zlib
      stable.cabal-install
      stable.fourmolu
      stable.hlint
      stable.haskell.packages.ghc96.haskell-language-server
    ];

    # https://devenv.sh/languages/
    languages.haskell.enable = true;
    # Use ghcWithPackages so all project deps are pre-compiled by nix and
    # available in GHC's global package db — no Hackage downloads needed.
    languages.haskell.package = ghcForProject;
    languages.haskell.stack.enable = true;
    languages.haskell.languageServer = stable.haskell.packages.ghc96.haskell-language-server;
    languages.elm.enable = true;

    # ── PocketBase local instance ────────────────────────────────────────────────
    # Runs PocketBase as a devenv process (start with: devenv up).
    # Data dir: pb_data/   Admin UI: http://127.0.0.1:8090/_/
    # Migrations are applied automatically on every start from pb_migrations/.
    processes.pocketbase.exec =
      "pocketbase serve --dir=./pb_data --http=127.0.0.1:8090 --migrationsDir=./pb_migrations --dev";

    # ── Elm / Vite dev server ────────────────────────────────────────────────────
    # Runs the Elm app dev server at http://localhost:5173 (start with: devenv up).
    # --host 0.0.0.0 makes it reachable from the host machine in devcontainer.
    processes.elm-dev.exec =
      "cd elm-app && npm install --silent && npm run dev -- --host 0.0.0.0";

    # ── Mailpit (local SMTP + web UI) ────────────────────────────────────────────
    # SMTP server at 127.0.0.1:1025; web UI at http://127.0.0.1:8025
    # PocketBase is configured to send OTP emails via mailpit (run make pb-configure).
    processes.mailpit.exec =
      "mailpit --smtp 127.0.0.1:1025 --listen 127.0.0.1:8025";

    enterShell = ''
      git --version
      echo ""
      echo "=== Palikkakilpailu dev environment ==="
      echo "  devenv up           → start PocketBase (8090) + Elm dev server (5173) + Mailpit (8025)"
      echo "  make gallery-run    → generate static gallery (requires devenv up first)"
      echo "  make test           → run Haskell tests"
      echo "  cd elm-app && npm test → run Elm tests"
      echo ""
      echo "  Copy .env.example → .env and fill in POCKETBASE_API_KEY"
      echo "  PocketBase admin UI: http://127.0.0.1:8090/_/"
      echo ""
    '';

    # Load POCKETBASE_URL and POCKETBASE_API_KEY from .env automatically.
    dotenv.enable = true;
  };
in
{
  profiles.shell.module = {
    imports = [ shell ];
  };
}
