{ stdenv, fetchurl, which, xorg }:

stdenv.mkDerivation rec {
  name    = "tclkit-${version}";
  version = "8.6.4";

  tcl_tag    = "tip_412";
  tk_tag     = "core_8_6_4";
  kit_commit = "c21eeb1e379bd5acb5b304f0784877b8e8dd31ca";

  tcl_src = fetchurl {
    url = "https://github.com/tcltk/tk/archive/${tk_tag}.tar.gz";
    sha256 = "0phbhasmgd31kyhlyjc6syisd5f2hhcjm61lgpr6v2px2cqng6zd";
  };

  tk_src = fetchurl {
    url = "https://github.com/tcltk/tcl/archive/${tcl_tag}.tar.gz";
    sha256 = "1nsjdrskf1vz9vvngpf5gcwbfv8667vmmglsjqp43gab8r0c5330";
  };

  kit_src = fetchurl {
    url = "https://github.com/patthoyts/kitgen/archive/${kit_commit}.tar.gz";
    sha256 = "0zz3xjb2cv64s578vhmjjilxlr8r6xqnnl7c0pvyx4z7inh3wd2c";
  };

  buildInputs = [ xorg.libX11 which ];
  builder = ./builder.sh;
}
