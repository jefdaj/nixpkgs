{ stdenv, fetchurl, jre }:

# TODO switch to source build if possible... how does that work in Java?
# ah! see https://nixos.org/nixpkgs/manual/#sec-language-java
#     and https://github.com/rambaut/figtree

# TODO fix "Error: Unable to access jarfile lib/figtree.jar"

stdenv.mkDerivation rec {
  name = "figtree-${version}";
  version = "1.4.2";
  src = fetchurl {
    url = "http://tree.bio.ed.ac.uk/download.php?id=90&num=3";
    name = "FigTree_v1.4.2.tgz"; # required since url has invalid characters
    sha256 = "15m0w56132m1k3788r4m24drflgnqgwarzgqn336kw4cpsgm0r2h";
  };
  buildInputs = [ jre ]; # TODO and makeWrapper?
  inherit jre;
  builder = ./builder.sh;
}
