{stdenv, jre, jdk, ant, fetchurl, unzip }:

# TODO include this in igv package, or keep separate?

stdenv.mkDerivation rec {
  version = "2.4.19";
  name = "igvtools-${version}";

  src = fetchurl {
    url = "http://www.broadinstitute.org/igv/projects/downloads/igvtools_${version}.zip";
    sha256 = "1j2pk6m3rfn3b7fjs8aaq0xa1d2nrri1jvx4kmmh5ybf97g1sdbv";
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
