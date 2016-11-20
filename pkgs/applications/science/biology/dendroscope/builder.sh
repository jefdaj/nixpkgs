#!/usr/bin/env bash

source $stdenv/setup

# the source is a shell script with bundled data; run it
mkdir -p $out/lib
cp $src install.sh
chmod +x install.sh
./install.sh -q -dir $out/lib

# install a wrapper around the upstream wrapper script
mkdir -p $out/bin
cat << EOF > $out/bin/dendroscope
export INSTALL4J_JAVA_PREFIX=${jre}
$out/lib/Dendroscope \$@
EOF
chmod +x $out/bin/dendroscope
