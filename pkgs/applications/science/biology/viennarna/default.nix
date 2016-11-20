{ stdenv, fetchurl, perl, python }:

stdenv.mkDerivation rec {
  name = "viennarna-${version}";
  version = "2.3.1";
  src = fetchurl {
    url = "https://www.tbi.univie.ac.at/RNA/download/sourcecode/2_3_x/ViennaRNA-2.3.1.tar.gz";
    sha256 = "17dzniy6s91fx985j4xz5i6gbd0ywjc03yggw8mnhr343dby2yps";
  };
  buildInputs = [ perl python ];
}
