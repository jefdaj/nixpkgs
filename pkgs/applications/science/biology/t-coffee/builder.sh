#!/usr/bin/env bash

source $stdenv/setup

# build
tar -xf $src
cd T-COFFEE_distribution_Version_*/t_coffee_source
make

# install
mkdir -p $out/bin
cp t_coffee $out/bin
