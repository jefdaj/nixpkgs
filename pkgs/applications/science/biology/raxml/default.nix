{ stdenv, fetchgit, clang, mpich2 }:

# TODO: metadata (description, license etc.)

stdenv.mkDerivation rec {
  name = "raxml-${version}";
  version = "8.2.9";
  src = fetchgit {
    url = "https://github.com/stamatak/standard-RAxML.git";
    rev = "4881d835222f3dcc3faec5f14d5681cb97de97c5";
    sha256 = "1bv12bzx7nqkhxp4wdfgl6wg4lx95j7vsg9mcj87b0hkr5zl9p2l";
  };
  buildInputs = [ clang mpich2 ];
  buildPhase = ''
    for makefile in Makefile.*; do
      make -f $makefile
    done
  '';
  installPhase = ''
    mkdir -p  $out/bin
    cp raxml* $out/bin
    chmod +x  $out/bin/*
  '';
}
