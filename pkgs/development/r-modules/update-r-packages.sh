#!/usr/bin/env bash

# Usage: ./update-r-packages.sh

# It'll edit the package lists and default.nix,
# and also leave a lot of build_*.log files from failed builds in the working dir.
# You can delete those or look through them for clues.

# TODO: new overall algorithm:
#       0. update package lists with generate-r-packages.R
#       1. list all packages by rPackages attribute name (without trying to access them!)
#       2. try to build each one, and
#         2a. if the attribute is missing, mark as archived (how?)
#         2b. if it works and is marked broken, fix that
#         2c. if it's broken but not marked, fix that instead
#            2ci. if there's a dependency error say it's due to that
#            2cii. or if it's a hash mismatch put that in too
#            2ciii. otherwise generic "broken build"
#       3. make sure the whole rPackages can be evaluated (all archived packages gone)

##################
# update metadata
##################

update_package_list() {
  prefix="$1"
  path="${prefix}-packages.nix"
  echo "Updating ${path}"
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
  logfile="build_${pkg}.log"
  grep 'should have sha256'  $logfile > /dev/null && reason="hash mismatch"
  grep 'dependencies couldn' $logfile > /dev/null && reason="broken dependency"
  echo "marking $pkg broken (${reason})"
  sed -i "/brokenPackages = \\[$/a \ \ \ \ \"$pkg\" # $reason" default.nix
}

mark_fixed() {
  echo "marking $1 fixed"
  sed -i "/\"$1\" # broken build/d"          default.nix
  sed -i "/\"$1\" # broken dependency/d"     default.nix
  sed -i "/\"$1\" # build is broken/d"       default.nix
  sed -i "/\"$1\" # Build Is Broken/d"       default.nix
  sed -i "/# depends on broken package $1/d" default.nix
}

test_build() {
  pkg="$1"
  logfile="build_${pkg}.log"
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
  echo "Testing each package build. This could take a while..."
  list_attr_names | while read pkg; do
    grep -E "\"$pkg\" # (depends on broken|[Bb]roken).*" default.nix &> /dev/null
    [[ $? == 0 ]] && fn='confirm_broken' || fn='confirm_builds'
    [[ $fn == 'confirm_broken' ]] || continue # TODO: remove this
    sem --no-notice $fn "$pkg"
  done
}

# echo "Confirming that broken packages still fail to build"
# grep -E '" # (broken build|[Bb]uild [Ii]s [Bb]roken)' default.nix | cut -d'"' -f2 |
#   while read pkg; do
#     sem --no-notice confirm_broken $pkg
#   done
# echo

# TODO: now go through all R packages, still skipping the ones with logs
# echo "Confirming that working packages still build OK"
# grep '= derive' *-packages.nix |
#   cut -d":" -f2 | cut -d' ' -f1 | sort | uniq |
#   while read pkg; do
#     sem --no-notice confirm_builds $pkg
#   done
# echo

# TODO: don't need to build each package; fail dependencies of broken ones automatically

# TODO: check for newly broken packages

# TODO: look through build logs to see what obvious fixes can be added (but commit first)
# TODO: fix 'should have sha256' errors
# TODO: fix Octave_map errors
# TODO: fix dependencies: BiGGr -> libsbml

main() {
  update_package_lists
  list_removed
  test_rpackages
  test_all_builds
}

main
