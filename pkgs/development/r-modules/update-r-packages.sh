#!/usr/bin/env bash

# Usage: ./update-r-packages.sh (all | git ref)

# This edits the .nix files, so you want to make sure they're clean before
# starting and look through the diffs afterward. It also leaves a lot of
# build/*.log files, which you can delete or look through for clues. Note that
# if you choose 'all' the script will attempt to build all ~10000 R packages!
# It's much faster to provide a git ref, and only packages added since that ref
# will be built. I normally use `HEAD` or `master`.

# TODO: fix Octave_map errors
# TODO: fix dependencies: BiGGr -> libsbml
# TODO: canceR capkcage infinite loop?
# TODO: has it ever actually marked something unbroken?
# TODO: do newly updated packages always hash mismatch?

##################################
# run R script to update metadata
##################################

update_package_list() {
  prefix="$1"; path="${prefix}-packages.nix"
  echo "Downloading updates to ${path}"
  Rscript generate-r-packages.R ${prefix} >new && mv new ${path}
  return $?
}

list_package_files() {
  ls *-packages.nix | sed 's/\(.*\)-packages.nix/\1/p' | sort | uniq
}

update_package_lists() {
  list_package_files | while read prefix; do
    update_package_list "$prefix"
  done
}

#####################################
# prompt to remove archived packages
#####################################

list_attr_names() {
  expr="builtins.attrNames (import ./../../.. {}).rPackages"
  nix-instantiate --eval --expr "$expr" |  sed 's/\ /\n/g' |
    cut -d'"' -f2 | sort | uniq | tail -n+3 | grep -v override
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
  nix-env -f "./../../.." -qaP -A rPackages &> /dev/null
  if [[ $? != 0 ]]; then
    echo "Warning! rPackages fails to evaluate. Something went wrong. :("
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
    echo "$pkg"
    list_depends_rec "$pkg"
  done | sort | uniq
}

mark_fixed() {
  [[ -z "$1" ]] && return
  is_marked_broken "$1" || return
  sed -i "/\"$1\" # broken build/d"              default.nix
  sed -i "/\"$1\" # build is broken/d"           default.nix
  sed -i "/\"$1\" # Build Is Broken/d"           default.nix
  sed -i "/\"$1\" # depends on broken package/d" default.nix
  sed -i "/# depends on broken package $1/d"     default.nix
  echo "    marked $1 unbroken"
}

mark_fixed_rec() {
  mark_fixed "$1"
  list_depends_rec "$1" | while read pkg; do
    mark_fixed "$pkg"
  done
}

list_rdepends() {
  grep -E "depends=.*"[\ \[]$1[\ \[]"" *-packages.nix |
    cut -d':' -f2 | cut -d' ' -f1 | sort | uniq
}

list_rdepends_rec() {
  list_rdepends "$1" | while read pkg; do
    echo "$pkg"
    list_rdepends_rec "$pkg"
  done
}

add_to_list() {
  name="$1"; item="$2"
  sed -i "/$name = \\[$/a \ \ \ \ $item" default.nix
}

is_marked_broken() {
  grep -E "\"$1\" # broken build"              default.nix &>/dev/null && return 0
  grep -E "\"$1\" # build is broken"           default.nix &>/dev/null && return 0
  grep -E "\"$1\" # Build Is Broken"           default.nix &>/dev/null && return 0
  grep -E "\"$1\" # depends on broken package" default.nix &>/dev/null && return 0
  return 1
}

first_broken_dependency() {
  pkg="$1"; logfile="build/${pkg}.log"
  grep 'dependencies couldn' "$logfile" |
    cut -c74- | cut -d'-' -f1 | head -n1 |
    sed 's/\./_/g'
}

mark_broken() {
  pkg="$1"; logfile="build/${pkg}.log"; reason="broken build"
  if grep 'dependencies couldn' $logfile > /dev/null; then
    broken="$(first_broken_dependency "${pkg}")"
    [[ $broken == $pkg ]] || reason="depends on broken package ${broken}"
  fi
  msg="\"$pkg\" # $reason"
  add_to_list "brokenPackages" "$msg"
  echo "    marked ${pkg} broken (${reason})"
}

mark_broken_dep() {
  pkg="$1"; dep="$2"
  if is_marked_broken "$pkg"; then
    echo "    $pkg already marked broken"
  else
    msg="\"$pkg\" # depends on broken package $dep"
    add_to_list "brokenPackages" "$msg"
    echo "    marked ${pkg} broken (depends on $dep)"
  fi
}

mark_broken_rec() {
  if is_marked_broken "$1"; then
    echo "    $1 already marked broken"
    return
  fi
  mark_broken "$1"
  list_rdepends_rec "$1" | while read pkg; do
    mark_broken_dep "$pkg" "$1"
  done
}

test_build() {
  pkg="$1"; logfile="build/${pkg}.log"
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
  [[ $code == 0 ]] && echo " ok" || echo " fail"
  return $code
}

update_package() {
  pkg="$1"
  grep -E "\"$pkg\" # (depends on broken|[Bb]roken).*" default.nix &> /dev/null
  test_build "${pkg}"
  code=$?
  [[ $code -eq 255 ]] && return # skipped
  [[ $code -eq 0 ]] && mark_fixed_rec  "$pkg"
  [[ $code -gt 0 ]] && mark_broken_rec "$pkg"
}

list_updated_packages() {
  ref="$1"
  git diff $ref *-packages.nix | grep -E '^\+' | cut -d'+' -f2- |
    grep '= derive' | cut -d' ' -f1 | sort | uniq
}

test_all_builds() {
  ref="$1"
  [[ "$ref" == "all" ]] && fn='list_grep_names' || fn='list_updated_packages'
  echo "Updating default.nix broken list. This may take a while!"
  $fn "$ref" | while read pkg; do
    update_package "$pkg"
  done
}

main() {
  update_package_lists
  list_removed
  test_rpackages
  test_all_builds "$1"
  test_rpackages
}

main
