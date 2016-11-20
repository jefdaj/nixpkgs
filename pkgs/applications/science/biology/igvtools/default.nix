{stdenv, jre, jdk, ant, fetchurl, unzip }:

# TODO include this in igv package, or keep separate?

stdenv.mkDerivation rec {
  version = "2.3.88";
  name = "igvtools-${version}";

  src = fetchurl {
    url = "http://www.broadinstitute.org/igv/projects/downloads/igvtools_${version}.zip";
    sha256 = "00awg17vaih3jn944npk4hfd6v6jmagiysc76lp5xnnqb9vjnn7z";
  };

  buildInputs = [ jdk ant unzip ];

  phases = [ "unpackPhase" "installPhase" ];

  inherit jre;
  installPhase = ''
    mkdir -p $out/{bin,lib}

    sed -i 's/--gui/gui/g' igvtools_gui # fix bug in launcher script
    cp -R * $out/lib

    cat << EOF > $out/bin/igvtools
    #!/usr/bin/env bash
    PATH=$jre/bin:\$PATH $out/lib/igvtools \$@
    EOF
    cat << EOF > $out/bin/igvtools_gui
    #!/usr/bin/env bash
    PATH=$jre/bin:\$PATH $out/lib/igvtools_gui \$@
    EOF

    chmod +x $out/bin/igvtools*
'';
}
