{ stdenv, fetchurl, which, xorg }:

stdenv.mkDerivation rec {
  name    = "tclkit-${version}";
  version = "8.6.4";

  tk_tag     = "core_8_6_4";
  tcl_tag    = "tip-412";
  kit_commit = "c21eeb1e379bd5acb5b304f0784877b8e8dd31ca";

  tk_src = fetchurl {
    url = "https://github.com/tcltk/tk/archive/${tk_tag}.tar.gz";
    sha256 = "14r01k5pncgq28zwgy6gd69pghzsw43vzgzpgy38y5f434x2wznn";
  };

  tcl_src = fetchurl {
    url = "https://github.com/tcltk/tcl/archive/${tcl_tag}.tar.gz";
    sha256 = "1s9xaxbqlpjjj847chlxp7zh295v8rk94p6qal72z7a21kj10ly9";
  };

  kit_src = fetchurl {
    url = "https://github.com/patthoyts/kitgen/archive/${kit_commit}.tar.gz";
    sha256 = "0zz3xjb2cv64s578vhmjjilxlr8r6xqnnl7c0pvyx4z7inh3wd2c";
  };

  buildInputs = [ xorg.libX11 which ];
  builder = ./builder.sh;
}
