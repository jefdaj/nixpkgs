{ stdenv, fetchurl }:

stdenv.mkDerivation rec {
  name = "t-coffee-${version}";
  version = "11.00.8cbe486";
  src = fetchurl {
    url = "http://www.tcoffee.org/Packages/Stable/Latest/T-COFFEE_distribution_Version_${version}.tar.gz";
    sha256 = "0b77g1vjwgzmnjgam2p3qn5ynj3an3mlp5yd95f71xsgawrq80dq";
  };
  builder = ./builder.sh;
}
