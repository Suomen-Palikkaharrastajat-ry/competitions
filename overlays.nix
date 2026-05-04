# Pin PocketBase to the production backend version.
# Override is needed because nixpkgs/master tracks the latest release.
# When upgrading PocketBase, update this version and both fixed-output hashes
# together, then smoke-test pb_migrations/ and pb_migrations_dev/.
final: prev: {
  pocketbase = prev.pocketbase.overrideAttrs (
    finalAttrs: old: {
      version = "0.37.5";
      src = final.fetchFromGitHub {
        owner = "pocketbase";
        repo = "pocketbase";
        rev = "v${finalAttrs.version}";
        hash = "sha256-z5brZQEblcPkNNg6kNDw9C/3CwUCdMF/TPcOIFaPoKI=";
      };
      vendorHash = "sha256-8YtDQLeStdUb6HXX/KEifDHiX//9cH7XCBu2LtHrCQM=";
    }
  );
}
