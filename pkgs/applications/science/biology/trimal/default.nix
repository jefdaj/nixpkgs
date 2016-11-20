{ stdenv, fetchgit }:

# TODO add viennarna dependency?

stdenv.mkDerivation rec {
  name = "trimal-${version}";
  version = "1.4";
  src = fetchgit {
    url = "https://github.com/scapella/trimal.git";
    rev = "f7b4a27747af5e95427c8c3f0f3b725029c7bdae";
    sha256 = "0isc7s3514di4z953xq53ncjkbi650sh4q9yyw5aag1n9hqnh7k0";
  };
  builder = ./builder.sh;
}
