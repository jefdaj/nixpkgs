{ stdenv, fetchurl, tclkit, makeWrapper }:

stdenv.mkDerivation {
  name = "sdx"; # TODO .kit?
  src = fetchurl {
    url = "http://equi4.com/pub/sk/sdx.kit";
    sha256 = "1ydxmy7swgraxm1x2dxiyfjkwbgyfwgn97s0nsrvb7mwww3v1m0i";
  };
  # TODO package tclkit
  # TODO substitute tclkit path into sdx.kit?
  inherit tclkit;
  buildInputs = [ makeWrapper ];
  builder = ./builder.sh;
}
