#!/usr/bin/env bash

source $stdenv/setup

# This was adapted from: https://aur.archlinux.org/packages/tclkit
# TODO can the system tk, tcl be used instead?

# extract source files
tar -zxf $tcl_src
tar -zxf $tk_src
tar -zxf $kit_src

# rearrange source files
mv kitgen-${kit_commit} kitgen
mkdir -p kitgen/8.6
mv tk-${tk_tag}   kitgen/8.6/tk
mv tcl-${tcl_tag} kitgen/8.6/tcl

# compile binaries
cd kitgen
export options="thread allenc cli dyn"
if [[ $system == 'x86_64-linux' ]]; then
  export B64=b64
fi
./config.sh 8.6/kit-large thread allenc cli dyn $B64
cd 8.6/kit-large
make

# install binaries
mkdir -p $out/bin
install -m755 kit-*    $out/bin/.
install -m755 tclkit-* $out/bin/.
cd $out/bin
ln -s tclkit-cli tclkit
