#!/usr/bin/env bash

# Usage: ./update-r-packages.sh

# It'll edit the package lists and default.nix,
# and also leave a lot of build_*.log files from failed builds in the working dir.
# You can delete those or look through them for clues.

# update package lists
for prefix in bioc bioc-annotation bioc-experiment cran irkernel; do
  echo "Downloading updates to ${prefix}-packages.nix..."
  Rscript generate-r-packages.R ${prefix} >new && mv new ${prefix}-packages.nix
done

# check for newly un-broken packages
update_package() {
  pkg="$1"
  logfile="build_${pkg}.log"
  [[ -a $logfile ]] && return
  nix-build --arg config '{ allowBroken = true; allowUnfree = true; }' '<nixpkgs>' -A "rPackages.${pkg}" 2>&1 &> $logfile
  [[ $? == 0 ]] || return
  rm build_${pkg}.log
  sed -i "/\"$pkg\" # broken build/d"          default.nix
  sed -i "/\"$pkg\" # build is broken/d"       default.nix
  sed -i "/\"$pkg\" # Build Is Broken/d"       default.nix
  sed -i "/# depends on broken package $pkg/d" default.nix
  echo "${pkg} builds! Updated default.nix"
}
echo "Checking for newly un-broken packages..."
export -f update_package
grep -E '" # (broken build|[Bb]uild [Ii]s [Bb]roken)' default.nix | cut -d'"' -f2 | while read pkg; do
  sem --no-notice update_package $pkg
done

# TODO: check for newly broken packages

# TODO: look through build logs to see what obvious fixes can be added (but commit first)
# TODO: fix 'should have sha256' errors
# TODO: fix Octave_map errors
# TODO: fix dependencies: BiGGr -> libsbml
