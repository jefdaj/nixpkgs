# This file was generated by go2nix.
{ lib, buildGoPackage, fetchgit }:

buildGoPackage rec {
  name = "gcsfuse-${version}";
  version = "0.23.0";
  rev = "v${version}";

  goPackagePath = "github.com/googlecloudplatform/gcsfuse";

  src = fetchgit {
    inherit rev;
    url = "https://github.com/googlecloudplatform/gcsfuse";
    sha256 = "1qxbpsmz22l5w4b7wbgfdq4v85cfc9ka9i8h4c56nals1x5lcsnx";
  };

  meta = {
    license = lib.licenses.asl20;
    platforms = lib.platforms.linux;
    maintainers = [];
    homepage = https://cloud.google.com/storage/docs/gcs-fuse;
    description =
      "A user-space file system for interacting with Google Cloud Storage";
  };
}
