/* This file defines the composition for CRAN (R) packages. */

# TODO: recommended package codetools for testing?

{ R, pkgs, overrides }:

let
  inherit (pkgs) fetchurl stdenv lib;

  buildRPackage = pkgs.callPackage ./generic-builder.nix { inherit R; };

  # Generates package templates given per-repository settings
  #
  # some packages, e.g. cncaGUI, require X running while installation,
  # so that we use xvfb-run if requireX is true.
  mkDerive = {mkHomepage, mkUrls}: lib.makeOverridable ({
        name, version, sha256,
        depends ? [],
        doCheck ? true,
        requireX ? false,
        broken ? false,
        hydraPlatforms ? R.meta.hydraPlatforms
      }: buildRPackage {
    name = "${name}-${version}";
    src = fetchurl {
      inherit sha256;
      urls = mkUrls { inherit name version; };
    };
    inherit doCheck requireX;
    propagatedBuildInputs = depends;
    nativeBuildInputs = depends;
    meta.homepage = mkHomepage name;
    meta.platforms = R.meta.platforms;
    meta.hydraPlatforms = hydraPlatforms;
    meta.broken = broken;
  });

  # Templates for generating Bioconductor, CRAN and IRkernel packages
  # from the name, version, sha256, and optional per-package arguments above
  #
  deriveBioc = mkDerive {
    mkHomepage = name: "http://www.bioconductor.org/packages/${name}.html";
    mkUrls = {name, version}: [ "mirror://bioc/bioc/src/contrib/${name}_${version}.tar.gz" ];
  };
  deriveBiocAnn = mkDerive {
    mkHomepage = name: "http://www.bioconductor.org/packages/${name}.html";
    mkUrls = {name, version}: [ "mirror://bioc/data/annotation/src/contrib/${name}_${version}.tar.gz" ];
  };
  deriveBiocExp = mkDerive {
    mkHomepage = name: "http://www.bioconductor.org/packages/${name}.html";
    mkUrls = {name, version}: [ "mirror://bioc/data/experiment/src/contrib/${name}_${version}.tar.gz" ];
  };
  deriveCran = mkDerive {
    mkHomepage = name: "http://bioconductor.org/packages/release/bioc/html/${name}.html";
    mkUrls = {name, version}: [
      "mirror://cran/src/contrib/${name}_${version}.tar.gz"
      "mirror://cran/src/contrib/00Archive/${name}/${name}_${version}.tar.gz"
    ];
  };
  deriveIRkernel = mkDerive {
    mkHomepage = name: "http://irkernel.github.io/";
    mkUrls = {name, version}: [ "http://irkernel.github.io/src/contrib/${name}_${version}.tar.gz" ];
  };

  # Overrides package definitions with nativeBuildInputs.
  # For example,
  #
  # overrideNativeBuildInputs {
  #   foo = [ pkgs.bar ]
  # } old
  #
  # results in
  #
  # {
  #   foo = old.foo.overrideDerivation (attrs: {
  #     nativeBuildInputs = attrs.nativeBuildInputs ++ [ pkgs.bar ];
  #   });
  # }
  overrideNativeBuildInputs = overrides: old:
    lib.mapAttrs (name: value:
      (builtins.getAttr name old).overrideDerivation (attrs: {
        nativeBuildInputs = attrs.nativeBuildInputs ++ value;
      })
    ) overrides;

  # Overrides package definitions with buildInputs.
  # For example,
  #
  # overrideBuildInputs {
  #   foo = [ pkgs.bar ]
  # } old
  #
  # results in
  #
  # {
  #   foo = old.foo.overrideDerivation (attrs: {
  #     buildInputs = attrs.buildInputs ++ [ pkgs.bar ];
  #   });
  # }
  overrideBuildInputs = overrides: old:
    lib.mapAttrs (name: value:
      (builtins.getAttr name old).overrideDerivation (attrs: {
        buildInputs = attrs.buildInputs ++ value;
      })
    ) overrides;

  # Overrides package definitions with new R dependencies.
  # For example,
  #
  # overrideRDepends {
  #   foo = [ self.bar ]
  # } old
  #
  # results in
  #
  # {
  #   foo = old.foo.overrideDerivation (attrs: {
  #     nativeBuildInputs = attrs.nativeBuildInputs ++ [ self.bar ];
  #     propagatedNativeBuildInputs = attrs.propagatedNativeBuildInputs ++ [ self.bar ];
  #   });
  # }
  overrideRDepends = overrides: old:
    lib.mapAttrs (name: value:
      (builtins.getAttr name old).overrideDerivation (attrs: {
        nativeBuildInputs = attrs.nativeBuildInputs ++ value;
        propagatedNativeBuildInputs = attrs.propagatedNativeBuildInputs ++ value;
      })
    ) overrides;

  # Overrides package definition requiring X running to install.
  # For example,
  #
  # overrideRequireX [
  #   "foo"
  # ] old
  #
  # results in
  #
  # {
  #   foo = old.foo.override {
  #     requireX = true;
  #   };
  # }
  overrideRequireX = packageNames: old:
    let
      nameValuePairs = map (name: {
        inherit name;
        value = (builtins.getAttr name old).override {
          requireX = true;
        };
      }) packageNames;
    in
      builtins.listToAttrs nameValuePairs;

  # Overrides package definition to skip check.
  # For example,
  #
  # overrideSkipCheck [
  #   "foo"
  # ] old
  #
  # results in
  #
  # {
  #   foo = old.foo.override {
  #     doCheck = false;
  #   };
  # }
  overrideSkipCheck = packageNames: old:
    let
      nameValuePairs = map (name: {
        inherit name;
        value = (builtins.getAttr name old).override {
          doCheck = false;
        };
      }) packageNames;
    in
      builtins.listToAttrs nameValuePairs;

  # Overrides package definition to mark it broken.
  # For example,
  #
  # overrideBroken [
  #   "foo"
  # ] old
  #
  # results in
  #
  # {
  #   foo = old.foo.override {
  #     broken = true;
  #   };
  # }
  overrideBroken = packageNames: old:
    let
      nameValuePairs = map (name: {
        inherit name;
        value = (builtins.getAttr name old).override {
          broken = true;
        };
      }) packageNames;
    in
      builtins.listToAttrs nameValuePairs;

  defaultOverrides = old: new:
    let old0 = old; in
    let
      old1 = old0 // (overrideRequireX packagesRequireingX old0);
      old2 = old1 // (overrideSkipCheck packagesToSkipCheck old1);
      old3 = old2 // (overrideRDepends packagesWithRDepends old2);
      old4 = old3 // (overrideNativeBuildInputs packagesWithNativeBuildInputs old3);
      old5 = old4 // (overrideBuildInputs packagesWithBuildInputs old4);
      old6 = old5 // (overrideBroken brokenPackages old5);
      old = old6;
    in old // (otherOverrides old new);

  # Recursive override pattern.
  # `_self` is a collection of packages;
  # `self` is `_self` with overridden packages;
  # packages in `_self` may depends on overridden packages.
  self = (defaultOverrides _self self) // overrides;
  _self = import ./bioc-packages.nix { inherit self; derive = deriveBioc; } //
          import ./bioc-annotation-packages.nix { inherit self; derive = deriveBiocAnn; } //
          import ./bioc-experiment-packages.nix { inherit self; derive = deriveBiocExp; } //
          import ./cran-packages.nix { inherit self; derive = deriveCran; } //
          import ./irkernel-packages.nix { inherit self; derive = deriveIRkernel; };

  # tweaks for the individual packages and "in self" follow

  packagesWithRDepends = {
    FactoMineR = [ self.car ];
    pander = [ self.codetools ];
  };

  # TODO: try to figure these out by zgrepping packages
  packagesWithNativeBuildInputs = {
    affyPLM = [ pkgs.zlib ];
    bamsignals = [ pkgs.zlib ];
    BitSeq = [ pkgs.zlib ];
    abn = [ pkgs.gsl ];
    adimpro = [ pkgs.imagemagick ];
    audio = [ pkgs.portaudio ];
    BayesSAE = [ pkgs.gsl ];
    BayesVarSel = [ pkgs.gsl ];
    BayesXsrc = [ pkgs.readline pkgs.ncurses ];
    bigGP = [ pkgs.openmpi ];
    BiocCheck = [ pkgs.which ];
    Biostrings = [ pkgs.zlib ];
    DiffBind = [ pkgs.zlib ];
    ShortRead = [ pkgs.zlib ];
    oligo = [ pkgs.zlib ];
    gmapR = [ pkgs.zlib ];
    bnpmr = [ pkgs.gsl ];
    BNSP = [ pkgs.gsl ];
    cairoDevice = [ pkgs.gtk2 ];
    Cairo = [ pkgs.libtiff pkgs.libjpeg pkgs.cairo ];
    Cardinal = [ pkgs.which ];
    chebpol = [ pkgs.fftw ];
    ChemmineOB = [ pkgs.openbabel pkgs.pkgconfig ];
    cit = [ pkgs.gsl ];
    curl = [ pkgs.curl ];
    devEMF = [ pkgs.xorg.libXft ];
    diversitree = [ pkgs.gsl pkgs.fftw ];
    EMCluster = [ pkgs.liblapack ];
    fftw = [ pkgs.fftw ];
    fftwtools = [ pkgs.fftw ];
    Formula = [ pkgs.gmp ];
    geoCount = [ pkgs.gsl ];
    git2r = [ pkgs.zlib pkgs.openssl ];
    GLAD = [ pkgs.gsl ];
    glpkAPI = [ pkgs.gmp pkgs.glpk ];
    gmp = [ pkgs.gmp ];
    graphscan = [ pkgs.gsl ];
    gsl = [ pkgs.gsl ];
    HiCseg = [ pkgs.gsl ];
    iBMQ = [ pkgs.gsl ];
    igraph = [ pkgs.gmp ];
    JavaGD = [ pkgs.jdk ];
    jpeg = [ pkgs.libjpeg ];
    KFKSDS = [ pkgs.gsl ];
    kza = [ pkgs.fftw ];
    libamtrack = [ pkgs.gsl ];
    mixcat = [ pkgs.gsl ];
    mvabund = [ pkgs.gsl ];
    mwaved = [ pkgs.fftw ];
    ncdf4 = [ pkgs.netcdf ];
    ncdf = [ pkgs.netcdf ];
    nloptr = [ pkgs.nlopt ];
    openssl = [ pkgs.openssl ];
    outbreaker = [ pkgs.gsl ];
    pander = [ pkgs.pandoc pkgs.which ];
    pbdMPI = [ pkgs.openmpi ];
    pbdNCDF4 = [ pkgs.netcdf ];
    pbdPROF = [ pkgs.openmpi ];
    PKI = [ pkgs.openssl ];
    png = [ pkgs.libpng ];
    PopGenome = [ pkgs.zlib ];
    proj4 = [ pkgs.proj ];
    qtbase = [ pkgs.qt4 ];
    qtpaint = [ pkgs.qt4 ];
    R2GUESS = [ pkgs.gsl ];
    R2SWF = [ pkgs.zlib pkgs.libpng pkgs.freetype ];
    RAppArmor = [ pkgs.libapparmor ];
    rapportools = [ pkgs.which ];
    rapport = [ pkgs.which ];
    rbamtools = [ pkgs.zlib ];
    rcdd = [ pkgs.gmp ];
    RcppCNPy = [ pkgs.zlib ];
    RcppGSL = [ pkgs.gsl ];
    RcppOctave = [ pkgs.zlib pkgs.bzip2 pkgs.icu pkgs.lzma pkgs.pcre pkgs.octave ];
    RcppZiggurat = [ pkgs.gsl ];
    rgdal = [ pkgs.proj pkgs.gdal ];
    rgeos = [ pkgs.geos ];
    rggobi = [ pkgs.ggobi pkgs.gtk2 pkgs.libxml2 ];
    rgl = [ pkgs.mesa pkgs.xlibsWrapper ];
    Rglpk = [ pkgs.glpk ];
    RGtk2 = [ pkgs.gtk2 ];
    Rhpc = [ pkgs.zlib pkgs.bzip2 pkgs.icu pkgs.lzma pkgs.openmpi pkgs.pcre ];
    Rhtslib = [ pkgs.zlib ];
    ridge = [ pkgs.gsl ];
    RJaCGH = [ pkgs.zlib ];
    rjags = [ pkgs.jags ];
    rJava = [ pkgs.zlib pkgs.bzip2 pkgs.icu pkgs.lzma pkgs.pcre pkgs.jdk pkgs.libzip ];
    Rlibeemd = [ pkgs.gsl ];
    rmatio = [ pkgs.zlib ];
    Rmpfr = [ pkgs.gmp pkgs.mpfr ];
    Rmpi = [ pkgs.openmpi ];
    RMySQL = [ pkgs.zlib pkgs.mysql.lib ];
    RNetCDF = [ pkgs.netcdf pkgs.udunits ];
    RODBCext = [ pkgs.libiodbc ];
    RODBC = [ pkgs.libiodbc ];
    rpg = [ pkgs.postgresql ];
    rphast = [ pkgs.pcre pkgs.zlib pkgs.bzip2 pkgs.gzip pkgs.readline ];
    Rpoppler = [ pkgs.poppler ];
    RPostgreSQL = [ pkgs.postgresql ];
    RProtoBuf = [ pkgs.protobuf ];
    rPython = [ pkgs.python ];
    RSclient = [ pkgs.openssl ];
    Rserve = [ pkgs.openssl ];
    Rssa = [ pkgs.fftw ];
    Rsubread = [ pkgs.zlib ];
    rtfbs = [ pkgs.zlib pkgs.pcre pkgs.bzip2 pkgs.gzip pkgs.readline ];
    rtiff = [ pkgs.libtiff ];
    runjags = [ pkgs.jags ];
    RVowpalWabbit = [ pkgs.zlib pkgs.boost ];
    rzmq = [ pkgs.zeromq3 ];
    SAVE = [ pkgs.zlib pkgs.bzip2 pkgs.icu pkgs.lzma pkgs.pcre ];
    sdcTable = [ pkgs.gmp pkgs.glpk ];
    seewave = [ pkgs.fftw pkgs.libsndfile ];
    SemiCompRisks = [ pkgs.gsl ];
    seqinr = [ pkgs.zlib ];
    seqminer = [ pkgs.zlib pkgs.bzip2 ];
    showtext = [ pkgs.zlib pkgs.libpng pkgs.icu pkgs.freetype ];
    simplexreg = [ pkgs.gsl ];
    SOD = [ pkgs.cudatoolkit ]; # requres CL/cl.h
    spate = [ pkgs.fftw ];
    sprint = [ pkgs.openmpi ];
    ssanv = [ pkgs.proj ];
    stsm = [ pkgs.gsl ];
    stringi = [ pkgs.icu ];
    survSNP = [ pkgs.gsl ];
    sysfonts = [ pkgs.zlib pkgs.libpng pkgs.freetype ];
    TAQMNGR = [ pkgs.zlib ];
    tiff = [ pkgs.libtiff ];
    TKF = [ pkgs.gsl ];
    tkrplot = [ pkgs.xorg.libX11 ];
    topicmodels = [ pkgs.gsl ];
    udunits2 = [ pkgs.udunits pkgs.expat ];
    V8 = [ pkgs.v8 ];
    VBLPCM = [ pkgs.gsl ];
    VBmix = [ pkgs.gsl pkgs.fftw pkgs.qt4 ];
    WhopGenome = [ pkgs.zlib ];
    XBRL = [ pkgs.zlib pkgs.libxml2 ];
    xml2 = [ pkgs.libxml2 ];
    XML = [ pkgs.libtool pkgs.libxml2 pkgs.xmlsec pkgs.libxslt ];
    XVector = [ pkgs.zlib ];
    Rsamtools = [ pkgs.zlib ];
    rtracklayer = [ pkgs.zlib ];
    affyio = [ pkgs.zlib ];
    VariantAnnotation = [ pkgs.zlib ];
    snpStats = [ pkgs.zlib ];
  };

  packagesWithBuildInputs = {
    # sort -t '=' -k 2
    svKomodo = [ pkgs.which ];
    nat = [ pkgs.which ];
    nat_nblast = [ pkgs.which ];
    nat_templatebrains = [ pkgs.which ];
    RMark = [ pkgs.which ];
    RPushbullet = [ pkgs.which ];
    qtpaint = [ pkgs.cmake ];
    qtbase = [ pkgs.cmake pkgs.perl ];
    gmatrix = [ pkgs.cudatoolkit ];
    RCurl = [ pkgs.curl ];
    R2SWF = [ pkgs.pkgconfig ];
    rggobi = [ pkgs.pkgconfig ];
    RGtk2 = [ pkgs.pkgconfig ];
    RProtoBuf = [ pkgs.pkgconfig ];
    Rpoppler = [ pkgs.pkgconfig ];
    VBmix = [ pkgs.pkgconfig ];
    XML = [ pkgs.pkgconfig ];
    cairoDevice = [ pkgs.pkgconfig ];
    chebpol = [ pkgs.pkgconfig ];
    fftw = [ pkgs.pkgconfig ];
    geoCount = [ pkgs.pkgconfig ];
    kza = [ pkgs.pkgconfig ];
    mwaved = [ pkgs.pkgconfig ];
    showtext = [ pkgs.pkgconfig ];
    spate = [ pkgs.pkgconfig ];
    stringi = [ pkgs.pkgconfig ];
    sysfonts = [ pkgs.pkgconfig ];
    Cairo = [ pkgs.pkgconfig ];
    Rsymphony = [ pkgs.pkgconfig pkgs.doxygen pkgs.graphviz pkgs.subversion ];
    qtutils = [ pkgs.qt4 ];
    ecoretriever = [ pkgs.which ];
    tcltk2 = [ pkgs.tcl pkgs.tk ];
    tikzDevice = [ pkgs.which pkgs.texLive ];
    rPython = [ pkgs.which ];
    gridGraphics = [ pkgs.which ];
    gputools = [ pkgs.which pkgs.cudatoolkit ];
    adimpro = [ pkgs.which pkgs.xorg.xdpyinfo ];
    PET = [ pkgs.which pkgs.xorg.xdpyinfo pkgs.imagemagick ];
    dti = [ pkgs.which pkgs.xorg.xdpyinfo pkgs.imagemagick ];
  };

  packagesRequireingX = [
    "accrual"
    "ade4TkGUI"
    "adehabitat"
    "analogue"
    "analogueExtra"
    "AnalyzeFMRI"
    "AnnotLists"
    "AnthropMMD"
    "aplpack"
    "aqfig"
    "arf3DS4"
    "asbio"
    "AtelieR"
    "BAT"
    "bayesDem"
    "BCA"
    "BEQI2"
    "betapart"
    "betaper"
    "BiodiversityR"
    "BioGeoBEARS"
    "bio_infer"
    "bipartite"
    "biplotbootGUI"
    "blender"
    "cairoDevice"
    "CCTpack"
    "cncaGUI"
    "cocorresp"
    "CommunityCorrelogram"
    "confidence"
    "constrainedKriging"
    "ConvergenceConcepts"
    "cpa"
    "DALY"
    "dave"
    "debug"
    "Deducer"
    "DeducerExtras"
    "DeducerPlugInExample"
    "DeducerPlugInScaling"
    "DeducerSpatial"
    "DeducerSurvival"
    "DeducerText"
    "Demerelate"
    "DescTools"
    "detrendeR"
    "dgmb"
    "DivMelt"
    "dpa"
    "DSpat"
    "dynamicGraph"
    "dynBiplotGUI"
    "EasyqpcR"
    "EcoVirtual"
    "ENiRG"
    "EnQuireR"
    "eVenn"
    "exactLoglinTest"
    "FAiR"
    "fat2Lpoly"
    "fbati"
    "FD"
    "feature"
    "FeedbackTS"
    "FFD"
    "fgui"
    "fisheyeR"
    "fit4NM"
    "forams"
    "forensim"
    "FreeSortR"
    "fscaret"
    "fSRM"
    "gcmr"
    "Geneland"
    "GeoGenetix"
    "geomorph"
    "geoR"
    "geoRglm"
    "georob"
    "GeoXp"
    "GGEBiplotGUI"
    "gnm"
    "GPCSIV"
    "GrammR"
    "GrapheR"
    "GroupSeq"
    "gsubfn"
    "GUniFrac"
    "gWidgets2RGtk2"
    "gWidgets2tcltk"
    "gWidgetsRGtk2"
    "gWidgetstcltk"
    "HH"
    "HiveR"
    "HomoPolymer"
    "iBUGS"
    "ic50"
    "iDynoR"
    "in2extRemes"
    "iplots"
    "isopam"
    "IsotopeR"
    "JGR"
    "KappaGUI"
    "likeLTD"
    "logmult"
    "LS2Wstat"
    "MAR1"
    "MareyMap"
    "memgene"
    "MergeGUI"
    "metacom"
    "Meth27QC"
    "MetSizeR"
    "MicroStrategyR"
    "migui"
    "miniGUI"
    "MissingDataGUI"
    "mixsep"
    "mlDNA"
    "MplusAutomation"
    "mpmcorrelogram"
    "mritc"
    "MTurkR"
    "multgee"
    "multibiplotGUI"
    "nodiv"
    "OligoSpecificitySystem"
    "onemap"
    "OpenRepGrid"
    "palaeoSig"
    "paleoMAS"
    "pbatR"
    "PBSadmb"
    "PBSmodelling"
    "PCPS"
    "pez"
    "phylotools"
    "picante"
    "PKgraph"
    "playwith"
    "plotSEMM"
    "plsRbeta"
    "plsRglm"
    "pmg"
    "PopGenReport"
    "poppr"
    "powerpkg"
    "PredictABEL"
    "prefmod"
    "PrevMap"
    "ProbForecastGOP"
    "QCAGUI"
    "qtbase"
    "qtpaint"
    "qtutils"
    "R2STATS"
    "r4ss"
    "RandomFields"
    "rareNMtests"
    "rAverage"
    "Rcmdr"
    "RcmdrPlugin_BCA"
    "RcmdrPlugin_coin"
    "RcmdrPlugin_depthTools"
    "RcmdrPlugin_DoE"
    "RcmdrPlugin_doex"
    "RcmdrPlugin_EACSPIR"
    "RcmdrPlugin_EBM"
    "RcmdrPlugin_EcoVirtual"
    "RcmdrPlugin_epack"
    "RcmdrPlugin_EZR"
    "RcmdrPlugin_FactoMineR"
    "RcmdrPlugin_HH"
    "RcmdrPlugin_IPSUR"
    "RcmdrPlugin_KMggplot2"
    "RcmdrPlugin_lfstat"
    "RcmdrPlugin_MA"
    "RcmdrPlugin_mosaic"
    "RcmdrPlugin_MPAStats"
    "RcmdrPlugin_orloca"
    "RcmdrPlugin_plotByGroup"
    "RcmdrPlugin_pointG"
    "RcmdrPlugin_qual"
    "RcmdrPlugin_ROC"
    "RcmdrPlugin_sampling"
    "RcmdrPlugin_SCDA"
    "RcmdrPlugin_SLC"
    "RcmdrPlugin_SM"
    "RcmdrPlugin_sos"
    "RcmdrPlugin_steepness"
    "RcmdrPlugin_survival"
    "RcmdrPlugin_TeachingDemos"
    "RcmdrPlugin_temis"
    "RcmdrPlugin_UCA"
    "recluster"
    "relax"
    "relimp"
    "RenextGUI"
    "reportRx"
    "reshapeGUI"
    "rgl"
    "RHRV"
    "rich"
    "rioja"
    "ripa"
    "rite"
    "rnbn"
    "RNCEP"
    "RQDA"
    "RSDA"
    "rsgcc"
    "RSurvey"
    "RunuranGUI"
    "sdcMicroGUI"
    "sharpshootR"
    "simba"
    "Simile"
    "SimpleTable"
    "SOLOMON"
    "soundecology"
    "SPACECAP"
    "spacodiR"
    "spatsurv"
    "sqldf"
    "SRRS"
    "SSDforR"
    "statcheck"
    "StatDA"
    "STEPCAM"
    "stosim"
    "strvalidator"
    "stylo"
    "svDialogstcltk"
    "svIDE"
    "svSocket"
    "svWidgets"
    "SYNCSA"
    "SyNet"
    "tcltk2"
    "TDMR"
    "TED"
    "TestScorer"
    "TIMP"
    "titan"
    "tkrgl"
    "tkrplot"
    "tmap"
    "tspmeta"
    "TTAinterfaceTrendAnalysis"
    "twiddler"
    "vcdExtra"
    "VecStatGraphs3D"
    "vegan"
    "vegan3d"
    "vegclust"
    "VIMGUI"
    "WMCapacity"
    "x12GUI"
    "xergm"
  ];

  packagesToSkipCheck = [
    "Rmpi" # tries to run MPI processes
    "gmatrix" # requires CUDA runtime
    "sprint" # tries to run MPI processes
    "pbdMPI" # tries to run MPI processes
  ];

  # Packages which cannot be installed due to lack of dependencies or other reasons.
  brokenPackages = [
    "ABAData" # broken build
    "ABAEnrichment" # depends on broken package ABAData
    "AER" # depends on broken package nloptr
    "ALLMLL" # broken build
    "ARRmData" # broken build
    "ARRmNormalization" # broken build
    "ART" # depends on broken package ar-car-2.1-0
    "ARTool" # depends on broken package nlopt-2.4.2
    "Actigraphy" # Build Is Broken
    "Affyhgu133Plus2Expr" # broken build
    "Affyhgu133aExpr" # broken build
    "AffymetrixDataTestFiles" # broken build
    "Affymoe4302Expr" # broken build
    "AgiMicroRna" # depends on broken package affycoretools
    "AmpAffyExample" # broken build
    "AnalysisPageServer" # broken build
    "AnnotationForge" # broken build
    "AnnotationHubData" # depends on broken package org_Hs_eg_db
    "ArfimaMLM" # depends on broken package nlopt-2.4.2
    "ArrayExpressHTS" # broken build
    "AshkenazimSonChr21" # broken build
    "AssetPricing" # depends on broken package polynom
    "AtelieR" # depends on broken package polynom
    "AutoModel" # depends on broken package r-car-2.1-0
    "BACA" # depends on broken package AnnotationForge
    "BAGS" # broken build
    "BANOVA" # broken build
    "BBRecapture" # depends on broken package nlopt-2.4.2
    "BCA" # depends on broken package nloptr
    "BEST" # depends on broken package jagsUI
    "BIFIEsurvey" # depends on broken package nlopt-2.4.2
    "BLCOP" # depends on broken package fPortfolio
    "BRugs" # build is broken
    "BSgenome_Alyrata_JGI_v1" # broken build
    "BSgenome_Amellifera_BeeBase_assembly4" # broken build
    "BSgenome_Amellifera_UCSC_apiMel2" # broken build
    "BSgenome_Amellifera_UCSC_apiMel2_masked" # broken build
    "BSgenome_Athaliana_TAIR_04232008" # broken build
    "BSgenome_Athaliana_TAIR_TAIR9" # broken build
    "BSgenome_Btaurus_UCSC_bosTau3" # broken build
    "BSgenome_Btaurus_UCSC_bosTau3_masked" # depends on broken package BSgenome_Btaurus_UCSC_bosTau3
    "BSgenome_Btaurus_UCSC_bosTau4" # broken build
    "BSgenome_Btaurus_UCSC_bosTau4_masked" # depends on broken package BSgenome_Btaurus_UCSC_bosTau4
    "BSgenome_Btaurus_UCSC_bosTau6" # broken build
    "BSgenome_Btaurus_UCSC_bosTau6_masked" # depends on broken package BSgenome_Btaurus_UCSC_bosTau6
    "BSgenome_Btaurus_UCSC_bosTau8" # broken build
    "BSgenome_Celegans_UCSC_ce10" # broken build
    "BSgenome_Celegans_UCSC_ce2" # broken build
    "BSgenome_Celegans_UCSC_ce6" # broken build
    "BSgenome_Cfamiliaris_UCSC_canFam2" # broken build
    "BSgenome_Cfamiliaris_UCSC_canFam2_masked" # depends on broken package BSgenome_Cfamiliaris_UCSC_canFam2
    "BSgenome_Cfamiliaris_UCSC_canFam3" # broken build
    "BSgenome_Cfamiliaris_UCSC_canFam3_masked" # depends on broken package BSgenome_Cfamiliaris_UCSC_canFam3
    "BSgenome_Dmelanogaster_UCSC_dm2" # broken build
    "BSgenome_Dmelanogaster_UCSC_dm2_masked" # broken build
    "BSgenome_Dmelanogaster_UCSC_dm3" # broken build
    "BSgenome_Dmelanogaster_UCSC_dm3_masked" # broken build
    "BSgenome_Dmelanogaster_UCSC_dm6" # broken build
    "BSgenome_Drerio_UCSC_danRer10" # broken build
    "BSgenome_Drerio_UCSC_danRer5" # broken build
    "BSgenome_Drerio_UCSC_danRer5_masked" # depends on broken package BSgenome_Drerio_UCSC_danRer5
    "BSgenome_Drerio_UCSC_danRer6" # broken build
    "BSgenome_Drerio_UCSC_danRer6_masked" # depends on broken package BSgenome_Drerio_UCSC_danRer6
    "BSgenome_Drerio_UCSC_danRer7" # broken build
    "BSgenome_Drerio_UCSC_danRer7_masked" # depends on broken package BSgenome_Drerio_UCSC_danRer7
    "BSgenome_Ecoli_NCBI_20080805" # broken build
    "BSgenome_Gaculeatus_UCSC_gasAcu1" # broken build
    "BSgenome_Gaculeatus_UCSC_gasAcu1_masked" # broken build
    "BSgenome_Ggallus_UCSC_galGal3" # broken build
    "BSgenome_Ggallus_UCSC_galGal3_masked" # depends on broken package BSgenome_Ggallus_UCSC_galGal3
    "BSgenome_Ggallus_UCSC_galGal4" # broken build
    "BSgenome_Ggallus_UCSC_galGal4_masked" # depends on broken package BSgenome_Ggallus_UCSC_galGal4
    "BSgenome_Hsapiens_1000genomes_hs37d5" # broken build
    "BSgenome_Hsapiens_NCBI_GRCh38" # broken build
    "BSgenome_Hsapiens_UCSC_hg17" # broken build
    "BSgenome_Hsapiens_UCSC_hg17_masked" # depends on broken package BSgenome_Hsapiens_UCSC_hg17
    "BSgenome_Hsapiens_UCSC_hg18" # broken build
    "BSgenome_Hsapiens_UCSC_hg18_masked" # depends on broken package BSgenome_Hsapiens_UCSC_hg18
    "BSgenome_Hsapiens_UCSC_hg19" # broken build
    "BSgenome_Hsapiens_UCSC_hg19_masked" # depends on broken package BSgenome_Hsapiens_UCSC_hg19
    "BSgenome_Hsapiens_UCSC_hg38" # broken build
    "BSgenome_Hsapiens_UCSC_hg38_masked" # depends on broken package BSgenome_Hsapiens_UCSC_hg38
    "BSgenome_Mfascicularis_NCBI_5_0" # broken build
    "BSgenome_Mfuro_UCSC_musFur1" # broken build
    "BSgenome_Mmulatta_UCSC_rheMac2" # broken build
    "BSgenome_Mmulatta_UCSC_rheMac2_masked" # depends on broken package BSgenome_Mmulatta_UCSC_rheMac2
    "BSgenome_Mmulatta_UCSC_rheMac3" # broken build
    "BSgenome_Mmulatta_UCSC_rheMac3_masked" # depends on broken package BSgenome_Mmulatta_UCSC_rheMac3
    "BSgenome_Mmusculus_UCSC_mm10" # broken build
    "BSgenome_Mmusculus_UCSC_mm10_masked" # depends on broken package BSgenome_Mmusculus_UCSC_mm10
    "BSgenome_Mmusculus_UCSC_mm8" # broken build
    "BSgenome_Mmusculus_UCSC_mm8_masked" # depends on broken package BSgenome_Mmusculus_UCSC_mm8
    "BSgenome_Mmusculus_UCSC_mm9" # broken build
    "BSgenome_Mmusculus_UCSC_mm9_masked" # depends on broken package BSgenome_Mmusculus_UCSC_mm9
    "BSgenome_Osativa_MSU_MSU7" # broken build
    "BSgenome_Ptroglodytes_UCSC_panTro2" # broken build
    "BSgenome_Ptroglodytes_UCSC_panTro2_masked" # depends on broken package BSgenome_Ptroglodytes_UCSC_panTro2
    "BSgenome_Ptroglodytes_UCSC_panTro3" # broken build
    "BSgenome_Ptroglodytes_UCSC_panTro3_masked" # depends on broken package BSgenome_Ptroglodytes_UCSC_panTro3
    "BSgenome_Rnorvegicus_UCSC_rn4" # broken build
    "BSgenome_Rnorvegicus_UCSC_rn4_masked" # depends on broken package BSgenome_Rnorvegicus_UCSC_rn4
    "BSgenome_Rnorvegicus_UCSC_rn5" # broken build
    "BSgenome_Rnorvegicus_UCSC_rn5_masked" # depends on broken package BSgenome_Rnorvegicus_UCSC_rn5
    "BSgenome_Rnorvegicus_UCSC_rn6" # broken build
    "BSgenome_Sscrofa_UCSC_susScr3" # broken build
    "BSgenome_Sscrofa_UCSC_susScr3_masked" # depends on broken package BSgenome_Sscrofa_UCSC_susScr3
    "BSgenome_Tguttata_UCSC_taeGut1" # broken build
    "BSgenome_Tguttata_UCSC_taeGut1_masked" # depends on broken package BSgenome_Tguttata_UCSC_taeGut1
    "BSgenome_Tguttata_UCSC_taeGut2" # broken build
    "BSgenome_Vvinifera_URGI_IGGP12Xv0" # broken build
    "BSgenome_Vvinifera_URGI_IGGP12Xv2" # broken build
    "BTSPAS" # broken build
    "Basic4Cseq" # broken build
    "BaySIC" # broken build
    "BayesMed" # depends on broken package R2jags
    "Bayesthresh" # depends on broken package nlopt-2.4.2
    "BeadArrayUseCases" # broken build
    "BiGGR" # broken build
    "BiSEp" # depends on broken package GO_db
    "BiodiversityR" # depends on broken package nlopt-2.4.2
    "BradleyTerry2" # depends on broken package nlopt-2.4.2
    "BrailleR" # broken build
    "BubbleTree" # depends on broken package r-biovizBase-1.17.2
    "CADFtest" # depends on broken package nlopt-2.4.2
    "CAFE" # broken build
    "CALIB" # broken build
    "CAMERA" # depends on broken package xcms
    "CARrampsOcl" # broken build
    "CCTpack" # depends on broken package R2jags
    "CCl4" # broken build
    "CCpop" # depends on broken package nlopt-2.4.2
    "CLME" # depends on broken package nlopt-2.4.2
    "CNEr" # broken build
    "CNORfuzzy" # depends on broken package nlopt-2.4.2
    "CNVPanelizer" # depends on broken cn.mops-1.15.1
    "CODEX" # depends on broken package BSgenome_Hsapiens_UCSC_hg19
    "COPDSexualDimorphism_data" # broken build
    "COSMIC_67" # broken build
    "CardinalWorkflows" # broken build
    "Category" # broken build
    "Causata" # broken build
    "ChAMP" # broken build
    "ChAMPdata" # broken build
    "ChIPComp" # depends on broken package r-Rsamtools-1.21.18
    "ChIPQC" # depends on broken package AnnotationForge
    "ChIPXpress" # broken build
    "ChIPXpressData" # broken build
    "ChIPpeakAnno" # broken build
    "ChIPseeker" # broken build
    "ChainLadder" # depends on broken package nlopt-2.4.2
    "ChemmineDrugs" # broken build
    "ChemmineR" # broken build
    "ChimpHumanBrainData" # broken build
    "ClustGeo" # depends on broken FactoMineR-1.31.3
    "ClustGeo" # depends on broken package car
    "CoCiteStats" # broken build
    "CompGO" # depends on broken package AnnotationForge
    "ConnectivityMap" # broken build
    "CopulaDTA" # broken build
    "CopyNumber450kData" # broken build
    "CopyhelpeR" # broken build
    "CopywriteR" # depends on broken package CopyhelpeR
    "CosmoPhotoz" # depends on broken package nlopt-2.4.2
    "CrypticIBDcheck" # depends on broken package nlopt-2.4.2
    "DAMisc" # depends on broken package nlopt-2.4.2
    "DAPAR" # depends on broken package MSnbase
    "DBKGrad" # depends on broken package SDD
    "DJL" # depends on broken package car
    "DMRcate" # broken build
    "DMRcatedata" # broken build
    "DOQTL" # depends on broken package BSgenome_Mmusculus_UCSC_mm10
    "DOSE" # broken build
    "DeSousa2013" # broken build
    "Deducer" # depends on broken package car
    "DeducerExtras" # depends on broken package nlopt-2.4.2
    "DeducerPlugInExample" # depends on broken package nlopt-2.4.2
    "DeducerPlugInScaling" # depends on broken package nlopt-2.4.2
    "DeducerSpatial" # depends on broken package nlopt-2.4.2
    "DeducerSurvival" # depends on broken package nlopt-2.4.2
    "DeducerText" # depends on broken package nlopt-2.4.2
    "DiagTest3Grp" # depends on broken package nlopt-2.4.2
    "DiffBind" # depends on broken package AnnotationForge
    "DirichletMultinomial" # broken build
    "DistatisR" # depends on broken package nlopt-2.4.2
    "DmelSGI" # broken build
    "DonaPLLP2013" # broken build
    "DrugVsDisease" # depends on broken package cMap2data
    "DrugVsDiseasedata" # broken build
    "DvDdata" # broken build
    "ELMER" # broken build
    "EMA" # depends on broken package nlopt-2.4.2
    "ESKNN" # depends on broken package r-caret-6.0-52
    "EatonEtAlChIPseq" # broken build
    "EffectLiteR" # depends on broken package nlopt-2.4.2
    "EnQuireR" # depends on broken package nlopt-2.4.2
    "EnrichmentBrowser" # depends on broken package r-EDASeq-2.3.2
    "EnsDb_Hsapiens_v75" # broken build
    "EnsDb_Hsapiens_v79" # broken build
    "EnsDb_Mmusculus_v75" # broken build
    "EnsDb_Mmusculus_v79" # broken build
    "EnsDb_Rnorvegicus_v79" # broken build
    "ExpressionView" # depends on broken package Category
    "FANTOM3and4CAGE" # broken build
    "FDRreg" # depends on broken package nlopt-2.4.2
    "FDb_InfiniumMethylation_hg18" # broken build
    "FDb_InfiniumMethylation_hg19" # broken build
    "FDb_UCSC_snp135common_hg19" # broken build
    "FDb_UCSC_snp137common_hg19" # broken build
    "FEM" # broken build
    "FSA" # depends on broken package car
    "FactoMineR" # depends on broken package car
    "Factoshiny" # depends on broken package nlopt-2.4.2
    "Fletcher2013a" # broken build
    "Fletcher2013b" # depends on broken package Fletcher2013a
    "FlowSOM" # depends on broken package flowCore
    "FlowSorted_Blood_450k" # broken build
    "FlowSorted_DLPFC_450k" # broken build
    "FunciSNP" # depends on broken package ChIPpeakAnno
    "FunciSNP_data" # broken build
    "FunctionalNetworks" # broken build
    "GDAtools" # depends on broken package nlopt-2.4.2
    "GEOsearch" # broken build
    "GEWIST" # depends on broken package nlopt-2.4.2
    "GGHumanMethCancerPanelv1_db" # depends on broken package AnnotationForge
    "GGdata" # broken build
    "GOFunction" # depends on broken package GO_db
    "GOSemSim" # depends on broken package GO_db
    "GOSim" # depends on broken package GO_db
    "GO_db" # broken build
    "GOstats" # depends on broken package AnnotationForge
    "GPC" # broken build
    "GSBenchMark" # broken build
    "GSVAdata" # broken build
    "GUIDEseq" # depends on broken package ChIPpeakAnno
    "GUIProfiler" # broken build
    "GWAF" # depends on broken package nlopt-2.4.2
    "GraphPAC" # depends on broken package RMallow
    "GraphPCA" # depends on broken package nlopt-2.4.2
    "HD2013SGI" # broken build
    "HLMdiag" # depends on broken package nlopt-2.4.2
    "HSMMSingleCell" # broken build
    "HTSanalyzeR" # depends on broken package Category
    "HiCDataHumanIMR90" # broken build
    "HiCDataLymphoblast" # broken build
    "HiPLARM" # Build Is Broken
    "HierO" # Build Is Broken
    "Hiiragi2013" # broken build
    "HilbertVisGUI" # Build Is Broken
    "HistDAWass" # depends on broken package nlopt-2.4.2
    "Homo_sapiens" # depends on broken package GO_db
    "Hs6UG171_db" # broken build
    "HsAgilentDesign026652_db" # broken build
    "HuO22_db" # broken build
    "HydeNet" # broken build
    "IATscores" # depends on broken package nlopt-2.4.2
    "INSPEcT" # depends on broken GenomicFeatures-1.21.13
    "IONiseR" # depends on broken rhdf5-2.13.4
    "ITALICS" # broken build
    "ITALICSData" # broken build
    "ITEMAN" # depends on broken package car
    "IVAS" # depends on broken package nlopt-2.4.2
    "IlluminaDataTestFiles" # broken build
    "IlluminaHumanMethylation27k_db" # broken build
    "IlluminaHumanMethylation450k_db" # broken build
    "IlluminaHumanMethylation450kanno_ilmn12_hg19" # broken build
    "IlluminaHumanMethylation450kprobe" # broken build
    "InPAS" # depends on broken package BSgenome_Drerio_UCSC_danRer7
    "JAGUAR" # depends on broken package nlopt-2.4.2
    "JASPAR2014" # broken build
    "JazaeriMetaData_db" # broken build
    "KEGGandMetacoreDzPathwaysGEO" # broken build
    "KEGGdzPathwaysGEO" # broken build
    "LANDD" # depends on broken package AnnotationForge
    "LAPOINTE_db" # broken build
    "LMERConvenienceFunctions" # depends on broken package nlopt-2.4.2
    "LOGIT" # depends on broken package car
    "LOST" # broken build
    "LiquidAssociation" # broken build
    "ListerEtAlBSseq" # broken build
    "LogisticDx" # depends on broken package nlopt-2.4.2
    "LowMACA" # depends on broken package motifStack
    "LungCancerACvsSCCGEO" # broken build
    "MAIT" # depends on broken package CAMERA
    "MAQCsubset" # broken build
    "MAQCsubsetAFX" # broken build
    "MAQCsubsetILM" # broken build
    "MBmca" # depends on broken nloptr-1.0.4
    "MBmca" # depends on broken package chipPCR
    "MCRestimate" # depends on broken package golubEsets
    "MEAL" # depends on broken package DMRcate
    "MEALData" # broken build
    "MEDIPSData" # broken build
    "MEDME" # depends on broken package nlopt-2.4.2
    "MEMSS" # depends on broken package nlopt-2.4.2
    "MLSeq" # depends on broken package nlopt-2.4.2
    "MMDiff" # depends on broken package AnnotationForge
    "MMDiffBamSubset" # broken build
    "MRIaggr" # broken build
    "MSnID" # depends on broken package MSnbase
    "MSnbase" # broken build
    "MSstats" # depends on broken package nlopt-2.4.2
    "MUGAExampleData" # broken build
    "MafDb_ALL_wgs_phase1_release_v3_20101123" # broken build
    "MafDb_ALL_wgs_phase3_release_v5b_20130502" # broken build
    "MafDb_ESP6500SI_V2_SSA137" # broken build
    "MafDb_ExAC_r0_3_sites" # broken build
    "MatrixRider" # depends on broken package CNEr
    "MaxPro" # depends on broken package nlopt-2.4.2
    "MazamaSpatialUtils" # broken build
    "MeSH_Aca_eg_db" # broken build
    "MeSH_Aga_PEST_eg_db" # broken build
    "MeSH_Ame_eg_db" # broken build
    "MeSH_Ath_eg_db" # broken build
    "MeSH_Bfl_eg_db" # broken build
    "MeSH_Bsu_TUB10_eg_db" # broken build
    "MeSH_Cal_SC5314_eg_db" # broken build
    "MeSH_Cbr_eg_db" # broken build
    "MeSH_Cfa_eg_db" # broken build
    "MeSH_Cin_eg_db" # broken build
    "MeSH_Cja_eg_db" # broken build
    "MeSH_Dan_eg_db" # broken build
    "MeSH_Ddi_AX4_eg_db" # broken build
    "MeSH_Der_eg_db" # broken build
    "MeSH_Dgr_eg_db" # broken build
    "MeSH_Dme_eg_db" # broken build
    "MeSH_Dpe_eg_db" # broken build
    "MeSH_Dre_eg_db" # broken build
    "MeSH_Dse_eg_db" # broken build
    "MeSH_Dsi_eg_db" # broken build
    "MeSH_Dvi_eg_db" # broken build
    "MeSH_Dya_eg_db" # broken build
    "MeSH_Eco_55989_eg_db" # broken build
    "MeSH_Eco_HS_eg_db" # broken build
    "MeSH_Eco_IAI1_eg_db" # broken build
    "MeSH_Eco_K12_MG1655_eg_db" # broken build
    "MeSH_Eco_O157_H7_EDL933_eg_db" # broken build
    "MeSH_Hsa_eg_db" # broken build
    "MeSH_Mmu_eg_db" # broken build
    "MeSH_Mtr_eg_db" # broken build
    "MeSH_Osa_eg_db" # broken build
    "MeSH_Ptr_eg_db" # broken build
    "MeSH_Rno_eg_db" # broken build
    "MeSH_Sce_S288c_eg_db" # broken build
    "MeSH_Spo_972h_eg_db" # broken build
    "MeSH_Xla_eg_db" # broken build
    "MeSH_Zma_eg_db" # broken build
    "MeSH_db" # broken build
    "Metatron" # depends on broken package nlopt-2.4.2
    "MethylAid" # depends on broken package FDb_InfiniumMethylation_hg19
    "MethylAidData" # broken build
    "MigClim" # Build Is Broken
    "MineICA" # depends on broken package AnnotationForge
    "MixMAP" # depends on broken package nlopt-2.4.2
    "MmAgilentDesign026655_db" # broken build
    "MoExExonProbesetLocation" # broken build
    "Mu15v1_db" # broken build
    "Mu22v3_db" # broken build
    "Mulder2012" # depends on broken package Category
    "MultiRR" # depends on broken package nlopt-2.4.2
    "Mus_musculus" # depends on broken package GO_db
    "NGScopy"
    "NGScopyData" # broken build
    "NHPoisson" # depends on broken package nlopt-2.4.2
    "NORRRM" # build is broken
    "NSM3" # broken build
    "NanoStringQCPro" # broken build
    "Neve2006" # broken build
    "Norway981_db" # broken build
    "OUwie" # depends on broken package nlopt-2.4.2
    "OmicsMarkeR" # depends on broken package nlopt-2.4.2
    "OperonHumanV3_db" # broken build
    "PADOG" # build is broken
    "PANDA" # broken build
    "PANTHER_db" # broken build
    "PBD" # broken build
    "PBImisc" # depends on broken package nlopt-2.4.2
    "PCpheno" # depends on broken package apComplex
    "PFAM_db" # broken build
    "PGSEA" # depends on broken package annaffy
    "POCRCannotation_db" # broken build
    "PREDAsampledata" # depends on broken package gahgu133plus2cdf
    "PSAboot" # depends on broken package nlopt-2.4.2
    "PWMEnrich_Dmelanogaster_background" # broken build
    "PWMEnrich_Hsapiens_background" # broken build
    "PartheenMetaData_db" # broken build
    "PathNetData" # broken build
    "PatternClass" # build is broken
    "Pbase" # depends on broken package MSnbase
    "PharmacoGx"
    "PhenStat" # depends on broken package nlopt-2.4.2
    "PolyPhen_Hsapiens_dbSNP131" # broken build
    "ProCoNA" # depends on broken package AnnotationForge
    "Prostar" # depends on broken package MSnbase
    "ProteomicsAnnotationHubData" # depends on broken package r-AnnotationHub-2.1.40
    "PythonInR"
    "QDNAseq_hg19" # broken build
    "QDNAseq_mm10" # broken build
    "QFRM"
    "QUALIFIER" # depends on broken package flowCore
    "QuartPAC" # depends on broken package RMallow
    "R2STATS" # depends on broken package nlopt-2.4.2
    "R2jags" # broken build
    "R2jags" # broken build
    "RADami" # broken build
    "RBerkeley"
    "RDAVIDWebService" # depends on broken package AnnotationForge
    "RDieHarder" # build is broken
    "REDseq" # depends on broken package BSgenome_Celegans_UCSC_ce2
    "REST" # depends on broken package nlopt-2.4.2
    "REndo" # depends on broken package AER
    "RIPSeekerData" # broken build
    "RLRsim" # depends on broken package nloptr
    "RMallow" # broken build
    "RMallow" # broken build
    "RMassBankData" # broken build
    "RNAinteract" # depends on broken package Category
    "RNAinteractMAPK" # depends on broken package Category
    "RNAither" # depends on broken package nlopt-2.4.2
    "RNAseqData_HNRNPC_bam_chr14" # broken build
    "RQuantLib" # build is broken
    "RRBSdata" # broken build
    "RRreg" # depends on broken package nloptr
    "RSAP" # build is broken
    "RSDA" # depends on broken package nlopt-2.4.2
    "RStoolbox" # depends on broken package r-caret-6.0-52
    "RTCGA_clinical" # broken build
    "RTCGA_mutations" # broken build
    "RTCGA_rnaseq" # broken build
    "RTN" # depends on broken package car
    "RVAideMemoire" # depends on broken package nlopt-2.4.2
    "RVFam" # depends on broken package nlopt-2.4.2
    "RWebServices" # broken build
    "RareVariantVis" # depends on broken VariantAnnotation-1.15.19
    "Rattus_norvegicus" # depends on broken package GO_db
    "RbioRXN" # depends on broken package ChemmineR
    "Rblpapi" # broken build
    "Rchemcpp" # depends on broken package ChemmineR
    "Rchoice" # depends on broken package car
    "RchyOptimyx" # broken build
    "Rcmdr" # depends on broken package car
    "RcmdrMisc" # depends on broken package car
    "RcmdrPlugin_BCA" # depends on broken package nlopt-2.4.2
    "RcmdrPlugin_DoE" # depends on broken package nlopt-2.4.2
    "RcmdrPlugin_EACSPIR" # depends on broken package nlopt-2.4.2
    "RcmdrPlugin_EBM" # depends on broken package nlopt-2.4.2
    "RcmdrPlugin_EZR" # depends on broken package nlopt-2.4.2
    "RcmdrPlugin_EcoVirtual" # depends on broken package nlopt-2.4.2
    "RcmdrPlugin_Export" # depends on broken package car
    "RcmdrPlugin_FactoMineR" # depends on broken package nlopt-2.4.2
    "RcmdrPlugin_HH" # depends on broken package nlopt-2.4.2
    "RcmdrPlugin_IPSUR" # depends on broken package nlopt-2.4.2
    "RcmdrPlugin_KMggplot2" # depends on broken package nlopt-2.4.2
    "RcmdrPlugin_MA" # depends on broken package nlopt-2.4.2
    "RcmdrPlugin_MPAStats" # depends on broken package nlopt-2.4.2
    "RcmdrPlugin_NMBU" # depends on broken package nlopt-2.4.2
    "RcmdrPlugin_RMTCJags" # depends on broken package nlopt-2.4.2
    "RcmdrPlugin_ROC" # depends on broken package nlopt-2.4.2
    "RcmdrPlugin_SCDA" # depends on broken package nlopt-2.4.2
    "RcmdrPlugin_SLC" # depends on broken package nlopt-2.4.2
    "RcmdrPlugin_SM" # depends on broken package nlopt-2.4.2
    "RcmdrPlugin_TeachingDemos" # depends on broken package nlopt-2.4.2
    "RcmdrPlugin_UCA" # depends on broken package nlopt-2.4.2
    "RcmdrPlugin_coin" # depends on broken package nlopt-2.4.2
    "RcmdrPlugin_depthTools" # depends on broken package nlopt-2.4.2
    "RcmdrPlugin_doex" # depends on broken package nlopt-2.4.2
    "RcmdrPlugin_epack" # depends on broken package nlopt-2.4.2
    "RcmdrPlugin_lfstat" # depends on broken package nlopt-2.4.2
    "RcmdrPlugin_mosaic" # depends on broken package nlopt-2.4.2
    "RcmdrPlugin_orloca" # depends on broken package nlopt-2.4.2
    "RcmdrPlugin_plotByGroup" # depends on broken package nlopt-2.4.2
    "RcmdrPlugin_pointG" # depends on broken package nlopt-2.4.2
    "RcmdrPlugin_qual" # depends on broken package nlopt-2.4.2
    "RcmdrPlugin_sampling" # depends on broken package nlopt-2.4.2
    "RcmdrPlugin_seeg" # depends on broken package nlopt-2.4.2
    "RcmdrPlugin_sos" # depends on broken package nlopt-2.4.2
    "RcmdrPlugin_steepness" # depends on broken package nlopt-2.4.2
    "RcmdrPlugin_survival" # depends on broken package nlopt-2.4.2
    "RcmdrPlugin_temis" # depends on broken package nlopt-2.4.2
    "Rcpi" # depends on broken package GO_db
    "Rcplex" # Build Is Broken
    "RcppAPT" # Build Is Broken
    "RcppRedis" # build is broken
    "ReactomePA" # depends on broken package DOSE
    "ReportingTools" # depends on broken package AnnotationForge
    "RforProteomics" # depends on broken package Category
    "Rgnuplot"
    "RmiR" # broken build
    "RmiR_Hs_miRNA" # broken build
    "RmiR_hsa" # broken build
    "RnAgilentDesign028282_db" # broken build
    "RnBeads" # depends on broken package FDb_InfiniumMethylation_hg19
    "RnBeads_hg19" # broken build
    "RnBeads_hg38" # broken build
    "RnBeads_mm10" # broken build
    "RnBeads_mm9" # broken build
    "RnBeads_rn5" # broken build
    "RnaSeqTutorial" # broken build
    "RnavGraph" # build is broken
    "Roberts2005Annotation_db" # broken build
    "RockFab" # broken build
    "Rothermel" # broken build
    "Rphylopars" # broken build
    "SCLCBam" # broken build
    "SDD" # broken build
    "SEPA" # depends on broken package org_Hs_eg_db
    "SHDZ_db" # broken build
    "SIFT_Hsapiens_dbSNP132" # broken build
    "SIFT_Hsapiens_dbSNP137" # broken build
    "SLGI" # depends on broken package GO_db
    "SNAGEE" # broken build
    "SNAGEEdata" # broken build
    "SNPhoodData" # broken build
    "SNPlocs_Hsapiens_dbSNP141_GRCh38" # broken build
    "SNPlocs_Hsapiens_dbSNP142_GRCh37" # broken build
    "SNPlocs_Hsapiens_dbSNP144_GRCh37" # broken build
    "SNPlocs_Hsapiens_dbSNP144_GRCh38" # broken build
    "SNPlocs_Hsapiens_dbSNP_20090506" # broken build
    "SNPlocs_Hsapiens_dbSNP_20100427" # broken build
    "SNPlocs_Hsapiens_dbSNP_20101109" # broken build
    "SNPlocs_Hsapiens_dbSNP_20110815" # broken build
    "SNPlocs_Hsapiens_dbSNP_20111119" # broken build
    "SNPlocs_Hsapiens_dbSNP_20120608" # broken build
    "SOD" # depends on broken package cudatoolkit-5.5.22
    "SVM2CRM" # broken build
    "SVM2CRMdata" # broken build
    "ScISI" # depends on broken package apComplex
    "SemDist" # broken build
    "SensMixed" # depends on broken package r-lme4-1.1-9
    "SensoMineR" # depends on broken package car
    "SeqFeatR" # broken build
    "SeqGrapheR" # Build Is Broken
    "SomatiCAData" # broken build
    "SoyNAM" # depends on broken package r-lme4-1.1-8
    "SpikeIn" # broken build
    "Statomica" # broken build
    "Surrogate" # depends on broken package nlopt-2.4.2
    "TBX20BamSubset" # broken build
    "TCGAMethylation450k" # broken build
    "TCGAbiolinks" # depends on broken package r-affy-1.47.1
    "TCGAcrcmRNA" # broken build
    "TDMR" # depends on broken package nlopt-2.4.2
    "TED" # broken build
    "TFBSTools" # depends on broken package CNEr
    "TKF" # broken build
    "TLBC" # depends on broken package car
    "TROM" # depends on broken package GO_db
    "TSMySQL" # broken build
    "TSdist" # broken build
    "TargetScoreData" # broken build
    "TargetSearchData" # broken build
    "TcGSA" # depends on broken package nlopt-2.4.2
    "TextoMineR" # depends on broken package car
    "TransferEntropy" # broken build
    "TriMatch" # depends on broken package car
    "TxDb_Celegans_UCSC_ce6_ensGene" # broken build
    "TxDb_Hsapiens_UCSC_hg19_knownGene" # broken build
    "TxDb_Hsapiens_UCSC_hg38_knownGene" # broken build
    "TxDb_Mmusculus_UCSC_mm9_knownGene" # broken build
    "TxDb_Rnorvegicus_BioMart_igis" # broken build
    "VBmix" # broken build
    "VIM" # depends on broken package car
    "VIMGUI" # depends on broken package nlopt-2.4.2
    "WES_1KG_WUGSC" # broken build
    "WGCNA" # depends on broken package GO_db
    "XtraSNPlocs_Hsapiens_dbSNP141_GRCh38" # broken build
    "XtraSNPlocs_Hsapiens_dbSNP144_GRCh37" # broken build
    "XtraSNPlocs_Hsapiens_dbSNP144_GRCh38" # broken build
    "Zelig" # depends on broken package AER
    "ZeligMultilevel" # depends on broken package nlopt-2.4.2
    "a4" # depends on broken package htmltools
    "a4Base" # broken build
    "a4Reporting" # broken build
    "aLFQ" # depends on broken package nlopt-2.4.2
    "abd" # depends on broken package nloptr
    "adSplit" # broken build
    "adabag" # depends on broken package nloptr
    "adhoc" # depends on broken package htmltools
    "adme16cod_db" # broken build
    "afex" # depends on broken package nlopt-2.4.2
    "affycompData" # broken build
    "affycoretools" # depends on broken package ReportingTools
    "agRee" # depends on broken package nlopt-2.4.2
    "ag_db" # depends on broken package org_At_tair_db
    "algstat" # depends on broken package polynom
    "alr3" # depends on broken package nlopt-2.4.2
    "alr4" # depends on broken package nlopt-2.4.2
    "alsace" # depends on broken nloptr-1.0.4
    "alsace" # depends on broken package nloptr
    "anacor" # depends on broken package nlopt-2.4.2
    "annaffy" # broken build
    "annmap" # broken build
    "aods3" # depends on broken package nlopt-2.4.2
    "apComplex" # broken build
    "apaTables" # depends on broken package r-car-2.1-0
    "apt" # depends on broken package nlopt-2.4.2
    "arabidopsis_db0" # broken build
    "arm" # depends on broken package nloptr
    "arrayMvout" # depends on broken package rgl
    "arrayQualityMetrics" # broken build
    "ath1121501_db" # depends on broken package org_At_tair_db
    "attract" # depends on broken package AnnotationForge
    "auRoc" # broken build
    "bamdit" # broken build
    "bapred" # depends on broken package r-lme4-1.1-9
    "bartMachine" # depends on broken package nlopt-2.4.2
    "bayesDem" # depends on broken package nlopt-2.4.2
    "bayesLife" # depends on broken package nloptr
    "bayesPop" # depends on broken package bayesLife
    "bayescount" # broken build
    "bayesmix" # broken build
    "bcrypt" # broken build
    "bdynsys" # depends on broken package nloptr
    "beadarrayExampleData" # broken build
    "bgmm" # depends on broken package nloptr
    "bigGP" # build is broken
    "bioassayR" # broken build
    "biotools" # broken build
    "birte" # build is broken
    "blimaTestingData" # broken build
    "blme" # depends on broken package nlopt-2.4.2
    "blmeco" # depends on broken package nlopt-2.4.2
    "blowtorch" # broken build
    "bmd" # depends on broken package nlopt-2.4.2
    "bmem" # depends on broken package nlopt-2.4.2
    "bmeta" # depends on broken package R2jags
    "bootnet" # depends on broken package nlopt-2.4.2
    "boral" # depends on broken package R2jags
    "boss" # depends on broken package nlopt-2.4.2
    "bovine_db" # broken build
    "bovine_db0" # broken build
    "brainGraph" # broken build
    "breastCancerMAINZ" # broken build
    "breastCancerNKI" # broken build
    "breastCancerTRANSBIG" # broken build
    "breastCancerUNT" # broken build
    "breastCancerUPP" # broken build
    "breastCancerVDX" # broken build
    "brms" # depends on broken package htmltools
    "bronchialIL13" # broken build
    "bsseqData" # broken build
    "cAIC4" # depends on broken package nlopt-2.4.2
    "cMap2data" # broken build
    "canceR" # depends on broken package Category
    "cancerdata" # broken build
    "candisc" # depends on broken package nlopt-2.4.2
    "canine_db0" # broken build
    "caninecdf" # broken build
    "car" # depends on broken package nloptr
    "carcass" # depends on broken package nlopt-2.4.2
    "caret" # depends on broken package car
    "caretEnsemble" # depends on broken package car
    "categoryCompare" # depends on broken package AnnotationForge
    "ccTutorial" # broken build
    "celegans_db" # broken build
    "cellHTS2" # depends on broken package Category
    "ceu1kg" # broken build
    "ceu1kgv" # broken build
    "ceuhm3" # broken build
    "cgdv17" # broken build
    "cghMCR" # broken build
    "charmData" # broken build
    "cheung2010" # broken build
    "chicken_db0" # broken build
    "chimera" # depends on broken package BSgenome_Hsapiens_UCSC_hg19
    "chipPCR" # depends on broken nloptr-1.0.4
    "chipPCR" # depends on broken package nloptr
    "chipenrich" # build is broken
    "chipenrich_data" # broken build
    "chopsticks" # broken build
    "classify" # depends on broken package R2jags
    "cleanUpdTSeq" # depends on broken package BSgenome_Drerio_UCSC_danRer7
    "climwin" # depends on broken package nlopt-2.4.2
    "clpAPI" # build is broken
    "clusterPower" # depends on broken package nlopt-2.4.2
    "clusterProfiler" # broken build
    "clusterSEs" # depends on broken AER-1.2-4
    "clusterSEs" # depends on broken package AER
    "coRNAi" # depends on broken package Category
    "coefplot" # broken build
    "colorscience"
    "colorscience" # depends on broken package munsellinterpol
    "compEpiTools" # broken build
    "compendiumdb" # broken build
    "conformal" # depends on broken package nlopt-2.4.2
    "conumee" # broken build
    "corHMM" # depends on broken package nlopt-2.4.2
    "cosmiq" # depends on broken package xcms
    "covmat" # depends on broken package r-VIM-4.4.1
    "cpgen" # depends on broken package r-pedigreemm-0.3-3
    "cplexAPI" # build is broken
    "crmPack" # broken build
    "ctsem" # depends on broken package r-OpenMx-2.2.6
    "cudaBayesreg" # build is broken
    "curatedBladderData" # broken build
    "curatedBreastData" # broken build
    "curatedCRCData" # broken build
    "curatedOvarianData" # broken build
    "curvHDR" # broken build
    "cytofkit" # broken build
    "dagLogo" # depends on broken package motifStack
    "dagbag" # build is broken
    "datafsm" # depends on broken package r-caret-6.0-52
    "davidTiling" # broken build
    "dbConnect" # broken build
    "demography" # broken build
    "derfinderData" # broken build
    "difR" # depends on broken package nlopt-2.4.2
    "diggitdata" # broken build
    "diveRsity" # depends on broken package nlopt-2.4.2
    "doMPI" # build is broken
    "dpa" # depends on broken package nlopt-2.4.2
    "dpcR" # depends on broken nloptr-1.0.4
    "dpcR" # depends on broken package nloptr
    "drc" # depends on broken package car
    "dressCheck" # broken build
    "drfit" # depends on broken package nlopt-2.4.2
    "drosgenome1_db" # broken build
    "drosophila2_db" # broken build
    "drosophila2cdf" # broken build
    "drsmooth" # depends on broken package nlopt-2.4.2
    "dsQTL" # broken build
    "dupRadar" # depends on broken package r-Rsubread-1.19.5
    "dyebiasexamples" # broken build
    "dynlm" # depends on broken package car
    "easyanova" # depends on broken package nlopt-2.4.2
    "ecd" # depends on broken package polynom
    "ecoliLeucine" # broken build
    "edge" # depends on broken package nlopt-2.4.2
    "eeptools" # depends on broken package nlopt-2.4.2
    "effects" # depends on broken package nloptr
    "eiR" # depends on broken package ChemmineR
    "eisa" # depends on broken package Category
    "encoDnaseI" # broken build
    "episplineDensity" # depends on broken package nlopt-2.4.2
    "epr" # depends on broken package nlopt-2.4.2
    "erer" # depends on broken package car
    "erma" # broken build
    "erma" # depends on broken GenomicFiles-1.5.4
    "estrogen" # broken build
    "evobiR" # broken build
    "exomePeak" # broken build
    "extRemes" # depends on broken package car
    "ez" # depends on broken package car
    "facopy" # depends on broken package nlopt-2.4.2
    "facopy_annot" # broken build
    "facsDorit" # broken build
    "faoutlier" # depends on broken package nlopt-2.4.2
    "fastLiquidAssociation" # depends on broken package LiquidAssociation
    "fastR" # depends on broken package nlopt-2.4.2
    "ffpe" # depends on broken package FDb_InfiniumMethylation_hg19
    "ffpeExampleData" # broken build
    "fishmethods" # depends on broken package nloptr
    "flagme" # depends on broken package CAMERA
    "flowBeads" # broken build
    "flowBin" # broken build
    "flowCHIC" # broken build
    "flowClean" # broken build
    "flowClust" # depends on broken package flowCore
    "flowCore" # broken build
    "flowDensity" # depends on broken package nlopt-2.4.2
    "flowDiv" # depends on broken package flowCore
    "flowFP" # depends on broken package flowCore
    "flowFit" # broken build
    "flowFitExampleData" # broken build
    "flowMatch" # broken build
    "flowMeans" # depends on broken package flowCore
    "flowMerge" # depends on broken package flowCore
    "flowPeaks" # build is broken
    "flowQ" # build is broken
    "flowQB" # broken build
    "flowStats" # depends on broken package flowCore
    "flowTrans" # broken build
    "flowType" # depends on broken package flowCore
    "flowUtils" # depends on broken package flowCore
    "flowVS" # depends on broken package flowCore
    "flowViz" # depends on broken package flowCore
    "flowWorkspace" # depends on broken package flowCore
    "flowWorkspaceData" # broken build
    "fly_db0" # broken build
    "fmcsR" # depends on broken package ChemmineR
    "freqweights" # depends on broken package nlopt-2.4.2
    "fscaret" # depends on broken package nlopt-2.4.2
    "funcy" # depends on broken package car
    "fxregime" # depends on broken package nlopt-2.4.2
    "gCMAP" # depends on broken package Category
    "gCMAPWeb" # depends on broken package Category
    "gahgu133acdf" # broken build
    "gahgu133bcdf" # broken build
    "gahgu133plus2cdf" # broken build
    "gahgu95av2cdf" # broken build
    "gahgu95bcdf" # broken build
    "gahgu95ccdf" # broken build
    "gahgu95dcdf" # broken build
    "gahgu95ecdf" # broken build
    "gamclass" # depends on broken package nlopt-2.4.2
    "gamm4" # depends on broken package nloptr
    "gcmr" # depends on broken package nlopt-2.4.2
    "gcspikelite" # broken build
    "geneLenDataBase" # broken build
    "genomationData" # broken build
    "genomewidesnp5Crlmm" # broken build
    "genomewidesnp6Crlmm" # broken build
    "genridge" # depends on broken package nlopt-2.4.2
    "gespeR" # depends on broken package Category
    "geuvPack" # broken build
    "geuvStore" # broken build
    "ggtut" # depends on broken package cheung2010
    "gimme" # depends on broken package nlopt-2.4.2
    "gmatrix" # depends on broken package cudatoolkit-5.5.22
    "goProfiles" # broken build
    "goTools" # broken build
    "golubEsets" # broken build
    "goseq" # depends on broken package geneLenDataBase
    "gplm" # depends on broken package nlopt-2.4.2
    "gputools" # depends on broken package cudatoolkit-5.5.22
    "granova" # depends on broken package nlopt-2.4.2
    "graphicalVAR" # depends on broken package nlopt-2.4.2
    "gridGraphics" # broken build
    "grndata" # broken build
    "gwascat" # depends on broken package GO_db
    "h10kcod_db" # broken build
    "h20kcod_db" # broken build
    "h5" # build is broken
    "h5vc" # broken build
    "h5vcData" # broken build
    "hapmap100khind" # broken build
    "hapmap100kxba" # broken build
    "hapmap370k" # broken build
    "hapmap500knsp" # broken build
    "hapmap500ksty" # broken build
    "hapmapsnp5" # broken build
    "hapmapsnp6" # broken build
    "harbChIP" # broken build
    "hbsae" # depends on broken package nlopt-2.4.2
    "hcg110_db" # broken build
    "healthyFlowData" # broken build
    "heplots" # depends on broken package car
    "hgfocus_db" # broken build
    "hgu133a2_db" # broken build
    "hgu133a2frmavecs" # broken build
    "hgu133a_db" # broken build
    "hgu133afrmavecs" # broken build
    "hgu133b_db" # broken build
    "hgu133plus2_db" # broken build
    "hgu133plus2frmavecs" # broken build
    "hgu219_db" # broken build
    "hgu95a_db" # broken build
    "hgu95aprobe" # broken build
    "hgu95av2" # broken build
    "hgu95av2_db" # broken build
    "hgu95b_db" # broken build
    "hgu95c_db" # broken build
    "hgu95d_db" # broken build
    "hgu95dprobe" # broken build
    "hgu95e_db" # broken build
    "hguDKFZ31_db" # broken build
    "hguatlas13k_db" # broken build
    "hgubeta7_db" # broken build
    "hgug4100a_db" # broken build
    "hgug4101a_db" # broken build
    "hgug4110b_db" # broken build
    "hgug4111a_db" # broken build
    "hgug4112a_db" # broken build
    "hgug4845a_db" # broken build
    "hguqiagenv3_db" # broken build
    "hi16cod_db" # broken build
    "hierGWAS"
    "highriskzone"
    "hmyriB36" # broken build
    "hom_At_inp_db" # broken build
    "hom_Ce_inp_db" # broken build
    "hom_Dm_inp_db" # broken build
    "hom_Dr_inp_db" # broken build
    "hom_Hs_inp_db" # broken build
    "hom_Mm_inp_db" # broken build
    "hom_Rn_inp_db" # broken build
    "hs25kresogen_db" # broken build
    "hta20stprobeset_db" # broken build
    "hta20sttranscriptcluster_db" # broken build
    "hthgu133a_db" # broken build
    "hthgu133afrmavecs" # broken build
    "hthgu133b_db" # broken build
    "hu35ksuba_db" # broken build
    "hu35ksubb_db" # broken build
    "hu35ksubc_db" # broken build
    "hu35ksubd_db" # broken build
    "hu6800_db" # broken build
    "huex10stprobeset_db" # broken build
    "huex10sttranscriptcluster_db" # broken build
    "huex_1_0_st_v2frmavecs" # broken build
    "hugene10stprobeset_db" # broken build
    "hugene10sttranscriptcluster_db" # broken build
    "hugene10stv1probe" # broken build
    "hugene11stprobeset_db" # broken build
    "hugene11sttranscriptcluster_db" # broken build
    "hugene20stprobeset_db" # broken build
    "hugene20sttranscriptcluster_db" # broken build
    "hugene21stprobeset_db" # broken build
    "hugene21sttranscriptcluster_db" # broken build
    "hugene_1_0_st_v1frmavecs" # broken build
    "human1mduov3bCrlmm" # broken build
    "human1mv1cCrlmm" # broken build
    "human370quadv3cCrlmm" # broken build
    "human370v1cCrlmm" # broken build
    "human550v3bCrlmm" # broken build
    "human610quadv1bCrlmm" # broken build
    "human650v3aCrlmm" # broken build
    "human660quadv1aCrlmm" # broken build
    "humanStemCell" # broken build
    "human_db0" # broken build
    "humancytosnp12v2p1hCrlmm" # broken build
    "humanomni1quadv1bCrlmm" # broken build
    "humanomni25quadv1bCrlmm" # broken build
    "humanomni5quadv1bCrlmm" # broken build
    "humanomniexpress12v1bCrlmm" # broken build
    "hwgcod_db" # broken build
    "hwwntest" # depends on broken package polynom
    "hysteresis" # depends on broken package nlopt-2.4.2
    "iCheck" # depends on broken package FDb_InfiniumMethylation_hg19
    "iClick" # depends on broken package nloptr
    "ibd" # depends on broken package nlopt-2.4.2
    "iccbeta" # depends on broken package nlopt-2.4.2
    "ifaTools" # depends on broken package r-OpenMx-2.2.6
    "ilc" # depends on broken package demography
    "illuminaHumanWGDASLv3_db" # broken build
    "illuminaHumanWGDASLv4_db" # broken build
    "illuminaHumanv1_db" # broken build
    "illuminaHumanv2BeadID_db" # broken build
    "illuminaHumanv2_db" # broken build
    "illuminaHumanv3_db" # broken build
    "illuminaHumanv4_db" # broken build
    "illuminaMousev1_db" # broken build
    "illuminaMousev1p1_db" # broken build
    "illuminaMousev2_db" # broken build
    "illuminaRatv1_db" # broken build
    "imageHTS" # depends on broken package Category
    "imager" # broken build
    "immunoClust" # build is broken
    "imputeR" # depends on broken package nlopt-2.4.2
    "in2extRemes" # depends on broken package nlopt-2.4.2
    "inSilicoMerging" # build is broken
    "ind1KG" # broken build
    "indac_db" # broken build
    "inferference" # depends on broken package nlopt-2.4.2
    "influence_ME" # depends on broken package nlopt-2.4.2
    "interactiveDisplay" # depends on broken package Category
    "interplot" # depends on broken arm-1.8-5
    "interplot" # depends on broken package arm
    "iptools"
    "iterpc" # depends on broken package polynom
    "ivpack" # depends on broken package nlopt-2.4.2
    "jetset"
    "jetset" # broken build
    "joda" # depends on broken package nlopt-2.4.2
    "jomo" # build is broken
    "keggorthology" # broken build
    "kidpack" # broken build
    "ldamatch" # depends on broken package polynom
    "learnstats" # depends on broken package nlopt-2.4.2
    "leeBamViews" # broken build
    "lefse" # build is broken
    "lmSupport" # depends on broken package nlopt-2.4.2
    "lme4" # depends on broken package nloptr
    "lmerTest" # depends on broken package nloptr
    "longpower" # depends on broken package nlopt-2.4.2
    "lumi" # depends on broken package FDb_InfiniumMethylation_hg19
    "lumiBarnes" # broken build
    "lumiHumanAll_db" # broken build
    "lumiHumanIDMapping" # broken build
    "lumiMouseAll_db" # broken build
    "lumiMouseIDMapping" # broken build
    "lumiRatAll_db" # broken build
    "lumiRatIDMapping" # broken build
    "m10kcod_db" # broken build
    "m20kcod_db" # broken build
    "mAPKL" # build is broken
    "mBvs" # broken build
    "maGUI" # depends on broken package AnnotationForge
    "maPredictDSC" # depends on broken package nlopt-2.4.2
    "maizeprobe" # broken build
    "mammaPrintData" # broken build
    "maqcExpression4plex" # broken build
    "marked" # depends on broken package nlopt-2.4.2
    "mbest" # depends on broken package nlopt-2.4.2
    "mdgsa" # depends on broken package GO_db
    "meboot" # depends on broken package nlopt-2.4.2
    "medflex" # depends on broken package r-car-2.1-0
    "mediation" # depends on broken package r-lme4-1.1-8
    "merTools" # depends on broken package r-arm-1.8-6
    "meshr" # depends on broken package Category
    "meta4diag" # broken build
    "metaMS" # depends on broken package CAMERA
    "metaMSdata" # broken build
    "metaMix" # build is broken
    "metaX" # depends on broken package r-CAMERA-1.25.2
    "metacom" # broken build
    "metagear" # build is broken
    "metaplus" # depends on broken package nlopt-2.4.2
    "methyAnalysis" # depends on broken package FDb_InfiniumMethylation_hg19
    "methylumi" # depends on broken package FDb_InfiniumMethylation_hg19
    "mgu74a_db" # broken build
    "mgu74av2_db" # broken build
    "mgu74b_db" # broken build
    "mgu74bv2_db" # broken build
    "mgu74c_db" # broken build
    "mgu74cv2_db" # broken build
    "mguatlas5k_db" # broken build
    "mgug4104a_db" # broken build
    "mgug4120a_db" # broken build
    "mgug4121a_db" # broken build
    "mgug4122a_db" # broken build
    "mi" # depends on broken package arm
    "mi16cod_db" # broken build
    "miRNATarget" # broken build
    "miRNAtap_db" # broken build
    "miRcomp" # broken build
    "miRcompData" # broken build
    "micEconAids" # depends on broken package nlopt-2.4.2
    "micEconCES" # depends on broken package nlopt-2.4.2
    "micEconSNQP" # depends on broken package nlopt-2.4.2
    "miceadds" # depends on broken package car
    "migui" # depends on broken package nlopt-2.4.2
    "minfiData" # depends on broken package IlluminaHumanMethylation450kanno_ilmn12_hg19
    "minionSummaryData" # broken build
    "mirIntegrator" # broken build
    "missDeaths"
    "missMDA" # depends on broken package nlopt-2.4.2
    "missMethyl" # depends on broken package FDb_InfiniumMethylation_hg19
    "mitoODE" # broken build
    "mitoODEdata" # broken build
    "mixAK" # depends on broken package nlopt-2.4.2
    "mixlm" # depends on broken package car
    "mlVAR" # depends on broken package nlopt-2.4.2
    "mlmRev" # depends on broken package nlopt-2.4.2
    "mm24kresogen_db" # broken build
    "moe430a_db" # broken build
    "moe430b_db" # broken build
    "moex10stprobeset_db" # broken build
    "moex10sttranscriptcluster_db" # broken build
    "mogene10stprobeset_db" # broken build
    "mogene10sttranscriptcluster_db" # broken build
    "mogene10stv1probe" # broken build
    "mogene11stprobeset_db" # broken build
    "mogene11sttranscriptcluster_db" # broken build
    "mogene20stprobeset_db" # broken build
    "mogene20sttranscriptcluster_db" # broken build
    "mogene21stprobeset_db" # broken build
    "mogene21sttranscriptcluster_db" # broken build
    "mogene_1_0_st_v1frmavecs" # broken build
    "mongolite" # build is broken
    "monocle" # depends on broken package HSMMSingleCell
    "monogeneaGM" # broken build
    "mosaic" # depends on broken package car
    "mosaicsExample" # broken build
    "motifRG" # depends on broken package BSgenome_Hsapiens_UCSC_hg19
    "motifStack" # broken build
    "motifStack" # broken build
    "motifbreakR" # depends on broken package r-BSgenome-1.37.5
    "mouse4302_db" # broken build
    "mouse4302frmavecs" # broken build
    "mouse430a2_db" # broken build
    "mouse430a2frmavecs" # broken build
    "mouse_db0" # broken build
    "mpedbarray_db" # broken build
    "mpoly" # depends on broken package polynom
    "msdata" # broken build
    "msmsEDA" # depends on broken package MSnbase
    "msmsTests" # depends on broken package MSnbase
    "mta10stprobeset_db" # broken build
    "mta10sttranscriptcluster_db" # broken build
    "mtbls2" # broken build
    "mu11ksuba_db" # broken build
    "mu11ksubb_db" # broken build
    "mu19ksuba_db" # broken build
    "mu19ksubb_db" # broken build
    "mu19ksubc_db" # broken build
    "multiDimBio" # depends on broken package nlopt-2.4.2
    "muma" # depends on broken package nlopt-2.4.2
    "munsellinterpol"
    "munsellinterpol" # broken build
    "munsellinterpol" # broken build
    "mutossGUI" # build is broken
    "mvGST" # depends on broken package AnnotationForge
    "mvMORPH" # broken build
    "mvinfluence" # depends on broken package nlopt-2.4.2
    "mvoutData" # broken build
    "mwgcod_db" # broken build
    "nCal" # depends on broken package nlopt-2.4.2
    "ncdfFlow" # depends on broken package flowCore
    "netbenchmark" # build is broken
    "netresponse" # broken build
    "nloptr" # broken build
    "nloptr" # broken build
    "nlts" # broken build
    "nonrandom" # depends on broken package nlopt-2.4.2
    "npIntFactRep" # depends on broken package nlopt-2.4.2
    "nugohs1a520180_db" # broken build
    "nugomm1a520177_db" # broken build
    "oligoData" # broken build
    "omics" # depends on broken package nloptr
    "oneChannelGUI" # depends on broken package BSgenome_Hsapiens_UCSC_hg19
    "openCyto" # depends on broken package flowCore
    "openssl" # broken build
    "ordBTL" # depends on broken package nlopt-2.4.2
    "ordPens" # depends on broken package r-lme4-1.1-9
    "org_At_tair_db" # broken build
    "org_Bt_eg_db" # broken build
    "org_Ce_eg_db" # broken build
    "org_Dm_eg_db" # broken build
    "org_Dr_eg_db" # broken build
    "org_Hs_eg_db" # broken build
    "org_Hs_ipi_db" # broken build
    "org_Mm_eg_db" # broken build
    "org_Mmu_eg_db" # broken build
    "org_Pt_eg_db" # broken build
    "org_Rn_eg_db" # broken build
    "org_Sc_sgd_db" # broken build
    "org_Ss_eg_db" # broken build
    "pRoloc" # depends on broken package car
    "pRolocGUI" # depends on broken package nlopt-2.4.2
    "pRolocdata" # broken build
    "pacman" # broken build
    "pamm" # depends on broken package nlopt-2.4.2
    "panelAR" # depends on broken package nlopt-2.4.2
    "papeR" # depends on broken package nlopt-2.4.2
    "parathyroidSE" # broken build
    "parboost" # depends on broken package nlopt-2.4.2
    "parma" # depends on broken package nlopt-2.4.2
    "pasillaBamSubset" # broken build
    "pathview" # depends on broken package org_Hs_eg_db
    "paxtoolsr" # broken build
    "pbkrtest" # depends on broken package nloptr
    "pcaBootPlot" # depends on broken FactoMineR-1.31.3
    "pcaBootPlot" # depends on broken package car
    "pcaGoPromoter_Hs_hg19" # broken build
    "pcaGoPromoter_Mm_mm9" # broken build
    "pcaGoPromoter_Rn_rn4" # broken build
    "pcaL1" # build is broken
    "pd_081229_hg18_promoter_medip_hx1" # broken build
    "pd_aragene_1_0_st" # broken build
    "pd_aragene_1_1_st" # broken build
    "pd_atdschip_tiling" # broken build
    "pd_bovgene_1_0_st" # broken build
    "pd_bovgene_1_1_st" # broken build
    "pd_cangene_1_0_st" # broken build
    "pd_cangene_1_1_st" # broken build
    "pd_canine" # broken build
    "pd_canine_2" # broken build
    "pd_celegans" # broken build
    "pd_chicken" # broken build
    "pd_chigene_1_0_st" # broken build
    "pd_chigene_1_1_st" # broken build
    "pd_chogene_2_0_st" # broken build
    "pd_chogene_2_1_st" # broken build
    "pd_citrus" # broken build
    "pd_cotton" # broken build
    "pd_cyngene_1_0_st" # broken build
    "pd_cyngene_1_1_st" # broken build
    "pd_cyrgene_1_0_st" # broken build
    "pd_cyrgene_1_1_st" # broken build
    "pd_cytogenetics_array" # broken build
    "pd_drogene_1_0_st" # broken build
    "pd_drogene_1_1_st" # broken build
    "pd_drosophila_2" # broken build
    "pd_e_coli_2" # broken build
    "pd_elegene_1_0_st" # broken build
    "pd_elegene_1_1_st" # broken build
    "pd_equgene_1_0_st" # broken build
    "pd_equgene_1_1_st" # broken build
    "pd_feinberg_hg18_me_hx1" # broken build
    "pd_feinberg_mm8_me_hx1" # broken build
    "pd_felgene_1_0_st" # broken build
    "pd_felgene_1_1_st" # broken build
    "pd_fingene_1_0_st" # broken build
    "pd_fingene_1_1_st" # broken build
    "pd_genomewidesnp_5" # broken build
    "pd_genomewidesnp_6" # broken build
    "pd_guigene_1_0_st" # broken build
    "pd_guigene_1_1_st" # broken build
    "pd_hg_u133_plus_2" # broken build
    "pd_hg_u133a" # broken build
    "pd_hg_u133b" # broken build
    "pd_hg_u219" # broken build
    "pd_hg_u95a" # broken build
    "pd_hg_u95d" # broken build
    "pd_ht_hg_u133a" # broken build
    "pd_hta_2_0" # broken build
    "pd_huex_1_0_st_v2" # broken build
    "pd_hugene_1_0_st_v1" # broken build
    "pd_hugene_1_1_st_v1" # broken build
    "pd_hugene_2_0_st" # broken build
    "pd_hugene_2_1_st" # broken build
    "pd_mapping250k_nsp" # broken build
    "pd_mapping250k_sty" # broken build
    "pd_mapping50k_hind240" # broken build
    "pd_mapping50k_xba240" # broken build
    "pd_margene_1_0_st" # broken build
    "pd_margene_1_1_st" # broken build
    "pd_medgene_1_0_st" # broken build
    "pd_medgene_1_1_st" # broken build
    "pd_medicago" # broken build
    "pd_moe430b" # broken build
    "pd_moex_1_0_st_v1" # broken build
    "pd_mogene_1_0_st_v1" # broken build
    "pd_mogene_1_1_st_v1" # broken build
    "pd_mogene_2_0_st" # broken build
    "pd_mogene_2_1_st" # broken build
    "pd_mta_1_0" # broken build
    "pd_mu11ksuba" # broken build
    "pd_nugo_mm1a520177" # broken build
    "pd_ovigene_1_0_st" # broken build
    "pd_ovigene_1_1_st" # broken build
    "pd_plasmodium_anopheles" # broken build
    "pd_poplar" # broken build
    "pd_porgene_1_0_st" # broken build
    "pd_porgene_1_1_st" # broken build
    "pd_rabgene_1_0_st" # broken build
    "pd_rabgene_1_1_st" # broken build
    "pd_raex_1_0_st_v1" # broken build
    "pd_ragene_1_0_st_v1" # broken build
    "pd_ragene_1_1_st_v1" # broken build
    "pd_ragene_2_0_st" # broken build
    "pd_ragene_2_1_st" # broken build
    "pd_rcngene_1_0_st" # broken build
    "pd_rcngene_1_1_st" # broken build
    "pd_rhegene_1_0_st" # broken build
    "pd_rhegene_1_1_st" # broken build
    "pd_rhesus" # broken build
    "pd_rice" # broken build
    "pd_rjpgene_1_0_st" # broken build
    "pd_rjpgene_1_1_st" # broken build
    "pd_rta_1_0" # broken build
    "pd_rusgene_1_0_st" # broken build
    "pd_rusgene_1_1_st" # broken build
    "pd_soybean" # broken build
    "pd_soygene_1_0_st" # broken build
    "pd_soygene_1_1_st" # broken build
    "pd_u133_x3p" # broken build
    "pd_vitis_vinifera" # broken build
    "pd_wheat" # broken build
    "pd_x_tropicalis" # broken build
    "pd_zebgene_1_0_st" # broken build
    "pd_zebgene_1_1_st" # broken build
    "pd_zebrafish" # broken build
    "pedbarrayv10_db" # broken build
    "pedbarrayv9_db" # broken build
    "pedigreemm" # depends on broken package nloptr
    "pequod" # depends on broken package nlopt-2.4.2
    "pglm" # depends on broken package car
    "phastCons100way_UCSC_hg19" # broken build
    "phastCons100way_UCSC_hg38" # broken build
    "phastCons7way_UCSC_hg38" # broken build
    "phenoTest" # depends on broken package Category
    "phia" # depends on broken package nlopt-2.4.2
    "phylocurve" # depends on broken package nlopt-2.4.2
    "piecewiseSEM" # depends on broken package nloptr
    "pig_db0" # broken build
    "plateCore" # depends on broken package flowCore
    "plfMA" # broken build
    "plm" # depends on broken package car
    "plsRbeta" # depends on broken package nlopt-2.4.2
    "plsRcox" # depends on broken package nlopt-2.4.2
    "plsRglm" # depends on broken package car
    "pmclust" # build is broken
    "pmm" # depends on broken package nlopt-2.4.2
    "polynom" # broken build
    "polynom" # broken build
    "pomp" # depends on broken package nlopt-2.4.2
    "porcine_db" # broken build
    "ppiPre" # depends on broken package GO_db
    "ppiStats" # depends on broken package Category
    "prLogistic" # depends on broken package nlopt-2.4.2
    "prebsdata" # broken build
    "predictmeans" # depends on broken package nlopt-2.4.2
    "preprocomb" # depends on broken package car
    "proteoQC" # depends on broken package MSnbase
    "ptw" # depends on broken nloptr-1.0.4
    "pumadata" # broken build
    "pvca" # depends on broken package nlopt-2.4.2
    "qtlnet" # depends on broken package nlopt-2.4.2
    "quantification" # depends on broken package nlopt-2.4.2
    "r10kcod_db" # broken build
    "rCGH" # depends on broken package r-affy-1.47.1
    "rDEA" # build is broken
    "rJPSGCS" # depends on broken package chopsticks
    "rLindo" # build is broken
    "rMAT" # build is broken
    "rRDPData" # broken build
    "rTRMui" # depends on broken package org_Hs_eg_db
    "rTableICC" # broken build
    "rUnemploymentData" # broken build
    "rae230a_db" # broken build
    "rae230b_db" # broken build
    "raex10stprobeset_db" # broken build
    "raex10sttranscriptcluster_db" # broken build
    "ragene10stprobeset_db" # broken build
    "ragene10sttranscriptcluster_db" # broken build
    "ragene11stprobeset_db" # broken build
    "ragene11sttranscriptcluster_db" # broken build
    "ragene20stprobeset_db" # broken build
    "ragene20sttranscriptcluster_db" # broken build
    "ragene21stprobeset_db" # broken build
    "ragene21sttranscriptcluster_db" # broken build
    "raincpc" # build is broken
    "rainfreq" # build is broken
    "rasclass" # depends on broken package nlopt-2.4.2
    "rat2302_db" # broken build
    "rat_db0" # broken build
    "rbundler" # broken build
    "rcellminer" # broken build
    "rcellminerData" # broken build
    "rcrypt" # broken build
    "rdd" # depends on broken package AER
    "rddtools" # depends on broken package r-AER-1.2-4
    "reactome_db" # broken build
    "recluster" # broken build
    "referenceIntervals" # depends on broken package nlopt-2.4.2
    "refund" # depends on broken package nloptr
    "refund_shiny" # depends on broken package r-refund-0.1-13
    "regRSM" # broken build
    "rgsepd" # depends on broken package geneLenDataBase
    "rgu34a_db" # broken build
    "rgu34b_db" # broken build
    "rgu34c_db" # broken build
    "rguatlas4k_db" # broken build
    "rgug4105a_db" # broken build
    "rgug4130a_db" # broken build
    "rgug4131a_db" # broken build
    "rheumaticConditionWOLLBOLD" # broken build
    "ri16cod_db" # broken build
    "rmgarch" # depends on broken package nlopt-2.4.2
    "rminer" # depends on broken package nlopt-2.4.2
    "rmumps" # broken build
    "rnu34_db" # broken build
    "robustlmm" # depends on broken package nlopt-2.4.2
    "rockchalk" # depends on broken package car
    "rols" # build is broken
    "rpubchem" # depends on broken package nlopt-2.4.2
    "rr" # depends on broken package nlopt-2.4.2
    "rtu34_db" # broken build
    "rugarch" # depends on broken package nloptr
    "rwgcod_db" # broken build
    "ryouready" # depends on broken package nlopt-2.4.2
    "sampleSelection" # depends on broken package car
    "sdcMicro" # depends on broken package car
    "sdcMicroGUI" # depends on broken package nlopt-2.4.2
    "seeg" # depends on broken package car
    "semGOF" # depends on broken package nlopt-2.4.2
    "semPlot" # depends on broken package nlopt-2.4.2
    "semdiag" # depends on broken package nlopt-2.4.2
    "seq2pathway" # broken build
    "seq2pathway_data" # broken build
    "seqCNA" # broken build
    "seqCNA_annot" # broken build
    "seqHMM" # depends on broken package nloptr
    "seqTools" # build is broken
    "seqc" # broken build
    "seventyGeneData" # broken build
    "shinyMethylData" # broken build
    "simPop" # depends on broken package r-VIM-4.4.1
    "simr" # depends on broken package nloptr
    "sjPlot" # depends on broken package nlopt-2.4.2
    "skewr" # depends on broken package FDb_InfiniumMethylation_hg19
    "sortinghat" # broken build
    "spacom" # depends on broken package nlopt-2.4.2
    "spade" # broken build
    "specificity" # depends on broken package nlopt-2.4.2
    "specmine" # depends on broken package CAMERA
    "splm" # depends on broken package car
    "spoccutils" # depends on broken spocc-0.3.0
    "ssmrob" # depends on broken package nlopt-2.4.2
    "stcm" # depends on broken package nlopt-2.4.2
    "stepp" # depends on broken package nlopt-2.4.2
    "stjudem" # broken build
    "stringgaussnet" # depends on broken package GO_db
    "sybilSBML" # build is broken
    "synapter" # depends on broken package MSnbase
    "synapterdata" # broken build
    "synthpop" # depends on broken package coefplot
    "systemPipeR" # depends on broken package AnnotationForge
    "systemPipeRdata" # broken build
    "systemfit" # depends on broken package car
    "tRanslatome" # depends on broken package GO_db
    "tigerstats" # depends on broken package nlopt-2.4.2
    "tmle" # broken build
    "tnam" # depends on broken package nloptr
    "topGO" # depends on broken package GO_db
    "translateSPSS2R" # depends on broken car-2.0-25
    "translateSPSS2R" # depends on broken package car
    "traseR"
    "traseR" # depends on broken package BSgenome_Hsapiens_UCSC_hg19
    "tsoutliers" # depends on broken package polynom
    "tweeDEseqCountData" # broken build
    "u133aaofav2cdf" # broken build
    "u133x3p_db" # broken build
    "u133x3pcdf" # broken build
    "umx" # depends on broken package r-OpenMx-2.2.6
    "userfriendlyscience" # depends on broken package nlopt-2.4.2
    "varComp" # depends on broken package r-lme4-1.1-9
    "variancePartition" # depends on broken package nloptr
    "vows" # depends on broken package nlopt-2.4.2
    "wateRmelon" # depends on broken package FDb_InfiniumMethylation_hg19
    "waveTilingData" # broken build
    "webbioc" # depends on broken package annaffy
    "webp" # broken build
    "wfe" # depends on broken package nlopt-2.4.2
    "wheatprobe" # broken build
    "worm_db0" # broken build
    "x_ent" # broken build
    "xcms" # broken build
    "xcms" # broken build
    "xenopus_db0" # broken build
    "xergm" # depends on broken package nlopt-2.4.2
    "xlaevis2probe" # broken build
    "xps" # build is broken
    "xtropicalisprobe" # broken build
    "yeast2_db" # broken build
    "yeastNagalakshmi" # broken build
    "yeastRNASeq" # broken build
    "yeast_db0" # broken build
    "ygs98_db" # broken build
    "yri1kgv" # broken build
    "zebrafish_db" # broken build
    "zebrafish_db0" # broken build
    "zetadiv" # depends on broken package nlopt-2.4.2
  ];

  otherOverrides = old: new: {
    stringi = old.stringi.overrideDerivation (attrs: {
      postInstall = let
        icuName = "icudt52l";
        icuSrc = pkgs.fetchzip {
          url = "http://static.rexamine.com/packages/${icuName}.zip";
          sha256 = "0hvazpizziq5ibc9017i1bb45yryfl26wzfsv05vk9mc1575r6xj";
          stripRoot = false;
        };
        in ''
          ${attrs.postInstall or ""}
          cp ${icuSrc}/${icuName}.dat $out/library/stringi/libs
        '';
    });

    xml2 = old.xml2.overrideDerivation (attrs: {
      preConfigure = ''
        export LIBXML_INCDIR=${pkgs.libxml2}/include/libxml2
        patchShebangs configure
        '';
    });

    curl = old.curl.overrideDerivation (attrs: {
      preConfigure = "patchShebangs configure";
    });

    RcppArmadillo = old.RcppArmadillo.overrideDerivation (attrs: {
      patchPhase = "patchShebangs configure";
    });

    rpf = old.rpf.overrideDerivation (attrs: {
      patchPhase = "patchShebangs configure";
    });

    BayesXsrc = old.BayesXsrc.overrideDerivation (attrs: {
      patches = [ ./patches/BayesXsrc.patch ];
    });

    rJava = old.rJava.overrideDerivation (attrs: {
      preConfigure = ''
        export JAVA_CPPFLAGS=-I${pkgs.jdk}/include/
        export JAVA_HOME=${pkgs.jdk}
      '';
    });

    JavaGD = old.JavaGD.overrideDerivation (attrs: {
      preConfigure = ''
        export JAVA_CPPFLAGS=-I${pkgs.jdk}/include/
        export JAVA_HOME=${pkgs.jdk}
      '';
    });

    Mposterior = old.Mposterior.overrideDerivation (attrs: {
      PKG_LIBS = "-L${pkgs.openblasCompat}/lib -lopenblas";
    });

    qtbase = old.qtbase.overrideDerivation (attrs: {
      patches = [ ./patches/qtbase.patch ];
    });

    Rmpi = old.Rmpi.overrideDerivation (attrs: {
      configureFlags = [
        "--with-Rmpi-type=OPENMPI"
      ];
    });

    Rmpfr = old.Rmpfr.overrideDerivation (attrs: {
      configureFlags = [
        "--with-mpfr-include=${pkgs.mpfr}/include"
      ];
    });

    RVowpalWabbit = old.RVowpalWabbit.overrideDerivation (attrs: {
      configureFlags = [
        "--with-boost=${pkgs.boost.dev}" "--with-boost-libdir=${pkgs.boost.lib}/lib"
      ];
    });

    RAppArmor = old.RAppArmor.overrideDerivation (attrs: {
      patches = [ ./patches/RAppArmor.patch ];
      LIBAPPARMOR_HOME = "${pkgs.libapparmor}";
    });

    RMySQL = old.RMySQL.overrideDerivation (attrs: {
      patches = [ ./patches/RMySQL.patch ];
      MYSQL_DIR="${pkgs.mysql.lib}";
    });

    devEMF = old.devEMF.overrideDerivation (attrs: {
      NIX_CFLAGS_LINK = "-L${pkgs.xorg.libXft}/lib -lXft";
    });

    slfm = old.slfm.overrideDerivation (attrs: {
      PKG_LIBS = "-L${pkgs.openblasCompat}/lib -lopenblas";
    });

    SamplerCompare = old.SamplerCompare.overrideDerivation (attrs: {
      PKG_LIBS = "-L${pkgs.openblasCompat}/lib -lopenblas";
    });

    gputools = old.gputools.overrideDerivation (attrs: {
      patches = [ ./patches/gputools.patch ];
      CUDA_HOME = "${pkgs.cudatoolkit}";
    });

    gmatrix = old.gmatrix.overrideDerivation (attrs: {
      patches = [ ./patches/gmatrix.patch ];
      CUDA_LIB_PATH = "${pkgs.cudatoolkit}/lib64";
      R_INC_PATH = "${pkgs.R}/lib/R/include";
      CUDA_INC_PATH = "${pkgs.cudatoolkit}/include";
    });

    EMCluster = old.EMCluster.overrideDerivation (attrs: {
      patches = [ ./patches/EMCluster.patch ];
    });

    spMC = old.spMC.overrideDerivation (attrs: {
      patches = [ ./patches/spMC.patch ];
    });

    BayesLogit = old.BayesLogit.overrideDerivation (attrs: {
      patches = [ ./patches/BayesLogit.patch ];
      buildInputs = (attrs.buildInputs or []) ++ [ pkgs.openblasCompat ];
    });

    BayesBridge = old.BayesBridge.overrideDerivation (attrs: {
      patches = [ ./patches/BayesBridge.patch ];
    });

    openssl = old.openssl.overrideDerivation (attrs: {
      OPENSSL_INCLUDES = "${pkgs.openssl}/include";
    });

    Rserve = old.Rserve.overrideDerivation (attrs: {
      patches = [ ./patches/Rserve.patch ];
      configureFlags = [
        "--with-server" "--with-client"
      ];
    });

    nloptr = old.nloptr.overrideDerivation (attrs: {
      configureFlags = [
        "--with-nlopt-cflags=-I${pkgs.nlopt}/include"
        "--with-nlopt-libs='-L${pkgs.nlopt}/lib -lnlopt_cxx -lm'"
      ];
    });

    V8 = old.V8.overrideDerivation (attrs: {
      preConfigure = "export V8_INCLUDES=${pkgs.v8}/include";
    });

  };
in
  self
