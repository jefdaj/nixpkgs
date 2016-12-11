{ stdenv, fetchurl, pkgconfig, libgtextutils }:

stdenv.mkDerivation {
  name = "fastx-toolkit-0.14";
  src = fetchurl {
    url = "https://github.com/agordon/fastx_toolkit/releases/download/0.0.14/fastx_toolkit-0.0.14.tar.bz2";
    sha256 = "01jqzw386873sr0pjp1wr4rn8fsga2vxs1qfmicvx1pjr72007wy";
  };
  buildInputs = [ pkgconfig libgtextutils ];
}
