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
    languages.haskell.package = stable.haskell.compiler.ghc96;
    languages.haskell.stack.enable = true;
    languages.haskell.languageServer = stable.haskell.packages.ghc96.haskell-language-server;
    languages.elm.enable = true;

    # ── PocketBase local instance ────────────────────────────────────────────────
    # Runs PocketBase as a devenv process (start with: devenv up).
    # Data dir: pb_data/   Admin UI: http://127.0.0.1:8090/_/
    # Migrations are applied automatically on every start from pb_migrations/.
    processes.pocketbase.exec =
      "pocketbase serve --dir=./pb_data --http=127.0.0.1:8090 --migrationsDir=./pb_migrations";

    enterShell = ''
      git --version
      stack --version
      echo "PocketBase: run 'devenv up' to start the local instance at http://127.0.0.1:8090"
      echo "  Set POCKETBASE_URL and POCKETBASE_API_KEY in .env (copy from .env.example)"
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
