{ stdenv, fetchurl, jre, gzip, which }:

stdenv.mkDerivation rec {
  name = "dendroscope-${version}";
  version = "3.5.7";
  src = fetchurl {
    url = "http://ab.inf.uni-tuebingen.de/data/software/dendroscope3/download/Dendroscope_unix_3_5_7.sh";
    sha256 = "0six8936zhb2lcwwb89h2x0xjabylgkvmx2xwplq26z3bfahqy16";
  };
  buildInputs = [ jre gzip which ];
  inherit jre;
  builder = ./builder.sh;
}
