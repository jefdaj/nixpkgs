{ stdenv, fetchFromGitHub, libtool, pkgconfig, automake, autoconf }:

stdenv.mkDerivation rec {
  name = "libgtextutils-0.7";
  version = "0.7";
  src = fetchFromGitHub {
    owner = "agordon";
    repo = "libgtextutils";
    rev = "510270ecf2e342a81d5dffbf38505bfe18d23dca";
    sha256 = "07zmdvp8m9035hz29chc1mhgdsgkd7n7nndfg8pzrph78hhq04gv";
  };
  buildInputs = [ libtool pkgconfig automake autoconf ];
  buildPhase = ''
    ./reconf
    ./configure
    make
  '';
}
