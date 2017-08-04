{ stdenv, fetchurl, fetchpatch, pkgconfig, zlib, libjpeg, xz }:

let
  version = "4.0.8";
in
stdenv.mkDerivation rec {
  name = "libtiff-${version}";

  src = fetchurl {
    url = "http://download.osgeo.org/libtiff/tiff-${version}.tar.gz";
    sha256 = "0419mh6kkhz5fkyl77gv0in8x4d2jpdpfs147y8mj86rrjlabmsr";
  };

  prePatch =let
      debian = fetchurl {
        url = http://http.debian.net/debian/pool/main/t/tiff/tiff_4.0.8-4.debian.tar.xz;
        sha256 = "172xsyj9xx8s1v5fdi72anzj89h85kw7bkczrmc6k3g0k8bhih1n";
      };
    in ''
      tar xf '${debian}'
      patches="$patches $(cat debian/patches/series | sed 's|^|debian/patches/|')"
    '';

  outputs = [ "bin" "dev" "out" "doc" ];

  nativeBuildInputs = [ pkgconfig ];

  propagatedBuildInputs = [ zlib libjpeg xz ]; #TODO: opengl support (bogus configure detection)

  enableParallelBuilding = true;

  doCheck = true;

  meta = with stdenv.lib; {
    description = "Library and utilities for working with the TIFF image file format";
    homepage = http://download.osgeo.org/libtiff;
    license = licenses.libtiff;
    platforms = platforms.unix;
  };
}
