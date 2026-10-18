# Pin PocketBase to the production backend version.
# Production runs the stock prebuilt binary (`./pocketbase update`); this
# builds the same release from source, without a custom Go wrapper.
# Override is needed because nixpkgs lags behind the latest release.
# When upgrading PocketBase, update this version and both fixed-output hashes
# together, then smoke-test pb_migrations/ and pb_migrations_dev/.
final: prev: {
  # PocketBase 0.40 requires Go 1.27.
  pocketbase = (prev.pocketbase.override { buildGoModule = final.buildGoModule.override { go = final.go_1_27; }; }).overrideAttrs (
    finalAttrs: old: {
      version = "0.40.5";
      src = final.fetchFromGitHub {
        owner = "pocketbase";
        repo = "pocketbase";
        rev = "v${finalAttrs.version}";
        hash = "sha256-aAXQ+hH1cBkxsKIp9VuCfLq5IznGQlrBry73i9ET8vw=";
      };
      vendorHash = "sha256-FIt4pP0a6oJarquRfGeUiy+8qi8cstvzl/D14dD/Hdw=";
    }
  );
}
