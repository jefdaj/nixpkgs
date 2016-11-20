{ stdenv, curl, fetchgit, jdk, maven }:

stdenv.mkDerivation rec {
  inherit stdenv maven jdk;
  version = "2015-01-23";
  name = "tarql-${version}";
  src = fetchgit {
    url = "https://github.com/tarql/tarql.git";
    rev = "6f97f9c578774e941704d8e5182d476e0f4d0537";
    sha256 = "f095fcfcffdec80e8ab7cabe611096d6b83e06fed07ce5f7f4b84f32ba569c0b";
  };
  mavenRepo = import ./deps.nix { inherit stdenv curl; };
  buildInputs = [ jdk maven ];
  builder = ./build-default.sh;
  meta = {
    homePage = "http://tarql.github.io/";
    description = ''SPARQL for Tables: Turn CSV into RDF using SPARQL syntax'';
    longDescription = ''
      Tarql is a command-line tool for converting CSV files to RDF using SPARQL
      1.1 syntax. It's written in Java and based on Apache ARQ.
    '';
  };
}
