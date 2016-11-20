#!/usr/bin/env bash

source $stdenv/setup

tar xf $src
cp -r FigTree_v${version} $out
chmod +x $out/bin/figtree

# wrapProgram $out/bin/figtree \
