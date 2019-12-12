{ stdenv, fetchurl, jre }:

# TODO switch to source build if possible... how does that work in Java?
# ah! see https://nixos.org/nixpkgs/manual/#sec-language-java
#     and https://github.com/rambaut/figtree

# TODO fix "Error: Unable to access jarfile lib/figtree.jar"

stdenv.mkDerivation rec {
  name = "figtree-${version}";
  version = "1.4.4";
  src = fetchurl {
    url = "https://github.com/rambaut/figtree/releases/download/v${version}/FigTree_v${version}.tgz";
    sha256 = "1a1s8805hf7j5n9r2fx6i3a17mvblzk63lqwz2f3d7mjaxv8d6sj";
  };
  buildInputs = [ jre ]; # TODO and makeWrapper?
  inherit jre;
  builder = ./builder.sh;
}
