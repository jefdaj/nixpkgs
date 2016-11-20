#!/usr/bin/env bash

source $stdenv/setup

# extract tarball (not sure why automatic extraction fails)
tar -zxf $src

# create directories
install -d -m755 $out/bin/
install -d -m755 $out/share/aliview/
install -d -m755 $out/share/applications/

# install our own wrapper script instead of the upstream one
cat << EOF > wrapper
$jre/bin/java -Xmx1024M -Xms512M -jar $out/share/aliview/aliview.jar \${1+"\$@"}
EOF
install -m755 wrapper $out/bin/aliview

# install supporting files
install -v -m755 aliview.jar         $out/share/aliview/
install -v -m755 aliicon_128x128.png $out/share/aliview/
install -v -m755 AliView.desktop     $out/share/applications/
