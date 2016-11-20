{ stdenv, fetchurl }:

stdenv.mkDerivation rec {
  name = "gblocks-${version}";
  version = "0.91b";
  src = fetchurl {
    url = "http://molevol.cmima.csic.es/castresana/Gblocks/Gblocks_Linux64_${version}.tar.Z";
    sha256 = "1p40r034rydmfb0s1lqkr3zdx64k2kf5nw5am0s65ry57kq5hdjn";
  };
  installPhase = ''
    mkdir -p $out/{src,bin}
    cp -r * $out/src
    mv $out/src/Gblocks $out/bin
    patchelf --set-interpreter \
      ${stdenv.glibc}/lib/ld-linux-x86-64.so.2 \
      $out/bin/Gblocks
  '';
}
