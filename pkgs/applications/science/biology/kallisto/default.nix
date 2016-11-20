{ stdenv, fetchurl, cmake, hdf5-cpp, zlib }:

stdenv.mkDerivation rec {
  name = "kallisto-${version}";
  version = "0.43.0";
  src = fetchurl {
    url = "https://github.com/pachterlab/kallisto/archive/v${version}.tar.gz";
    sha256 = "1d9cqf3lz6mm9kmqn47d99c6byn6q9l4ppgcafxrhcnrb2davhv9";
  };
  buildInputs = [ cmake hdf5-cpp zlib ];
}
