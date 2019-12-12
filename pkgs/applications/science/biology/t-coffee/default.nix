{ stdenv, fetchurl }:

stdenv.mkDerivation rec {
  name = "t-coffee-${version}";
  version = "13.41.0.28bdc39";
  src = fetchurl {
    url = "http://www.tcoffee.org/Packages/Archives/T-COFFEE_distribution_Version_${version}.tar.gz";
    sha256 = "0hbhb3145hbviwy6gm077psw92yhjyx46m5hbngb0gvjhr7ya6q8";
  };
  builder = ./builder.sh;
}
