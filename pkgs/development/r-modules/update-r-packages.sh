#!/usr/bin/env bash

# Usage: ./update-r-packages.sh

# It edits the .nix files, so you want to make sure they're clean before
# starting and look through the diffs afterward. It also leaves a lot of
# build/*.log files, which you can delete or look through for clues.

# TODO: fix 'should have sha256' errors
# TODO: fix Octave_map errors
# TODO: fix dependencies: BiGGr -> libsbml
# TODO: don't need to build each package?
#       could fail dependencies of broken ones automatically

##################
# update metadata
##################

update_package_list() {
  prefix="$1"
  path="${prefix}-packages.nix"
  echo "Downloading updates to ${path}"
  Rscript generate-r-packages.R ${prefix} >new && mv new ${path}
  return $?
}

update_package_lists() {
  for prefix in bioc bioc-annotation bioc-experiment cran irkernel; do
    update_package_list "$prefix"
  done
}

###########################
# remove archived packages
###########################

list_attr_names() {
  expr="builtins.attrNames (import <nixpkgs> {}).rPackages"
  nix-instantiate --eval --expr "$expr" |  sed 's/\ /\n/g' |
    cut -d'"' -f2 | sort | uniq | tail -n+3 |
    grep -v override
}

list_grep_names() {
  grep '= derive' *-packages.nix |
    cut -d':' -f2 | cut -d' ' -f1 | sort | uniq
}

list_removed() {
  echo "Looking for removed packages"
  archived=$(comm -23 <(list_attr_names) <(list_grep_names))
  [[ -z "$archived" ]] && return 0
  echo "These packages have been removed upstream:"
  echo "$archived" | while read l; do echo "  $l"; done
  echo "They should be removed from default.nix too before continuing."
  exit 1
}

test_rpackages() {
  echo "Testing that rPackages evaluates properly"
  nix-env -f "<nixpkgs>" -qaP -A rPackages &> /dev/null
  if [[ $? != 0 ]]; then
    echo "Warning! rPackages failed to evaluate. Something went wrong. :("
  fi
}

##################
# test all builds
##################

mark_broken() {
  reason="broken build"
  pkg="$1"
  logfile="build/${pkg}.log"
  grep 'should have sha256'  $logfile > /dev/null && reason="hash mismatch"
  grep 'dependencies couldn' $logfile > /dev/null && reason="broken dependency"
  # TODO: make this into a generic "insert into list" function?
  sed -i "/brokenPackages = \\[$/a \ \ \ \ \"$pkg\" # $reason" default.nix
  echo "  added $pkg (${reason})"
}

mark_fixed() {
  sed -i "/\"$1\" # broken build/d"              default.nix
  sed -i "/\"$1\" # broken dependency/d"         default.nix
  sed -i "/\"$1\" # build is broken/d"           default.nix
  sed -i "/\"$1\" # Build Is Broken/d"           default.nix
  sed -i "/\"$1\" # depends on broken package/d" default.nix
  sed -i "/# depends on broken package $1/d"     default.nix
  echo "  removed $1"
}

test_build() {
  pkg="$1"
  logfile="build/${pkg}.log"
  [[ -d build ]] || mkdir build
  if [[ -a $logfile ]]; then
    echo "Skipping ${pkg} because ${logfile} exists"
    return -1
  fi
  nix-build '<nixpkgs>' \
    --arg config '{ allowBroken = true; allowUnfree = true; }' \
    -A "rPackages.${pkg}" 2>&1 &> $logfile
  code=$?
  [[ $code == 0 ]] && echo "${pkg} builds" || echo "${pkg} fails to build"
  return $code
}

confirm_broken() {
  test_build "$1" >/dev/null
  [[ $? ==  0 ]] && mark_fixed "$1"
}

confirm_builds() {
  test_build "$1" >/dev/null && echo "$1 still builds"
  [[ $? == 1 ]] && mark_broken "$1"
}

# make functions available to parallel
export -f test_build mark_broken mark_fixed confirm_broken confirm_builds

test_all_builds() {
  echo "Updating default.nix broken list. This will take a while!"
  list_attr_names | while read pkg; do
    grep -E "\"$pkg\" # (depends on broken|[Bb]roken).*" default.nix &> /dev/null
    [[ $? == 0 ]] && fn='confirm_broken' || fn='confirm_builds'
    [[ $fn == 'confirm_broken' ]] || continue # TODO: remove this
    sem --no-notice $fn "$pkg"
  done
}

main() {
  update_package_lists
  list_removed
  test_rpackages
  test_all_builds
  test_rpackages
}

main
