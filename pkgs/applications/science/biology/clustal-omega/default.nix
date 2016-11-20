{ stdenv, fetchurl, argtable2 }:

stdenv.mkDerivation {
  name = "clustal-omega-1.2.1";
  src = fetchurl {
    url = "http://www.clustal.org/omega/clustal-omega-1.2.1.tar.gz";
    sha256 = "02ibkx0m0iwz8nscg998bh41gg251y56cgh86bvyrii5m8kjgwqf";
  };
  buildInputs = [ argtable2 ];
}
