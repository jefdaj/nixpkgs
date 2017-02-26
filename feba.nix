# with import <nixpkgs> {};

{ perl, perlPackages, rPackages, rWrapper, stdenv, fetchgit, makeWrapper, writeScript }:

# TODO check whether perl packages are picked up
# TODO check whether R packages are picked up
# TODO add gfftools and replace missing bin/genbank2gff.pl

let
  # BioPerl = import ./bioperl.nix;
  perlDeps = with perlPackages; [
    # perl
    DBI
    FileWhich
    GetoptLong
    BioPerl
    # TODO package these?
    # Bio::Perl
    # Bio::SeqIO
    # Compounds
    # FileHandle
    # FindBin
    # Gene
    # POSIX
  ];
  rDeps = rWrapper.override {
    packages = with rPackages; [
      # TODO package this? think i remember it being hard...
      # ncdf4
      # R # TODO is this redundant?
      # parallel
    ];
  };

in stdenv.mkDerivation rec {
  name = "feba-${version}";
  # version = "9e96ed"; # TODO switch to current master?
  version = "bad9dd9"; # TODO switch to current master?
  src = fetchgit {
    url = "https://bitbucket.org/berkeleylab/feba";
    rev = version;
    # sha256 = "0x7wd8qc9l306i0z94qczlax5p0awf6pynvl6vilxdn02sxyvbi6";
    sha256 = "1wm6jhvkyk0wx0xi8r1235zbwsrqsx5hw7vwq8qzkhxk9vdb50vm";
  };
  # propogatedBuildInputs = perlDeps ++ [ rDeps ];
  buildInputs = [ makeWrapper rDeps ] ++ [ perl perlDeps ];
  builder = writeScript "builder.sh" ''
    source $stdenv/setup
    mkdir -p $out
    cp -R $src/* $out/
    rm $out/README $out/LICENSE
    chmod +w $out/bin
    # for script in $out/bin/*.pl; do
    #   wrapProgram $script --SET PERL5LIB : "$PERL5LIB"
    # done
    patchShebangs $out/bin
    echo "libs: $R_LIBS_SITE"
    chmod -w $out/bin
  '';
}
