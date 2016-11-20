{ stdenv, fetchurl }:

stdenv.mkDerivation {
  name = "argtable-2.13";
  src = fetchurl {
    url = "http://prdownloads.sourceforge.net/argtable/argtable2-13.tar.gz";
    sha256 = "1gyxf4bh9jp5gb3l6g5qy90zzcf3vcpk0irgwbv1lc6mrskyhxwg";
  };
}
