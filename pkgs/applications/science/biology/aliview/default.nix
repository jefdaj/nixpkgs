{ stdenv, fetchurl, jre }:

stdenv.mkDerivation rec {
  name = "aliview-${version}";
  version = "1.18";
  src = fetchurl {
    url = "http://www.ormbunkar.se/aliview/downloads/linux/linux-version-1.18/aliview.tgz";
    sha256 = "1m7ign2wb62fn4hmi4ywnkzdpjifl6jz83l27i40nby7cyyym9cj";
  };
  inherit jre;
  builder = ./builder.sh;
}
