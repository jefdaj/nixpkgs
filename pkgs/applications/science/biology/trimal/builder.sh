#!/usr/bin/env bash

source $stdenv/setup

# build binaries
cp -R $src/source ./
chmod +w source
cd source
make

# install binaries
mkdir -p $out/bin
cp *al $out/bin
