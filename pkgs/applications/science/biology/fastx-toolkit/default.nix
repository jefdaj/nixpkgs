{ stdenv, fetchFromGitHub, pkgconfig, libgtextutils }:

stdenv.mkDerivation rec {
  name = "fastx-toolkit-${version}";
  version = "0.0.14";
  src = fetchFromGitHub {
    owner = "agordon";
    repo = "fastx_toolkit";
    rev = "ea0ca83ba24dce80c20ca589b838a281fe5deb0c";
    sha256 = "07zmdvp8m9035hz29chc1mhgdsgkd7n7nndfg8pzrph78hhq04gv";
  };
  buildInputs = [ pkgconfig libgtextutils ];
#   buildPhase = ''
#     ./reconf
#     ./configure
#     make
#   '';
}
