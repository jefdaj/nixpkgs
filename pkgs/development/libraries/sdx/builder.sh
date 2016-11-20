#!/usr/bin/env bash

source $stdenv/setup
mkdir -p $out/bin
install -m755 $src $out/bin/sdx.kit
chmod ugo+x $out/bin/sdx.kit
wrapProgram $out/bin/sdx.kit --prefix PATH : ${tclkit}/bin
 
