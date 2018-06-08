# TODO figure out how it picks up the Accessory + config files
# if nothing else, could directly patch AppMain.tcl:
# set accdir [file join [file dirname $argv0] "Accessory Files"]
# also see:
# https://aboutfoto.wordpress.com/2015/01/19/ape-a-plasmid-editor-installation-on-linux-debian/

{ stdenv, fetchurl, sdx, unzip, tk }:

stdenv.mkDerivation rec {
  homepage = "http://biologylabs.utah.edu/jorgensen/wayned/ape";
  # version = "2.0.49";
  version = "2.0.55";
  name = "ape-${version}";
  src = fetchurl {
    url = "${homepage}/Download/Windows/ApE_win_current.zip";
    # sha256 = "0phbhasmgd31kyhlyjc6syisd5f2hhcjm61lgpr6v2px2cqng6zd";
    # sha256 = "0kqhixz62b9psmk6pp90n2v1qn2n26f2y0s7xx8a8xyrdwm2bins";
    sha256 = "1nhcc1j12ap4sq20183a3wwvzgbjfcmnmjrmib4wk4sv5wv104nc";
  };
  inherit tk;
  buildInputs = [ sdx unzip ];
  builder = ./builder.sh;
  meta = {
    inherit homepage;
  };
}
