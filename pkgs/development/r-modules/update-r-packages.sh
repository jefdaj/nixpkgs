#!/usr/bin/env bash

# Usage: ./update-r-packages.sh

# It edits the .nix files, so you want to make sure they're clean before
# starting and look through the diffs afterward. It also leaves a lot of
# build/*.log files, which you can delete or look through for clues.

# TODO: fix Octave_map errors
# TODO: fix dependencies: BiGGr -> libsbml
# TODO: only build NEW packages to speed it up drastically!

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

#####################################
# prompt to remove archived packages
#####################################

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

#########################################
# test all builds and update broken list
#########################################

list_depends() {
  [[ -z "$1" ]] && return
  grep -E "^$1 =" *-packages.nix |
    cut -d'[' -f2 | cut -d']' -f1 | sed "s/\ /\\n/g"
}

list_depends_rec() {
  list_depends "$1" | while read pkg; do
    # [[ -z "$pkg" ]] && return
    echo "$pkg"
    list_depends_rec "$pkg"
  done | sort | uniq
}

mark_fixed() {
  [[ -z "$1" ]] && return
  is_marked_broken "$1" || return
  sed -i "/\"$1\" # broken build/d"              default.nix
  sed -i "/\"$1\" # broken dependency/d"         default.nix
  sed -i "/\"$1\" # build is broken/d"           default.nix
  sed -i "/\"$1\" # Build Is Broken/d"           default.nix
  sed -i "/\"$1\" # depends on broken package/d" default.nix
  sed -i "/# depends on broken package $1/d"     default.nix
  echo "    removed $1 from broken list"
}

mark_fixed_rec() {
  mark_fixed "$1"
  list_depends_rec "$1" | while read pkg; do
    # [[ -z "$pkg" ]] && continue
    mark_fixed "$pkg"
  done
}

list_rdepends() {
  grep -E "depends=.*"[\ \[]$1[\ \[]"" *-packages.nix |
    cut -d':' -f2 | cut -d' ' -f1 | sort | uniq
}

list_rdepends_rec() {
  list_rdepends "$1" | while read pkg; do
    # [[ -z "$pkg" ]] && return
    echo "$pkg"
    list_rdepends_rec "$pkg"
  done
}

add_to_list() {
  name="$1"
  item="$2"
  sed -i "/$name = \\[$/a \ \ \ \ $item" default.nix
}

is_marked_broken() {
  grep -E "\"$1\" # broken build"              default.nix &>/dev/null && return 0
  grep -E "\"$1\" # broken dependency"         default.nix &>/dev/null && return 0
  grep -E "\"$1\" # build is broken"           default.nix &>/dev/null && return 0
  grep -E "\"$1\" # Build Is Broken"           default.nix &>/dev/null && return 0
  grep -E "\"$1\" # depends on broken package" default.nix &>/dev/null && return 0
  return 1
}

# TODO: be more accurate about the broken dependency here?
# TODO: or less accurate and have simpler code? could just say it's the build
mark_broken() {
  pkg="$1"
  logfile="build/${pkg}.log"
  reason="broken build"
  grep 'should have sha256'  $logfile > /dev/null && reason="hash mismatch"
  grep 'dependencies couldn' $logfile > /dev/null && reason="broken dependency"
  msg="\"$pkg\" # $reason"
  add_to_list "brokenPackages" "$msg"
  echo "    added ${pkg} to broken list (${reason})"
}

mark_broken_dep() {
  pkg="$1"; dep="$2"
  # [[ -z "$pkg" ]] && continue
  if is_marked_broken "$pkg"; then
    echo "    $pkg already marked broken"
  else
    msg="\"$pkg\" # depends on broken package $dep"
    add_to_list "brokenPackages" "$msg"
    echo "    added ${pkg} to broken list (depends on $dep)"
  fi
}

mark_broken_rec() {
  if is_marked_broken "$1"; then
    echo "    $1 already marked broken"
    return
  fi
  mark_broken "$1"
  list_rdepends_rec "$1" | while read pkg; do
    # [[ -z "$pkg" ]] && continue
    mark_broken_dep "$pkg" "$1"
  done
}

test_build() {
  pkg="$1"
  logfile="build/${pkg}.log"
  [[ -d build ]] || mkdir build
  if [[ -a $logfile ]]; then
    echo "  skipping ${pkg} because ${logfile} exists"
    return 255
  fi
  echo -n "  building ${pkg}..."
  nix-build '<nixpkgs>' \
    --arg config '{ allowBroken = true; allowUnfree = true; }' \
    -A "rPackages.${pkg}" 2>&1 &> $logfile
  code=$?
  [[ $code == 0 ]] && echo " success!" || echo " fail :("
  return $code
}

update_package() {
  pkg="$1"
  # [[ -z "$pkg" ]] && continue
  grep -E "\"$pkg\" # (depends on broken|[Bb]roken).*" default.nix &> /dev/null
  test_build "${pkg}"
  code=$?
  [[ $code -eq 255 ]] && return # skipped
  [[ $code -eq 0 ]] && mark_fixed_rec  "$pkg"
  [[ $code -gt 0 ]] && mark_broken_rec "$pkg"
}

test_all_builds() {
  echo "Updating default.nix broken list. This will take a while!"
  list_attr_names | while read pkg; do
    update_package "$pkg"
  done
}

main() {
  # update_package_lists
  list_removed
  test_rpackages
  test_all_builds
  test_rpackages
}

main
