# Based on nixpkgs/pkgs/applications/networking/cluster/mesos
# TODO is the proxy stuff needed?

{ stdenv, curl }:

stdenv.mkDerivation {
  name = "tarql-deps";
  builder = ./build-deps.sh;

  outputHashAlgo = "sha256";
  outputHashMode = "recursive";
  outputHash = "1ymb8k8z71dlkq828fq0n55ks2ap2sbsymsmj6ig9v7s7ccjcaxs";
  buildInputs = [ curl ];

  # We borrow these environment variables from the caller to allow
  # easy proxy configuration. This is impure, but a fixed-output
  # derivation like fetchurl is allowed to do so since its result is
  # by definition pure.
  impureEnvVars = ["http_proxy" "https_proxy" "ftp_proxy" "all_proxy" "no_proxy"];
}
