/* This file defines the composition for CRAN (R) packages. */

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
    abn = [ pkgs.gsl ];
    adimpro = [ pkgs.imagemagick ];
    audio = [ pkgs.portaudio ];
    BayesSAE = [ pkgs.gsl ];
    BayesVarSel = [ pkgs.gsl ];
    BayesXsrc = [ pkgs.readline pkgs.ncurses ];
    bigGP = [ pkgs.openmpi ];
    BiocCheck = [ pkgs.which ];
    Biostrings = [ pkgs.zlib ];
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
    "a4Classif" # broken build
    "abd" # depends on broken package nlopt-2.4.2
    "Actigraphy" # Build Is Broken
    "adabag" # depends on broken package nlopt-2.4.2
    "ADaCGH2" # depends on broken package tilingArray-1.47.0
    "adhoc" # broken build
    "AER" # depends on broken package nlopt-2.4.2
    "afex" # depends on broken package nlopt-2.4.2
    "agRee" # depends on broken package nlopt-2.4.2
    "aLFQ" # depends on broken package nlopt-2.4.2
    "alr3" # depends on broken package nlopt-2.4.2
    "alr4" # depends on broken package nlopt-2.4.2
    "alsace" # depends on broken nloptr-1.0.4
    "anacor" # depends on broken package nlopt-2.4.2
    "AnnotationHubData" # depends on broken package r-AnnotationForge-1.11.19
    "aods3" # depends on broken package nlopt-2.4.2
    "apaTables" # depends on broken package r-car-2.1-0
    "apt" # depends on broken package nlopt-2.4.2
    "ArfimaMLM" # depends on broken package nlopt-2.4.2
    "arm" # depends on broken package nlopt-2.4.2
    "ART" # depends on broken package ar-car-2.1-0
    "ARTool" # depends on broken package nlopt-2.4.2
    "AtelieR" # broken build
    "AutoModel" # depends on broken package r-car-2.1-0
    "bamsignals" # build is broken
    "bapred" # depends on broken package r-lme4-1.1-9
    "bartMachine" # depends on broken package nlopt-2.4.2
    "bayesDem" # depends on broken package nlopt-2.4.2
    "bayesLife" # depends on broken package nlopt-2.4.2
    "bayesPop" # depends on broken package nlopt-2.4.2
    "Bayesthresh" # depends on broken package nlopt-2.4.2
    "bayou" # broken build
    "baySeq" # broken build
    "BBCAnalyzer" # depends on broken package r-Rsamtools-1.21.18
    "BBRecapture" # depends on broken package nlopt-2.4.2
    "BCA" # depends on broken package nlopt-2.4.2
    "bgmm" # depends on broken package nlopt-2.4.2
    "BIFIEsurvey" # depends on broken package nlopt-2.4.2
    "bigGP" # build is broken
    "BiGGR" # depends on broken package rsbml-2.27.0
    "bigmemoryExtras" # broken build
    "bioassayR" # broken build
    "BiocCheck" # broken build
    "biocViews" # broken build
    "BiodiversityR" # depends on broken package nlopt-2.4.2
    "BioSeqClass" # broken build
    "biotools" # depends on broken package rpanel-1.1-3
    "birte" # build is broken
    "bisectr" # broken build
    "BLCOP" # depends on broken package Rsymphony-0.1-20
    "blmeco" # depends on broken package nlopt-2.4.2
    "blme" # depends on broken package nlopt-2.4.2
    "bmd" # depends on broken package nlopt-2.4.2
    "bmem" # depends on broken package nlopt-2.4.2
    "BMhyd" # broken build
    "bootnet" # depends on broken package nlopt-2.4.2
    "boss" # depends on broken package nlopt-2.4.2
    "BradleyTerry2" # depends on broken package nlopt-2.4.2
    "BrailleR" # broken build
    "BRugs" # build is broken
    "BubbleTree" # depends on broken package r-biovizBase-1.17.2
    "CADFtest" # depends on broken package nlopt-2.4.2
    "cAIC4" # depends on broken package nlopt-2.4.2
    "CAMERA" # depends on broken package mzR-2.3.1
    "candisc" # depends on broken package nlopt-2.4.2
    "carcass" # depends on broken package nlopt-2.4.2
    "car" # depends on broken package nlopt-2.4.2
    "caret" # depends on broken package nlopt-2.4.2
    "caretEnsemble" # depends on broken package nlopt-2.4.2
    "caRpools" # broken build
    "CARrampsOcl" # depends on broken package OpenCL-0.1-3
    "Causata" # broken build
    "CCpop" # depends on broken package nlopt-2.4.2
    "ChainLadder" # depends on broken package nlopt-2.4.2
    "ChemmineR" # Build Is Broken
    "ChIPComp" # depends on broken package r-Rsamtools-1.21.18
    "chipenrich" # build is broken
    "chipPCR" # depends on broken nloptr-1.0.4
    "climwin" # depends on broken package nlopt-2.4.2
    "clippda" # broken build
    "CLME" # depends on broken package nlopt-2.4.2
    "clpAPI" # build is broken
    "clusterPower" # depends on broken package nlopt-2.4.2
    "clusterSEs" # depends on broken AER-1.2-4
    "ClustGeo" # depends on broken FactoMineR-1.31.3
    "CNORfuzzy" # depends on broken package nlopt-2.4.2
    "CNVPanelizer" # depends on broken cn.mops-1.15.1
    "cogena" # broken build
    "COHCAP" # build is broken
    "colorscience"
    "compendiumdb" # broken build
    "conformal" # depends on broken package nlopt-2.4.2
    "convevol" # broken build
    "corHMM" # depends on broken package nlopt-2.4.2
    "cosmiq" # depends on broken package mzR-2.3.1
    "CosmoPhotoz" # depends on broken package nlopt-2.4.2
    "covmat" # depends on broken package r-VIM-4.4.1
    "covr" # broken build
    "cpgen" # depends on broken package r-pedigreemm-0.3-3
    "cplexAPI" # build is broken
    "creditr" # broken build
    "CrypticIBDcheck" # depends on broken package nlopt-2.4.2
    "ctsem" # depends on broken package r-OpenMx-2.2.6
    "cudaBayesreg" # build is broken
    "curvHDR" # broken build
    "cytofkit" # broken build
    "daff" # depends on broken package V8-0.6
    "dagbag" # build is broken
    "DAMisc" # depends on broken package nlopt-2.4.2
    "datafsm" # depends on broken package r-caret-6.0-52
    "dbConnect" # broken build
    "DBKGrad" # depends on broken package rpanel-1.1-3
    "DECIPHER" # broken build
    "Deducer" # depends on broken package nlopt-2.4.2
    "DeducerExtras" # depends on broken package nlopt-2.4.2
    "DeducerPlugInExample" # depends on broken package nlopt-2.4.2
    "DeducerPlugInScaling" # depends on broken package nlopt-2.4.2
    "DeducerSpatial" # depends on broken package nlopt-2.4.2
    "DeducerSurvival" # depends on broken package nlopt-2.4.2
    "DeducerText" # depends on broken package nlopt-2.4.2
    "DEGraph" # depends on broken package RCytoscape-1.19.0
    "destiny" # depends on broken package VIM-4.3.0
    "DiagTest3Grp" # depends on broken package nlopt-2.4.2
    "diffHic" # depends on broken package rhdf5-2.13.1
    "difR" # depends on broken package nlopt-2.4.2
    "diggit" # broken build
    "DirichletMultinomial" # Build Is Broken
    "discSurv" # depends on broken package nlopt-2.4.2
    "DistatisR" # depends on broken package nlopt-2.4.2
    "diveRsity" # depends on broken package nlopt-2.4.2
    "doMPI" # build is broken
    "dpa" # depends on broken package nlopt-2.4.2
    "dpcR" # depends on broken nloptr-1.0.4
    "drc" # depends on broken package nlopt-2.4.2
    "drfit" # depends on broken package nlopt-2.4.2
    "drsmooth" # depends on broken package nlopt-2.4.2
    "dupRadar" # depends on broken package r-Rsubread-1.19.5
    "dynlm" # depends on broken package nlopt-2.4.2
    "easyanova" # depends on broken package nlopt-2.4.2
    "edge" # depends on broken package nlopt-2.4.2
    "eeptools" # depends on broken package nlopt-2.4.2
    "EffectLiteR" # depends on broken package nlopt-2.4.2
    "effects" # depends on broken package nlopt-2.4.2
    "eiR" # depends on broken package ChemmineR-2.21.7
    "EMA" # depends on broken package nlopt-2.4.2
    "EnQuireR" # depends on broken package nlopt-2.4.2
    "EnrichedHeatmap" # broken build
    "EnrichmentBrowser" # depends on broken package r-EDASeq-2.3.2
    "episplineDensity" # depends on broken package nlopt-2.4.2
    "epr" # depends on broken package nlopt-2.4.2
    "erer" # depends on broken package nlopt-2.4.2
    "erma" # depends on broken GenomicFiles-1.5.4
    "erpR" # depends on broken package rpanel-1.1-3
    "ESKNN" # depends on broken package r-caret-6.0-52
    "evobiR" # broken build
    "evolqg" # broken build
    "extRemes" # depends on broken package nlopt-2.4.2
    "ez" # depends on broken package nlopt-2.4.2
    "facopy" # depends on broken package nlopt-2.4.2
    "FactoMineR" # depends on broken package nlopt-2.4.2
    "Factoshiny" # depends on broken package nlopt-2.4.2
    "faoutlier" # depends on broken package nlopt-2.4.2
    "fastR" # depends on broken package nlopt-2.4.2
    "FDRreg" # depends on broken package nlopt-2.4.2
    "FedData" # broken build
    "FindMyFriends" # broken build
    "flagme" # depends on broken package mzR-2.3.1
    "flowBeads" # broken build
    "flowBin" # broken build
    "flowcatchR" # broken build
    "flowCHIC" # broken build
    "flowClean" # broken build
    "flowClust" # broken build
    "flowCore" # broken build
    "flowDensity" # depends on broken package nlopt-2.4.2
    "flowFit" # broken build
    "flowFP" # broken build
    "flowMatch" # broken build
    "flowMeans" # broken build
    "flowMerge" # broken build
    "flowPeaks" # build is broken
    "flowQB" # broken build
    "flowQ" # build is broken
    "flowStats" # depends on broken package ncdfFlow-2.15.2
    "flowTrans" # broken build
    "flowType" # broken build
    "flowUtils" # broken build
    "flowViz" # broken build
    "flowVS" # depends on broken package ncdfFlow-2.15.2
    "flowWorkspace" # depends on broken package ncdfFlow-2.15.2
    "fmcsR" # depends on broken package ChemmineR-2.21.7
    "fPortfolio" # depends on broken package Rsymphony-0.1-20
    "freqweights" # depends on broken package nlopt-2.4.2
    "fscaret" # depends on broken package nlopt-2.4.2
    "fxregime" # depends on broken package nlopt-2.4.2
    "gamclass" # depends on broken package nlopt-2.4.2
    "gamlss_demo" # depends on broken package rpanel-1.1-3
    "gamm4" # depends on broken package nlopt-2.4.2
    "gcmr" # depends on broken package nlopt-2.4.2
    "GDAtools" # depends on broken package nlopt-2.4.2
    "GENE_E" # depends on broken package rhdf5-2.13.1
    "genefu" # broken build
    "genotypeeval" # depends on broken package r-rtracklayer-1.29.12
    "genridge" # depends on broken package nlopt-2.4.2
    "geojsonio" # depends on broken package V8-0.6
    "geomorph" # broken build
    "GEWIST" # depends on broken package nlopt-2.4.2
    "gfcanalysis" # broken build
    "gimme" # depends on broken package nlopt-2.4.2
    "gmatrix" # depends on broken package cudatoolkit-5.5.22
    "goseq" # build is broken
    "GPC" # broken build
    "gplm" # depends on broken package nlopt-2.4.2
    "gputools" # depends on broken package cudatoolkit-5.5.22
    "gQTLBase" # depends on broken package r-GenomicFiles-1.5.8
    "granova" # depends on broken package nlopt-2.4.2
    "graphicalVAR" # depends on broken package nlopt-2.4.2
    "GraphPCA" # depends on broken package nlopt-2.4.2
    "GSCA" # depends on broken package rhdf5-2.13.1
    "GUIDE" # depends on broken package rpanel-1.1-3
    "GUIProfiler" # broken build
    "Guitar" # depends on broken package r-GenomicAlignments-1.5.18
    "GWAF" # depends on broken package nlopt-2.4.2
    "h5" # build is broken
    "h5vc" # depends on broken package rhdf5-2.13.1
    "hbsae" # depends on broken package nlopt-2.4.2
    "HCsnip" # broken build
    "heplots" # depends on broken package nlopt-2.4.2
    "hierGWAS"
    "HierO" # Build Is Broken
    "highriskzone"
    "HilbertVisGUI" # Build Is Broken
    "HiPLARM" # Build Is Broken
    "hisse" # broken build
    "HistDAWass" # depends on broken package nlopt-2.4.2
    "HLMdiag" # depends on broken package nlopt-2.4.2
    "HydeNet" # broken build
    "hysteresis" # depends on broken package nlopt-2.4.2
    "IATscores" # depends on broken package nlopt-2.4.2
    "ibd" # depends on broken package nlopt-2.4.2
    "iccbeta" # depends on broken package nlopt-2.4.2
    "ifaTools" # depends on broken package r-OpenMx-2.2.6
    "imager" # broken build
    "immer" # depends on broken package r-sirt-1.8-9
    "immunoClust" # build is broken
    "imputeR" # depends on broken package nlopt-2.4.2
    "in2extRemes" # depends on broken package nlopt-2.4.2
    "inferference" # depends on broken package nlopt-2.4.2
    "influence_ME" # depends on broken package nlopt-2.4.2
    "inSilicoMerging" # build is broken
    "INSPEcT" # depends on broken GenomicFeatures-1.21.13
    "interplot" # depends on broken arm-1.8-5
    "IONiseR" # depends on broken rhdf5-2.13.4
    "iptools"
    "IsingFit" # depends on broken package nlopt-2.4.2
    "ITALICS" # depends on broken package oligo-1.33.0
    "IVAS" # depends on broken package nlopt-2.4.2
    "ivpack" # depends on broken package nlopt-2.4.2
    "JAGUAR" # depends on broken package nlopt-2.4.2
    "jetset"
    "joda" # depends on broken package nlopt-2.4.2
    "jomo" # build is broken
    "js" # depends on broken package V8-0.6
    "lawn" # depends on broken package V8-0.6
    "ldblock" # depends on broken package r-snpStats-1.19.3
    "learnstats" # depends on broken package nlopt-2.4.2
    "lefse" # build is broken
    "lessR" # depends on broken package nlopt-2.4.2
    "lgcp" # depends on broken package rpanel-1.1-3
    "LinRegInteractive" # depends on broken package rpanel-1.1-3
    "lmdme" # build is broken
    "lme4" # depends on broken package nlopt-2.4.2
    "LMERConvenienceFunctions" # depends on broken package nlopt-2.4.2
    "lmerTest" # depends on broken package nlopt-2.4.2
    "lmSupport" # depends on broken package nlopt-2.4.2
    "LogisticDx" # depends on broken package nlopt-2.4.2
    "longpower" # depends on broken package nlopt-2.4.2
    "LOST" # broken build
    "MAIT" # depends on broken package nlopt-2.4.2
    "mAPKL" # build is broken
    "maPredictDSC" # depends on broken package nlopt-2.4.2
    "marked" # depends on broken package nlopt-2.4.2
    "MatrixRider" # depends on broken package DirichletMultinomial-1.11.1
    "MaxPro" # depends on broken package nlopt-2.4.2
    "MazamaSpatialUtils" # broken build
    "mbest" # depends on broken package nlopt-2.4.2
    "MBmca" # depends on broken nloptr-1.0.4
    "meboot" # depends on broken package nlopt-2.4.2
    "medflex" # depends on broken package r-car-2.1-0
    "mediation" # depends on broken package r-lme4-1.1-8
    "MEDME" # depends on broken package nlopt-2.4.2
    "MEMSS" # depends on broken package nlopt-2.4.2
    "merTools" # depends on broken package r-arm-1.8-6
    "meta4diag" # broken build
    "Metab" # depends on broken package mzR-2.3.1
    "metacom" # broken build
    "metagear" # build is broken
    "MetaLandSim" # broken build
    "metaMix" # build is broken
    "metaMS" # depends on broken package mzR-2.3.1
    "metaplus" # depends on broken package nlopt-2.4.2
    "metaSEM" # depends on broken package OpenMx-2.2.4
    "Metatron" # depends on broken package nlopt-2.4.2
    "metaX" # depends on broken package r-CAMERA-1.25.2
    "miceadds" # depends on broken package nlopt-2.4.2
    "micEconAids" # depends on broken package nlopt-2.4.2
    "micEconCES" # depends on broken package nlopt-2.4.2
    "micEconSNQP" # depends on broken package nlopt-2.4.2
    "mi" # depends on broken package nlopt-2.4.2
    "MigClim" # Build Is Broken
    "migui" # depends on broken package nlopt-2.4.2
    "minimist" # depends on broken package V8-0.6
    "missDeaths"
    "missMDA" # depends on broken package nlopt-2.4.2
    "mixAK" # depends on broken package nlopt-2.4.2
    "mixlm" # depends on broken package nlopt-2.4.2
    "MixMAP" # depends on broken package nlopt-2.4.2
    "MLInterfaces" # broken build
    "mlmRev" # depends on broken package nlopt-2.4.2
    "MLSeq" # depends on broken package nlopt-2.4.2
    "mlVAR" # depends on broken package nlopt-2.4.2
    "mongolite" # build is broken
    "monogeneaGM" # broken build
    "mosaic" # depends on broken package nlopt-2.4.2
    "motifbreakR" # depends on broken package r-BSgenome-1.37.5
    "mpoly" # broken build
    "msa" # broken build
    "MSeasy" # depends on broken package mzR-2.3.1
    "MSeasyTkGUI" # depends on broken package mzR-2.3.1
    "MSGFgui" # depends on broken package MSGFplus-1.3.0
    "MSGFplus" # Build Is Broken
    "MSstats" # depends on broken package nlopt-2.4.2
    "multiDimBio" # depends on broken package nlopt-2.4.2
    "MultiRR" # depends on broken package nlopt-2.4.2
    "muma" # depends on broken package nlopt-2.4.2
    "munsellinterpol"
    "mutossGUI" # build is broken
    "mvinfluence" # depends on broken package nlopt-2.4.2
    "mvMORPH" # broken build
    "myvariant" # depends on broken package r-VariantAnnotation-1.15.31
    "mzR" # build is broken
    "nCal" # depends on broken package nlopt-2.4.2
    "ncdfFlow" # build is broken
    "NCIgraph" # depends on broken package RCytoscape-1.19.0
    "netbenchmark" # build is broken
    "netresponse" # broken build
    "NetSAM" # broken build
    "NGScopy"
    "NHPoisson" # depends on broken package nlopt-2.4.2
    "nloptr" # depends on broken package nlopt-2.4.2
    "nlts" # broken build
    "nonrandom" # depends on broken package nlopt-2.4.2
    "NORRRM" # build is broken
    "npIntFactRep" # depends on broken package nlopt-2.4.2
    "NSM3" # broken build
    "OmicsMarkeR" # depends on broken package nlopt-2.4.2
    "OpenCL" # build is broken
    "opencpu" # broken build
    "openCyto" # depends on broken package ncdfFlow-2.15.2
    "OpenMx" # build is broken
    "optBiomarker" # depends on broken package rpanel-1.1-3
    "ora" # depends on broken package ROracle-1.1-12
    "ordBTL" # depends on broken package nlopt-2.4.2
    "ordPens" # depends on broken package r-lme4-1.1-9
    "OUwie" # depends on broken package nlopt-2.4.2
    "pacman" # broken build
    "PADOG" # build is broken
    "paleotree" # broken build
    "pamm" # depends on broken package nlopt-2.4.2
    "panelAR" # depends on broken package nlopt-2.4.2
    "papeR" # depends on broken package nlopt-2.4.2
    "parboost" # depends on broken package nlopt-2.4.2
    "parma" # depends on broken package nlopt-2.4.2
    "Pasha" # depends on broken package GenomicAlignments-1.5.12
    "PatternClass" # build is broken
    "pbdBASE" # depends on broken package pbdSLAP-0.2-0
    "PBD" # broken build
    "pbdDEMO" # depends on broken package pbdSLAP-0.2-0
    "pbdDMAT" # depends on broken package pbdSLAP-0.2-0
    "pbdSLAP" # build is broken
    "PBImisc" # depends on broken package nlopt-2.4.2
    "pbkrtest" # depends on broken package nlopt-2.4.2
    "pcaBootPlot" # depends on broken FactoMineR-1.31.3
    "pcaL1" # build is broken
    "pedigreemm" # depends on broken package nlopt-2.4.2
    "pedometrics" # depends on broken package nlopt-2.4.2
    "pequod" # depends on broken package nlopt-2.4.2
    "PharmacoGx"
    "PhenStat" # depends on broken package nlopt-2.4.2
    "phia" # depends on broken package nlopt-2.4.2
    "phylocurve" # depends on broken package nlopt-2.4.2
    "phytools" # broken build
    "plateCore" # depends on broken package ncdfFlow-2.15.2
    "plfMA" # broken build
    "plsRbeta" # depends on broken package nlopt-2.4.2
    "plsRcox" # depends on broken package nlopt-2.4.2
    "plsRglm" # depends on broken package nlopt-2.4.2
    "pmclust" # build is broken
    "pmm" # depends on broken package nlopt-2.4.2
    "pomp" # depends on broken package nlopt-2.4.2
    "predictionet" # broken build
    "predictmeans" # depends on broken package nlopt-2.4.2
    "prLogistic" # depends on broken package nlopt-2.4.2
    "pRoloc" # depends on broken package nlopt-2.4.2
    "pRolocGUI" # depends on broken package nlopt-2.4.2
    "ProteomicsAnnotationHubData" # depends on broken package r-AnnotationHub-2.1.40
    "PSAboot" # depends on broken package nlopt-2.4.2
    "ptw" # depends on broken nloptr-1.0.4
    "purge" # depends on broken package r-lme4-1.1-9
    "pvca" # depends on broken package nlopt-2.4.2
    "PythonInR"
    "QFRM"
    "qgraph" # depends on broken package nlopt-2.4.2
    "qtbase" # build is broken
    "qtlnet" # depends on broken package nlopt-2.4.2
    "qtpaint" # depends on broken package qtbase-1.0.9
    "qtutils" # depends on broken package qtbase-1.0.9
    "QUALIFIER" # depends on broken package ncdfFlow-2.15.2
    "quantification" # depends on broken package nlopt-2.4.2
    "R2STATS" # depends on broken package nlopt-2.4.2
    "RADami" # broken build
    "raincpc" # build is broken
    "rainfreq" # build is broken
    "RAM" # broken build
    "RamiGO" # depends on broken package RCytoscape-1.19.0
    "RareVariantVis" # depends on broken VariantAnnotation-1.15.19
    "rasclass" # depends on broken package nlopt-2.4.2
    "rase" # broken build
    "RBerkeley"
    "RbioRXN" # depends on broken package ChemmineR-2.21.7
    "Rblpapi" # broken build
    "rbundler" # broken build
    "rcellminer" # broken build
    "rCGH" # depends on broken package r-affy-1.47.1
    "Rchemcpp" # depends on broken package ChemmineR-2.21.7
    "RchyOptimyx" # broken build
    "Rcmdr" # depends on broken package nlopt-2.4.2
    "RcmdrMisc" # depends on broken package nlopt-2.4.2
    "RcmdrPlugin_BCA" # depends on broken package nlopt-2.4.2
    "RcmdrPlugin_coin" # depends on broken package nlopt-2.4.2
    "RcmdrPlugin_depthTools" # depends on broken package nlopt-2.4.2
    "RcmdrPlugin_DoE" # depends on broken package nlopt-2.4.2
    "RcmdrPlugin_doex" # depends on broken package nlopt-2.4.2
    "RcmdrPlugin_EACSPIR" # depends on broken package nlopt-2.4.2
    "RcmdrPlugin_EBM" # depends on broken package nlopt-2.4.2
    "RcmdrPlugin_EcoVirtual" # depends on broken package nlopt-2.4.2
    "RcmdrPlugin_epack" # depends on broken package nlopt-2.4.2
    "RcmdrPlugin_EZR" # depends on broken package nlopt-2.4.2
    "RcmdrPlugin_FactoMineR" # depends on broken package nlopt-2.4.2
    "RcmdrPlugin_HH" # depends on broken package nlopt-2.4.2
    "RcmdrPlugin_IPSUR" # depends on broken package nlopt-2.4.2
    "RcmdrPlugin_KMggplot2" # depends on broken package nlopt-2.4.2
    "RcmdrPlugin_lfstat" # depends on broken package nlopt-2.4.2
    "RcmdrPlugin_MA" # depends on broken package nlopt-2.4.2
    "RcmdrPlugin_mosaic" # depends on broken package nlopt-2.4.2
    "RcmdrPlugin_MPAStats" # depends on broken package nlopt-2.4.2
    "RcmdrPlugin_NMBU" # depends on broken package nlopt-2.4.2
    "RcmdrPlugin_orloca" # depends on broken package nlopt-2.4.2
    "RcmdrPlugin_plotByGroup" # depends on broken package nlopt-2.4.2
    "RcmdrPlugin_pointG" # depends on broken package nlopt-2.4.2
    "RcmdrPlugin_qual" # depends on broken package nlopt-2.4.2
    "RcmdrPlugin_RMTCJags" # depends on broken package nlopt-2.4.2
    "RcmdrPlugin_ROC" # depends on broken package nlopt-2.4.2
    "RcmdrPlugin_sampling" # depends on broken package nlopt-2.4.2
    "RcmdrPlugin_SCDA" # depends on broken package nlopt-2.4.2
    "RcmdrPlugin_seeg" # depends on broken package nlopt-2.4.2
    "RcmdrPlugin_SLC" # depends on broken package nlopt-2.4.2
    "RcmdrPlugin_SM" # depends on broken package nlopt-2.4.2
    "RcmdrPlugin_sos" # depends on broken package nlopt-2.4.2
    "RcmdrPlugin_steepness" # depends on broken package nlopt-2.4.2
    "RcmdrPlugin_survival" # depends on broken package nlopt-2.4.2
    "RcmdrPlugin_TeachingDemos" # depends on broken package nlopt-2.4.2
    "RcmdrPlugin_temis" # depends on broken package nlopt-2.4.2
    "RcmdrPlugin_UCA" # depends on broken package nlopt-2.4.2
    "Rcpi" # depends on broken package ChemmineR-2.21.7
    "Rcplex" # Build Is Broken
    "RcppAPT" # Build Is Broken
    "RcppRedis" # build is broken
    "rcrypt" # broken build
    "RCytoscape" # Build Is Broken
    "rdd" # depends on broken package nlopt-2.4.2
    "rddtools" # depends on broken package r-AER-1.2-4
    "rDEA" # build is broken
    "RDieHarder" # build is broken
    "REBayes" # depends on broken package Rmosek-1.2.5.1
    "recluster" # broken build
    "referenceIntervals" # depends on broken package nlopt-2.4.2
    "refund" # depends on broken package nlopt-2.4.2
    "refund_shiny" # depends on broken package r-refund-0.1-13
    "regRSM" # broken build
    "repijson" # depends on broken package V8-0.6
    "REST" # depends on broken package nlopt-2.4.2
    "rgbif" # depends on broken package V8-0.6
    "Rgnuplot"
    "rgsepd" # depends on broken package goseq-1.21.1
    "rhdf5" # build is broken
    "rjade" # depends on broken package V8-0.6
    "rJPSGCS" # build is broken
    "rLindo" # build is broken
    "RLRsim" # depends on broken package r-lme4-1.1-9
    "RMassBank" # depends on broken package mzR-2.3.1
    "rMAT" # build is broken
    "rmgarch" # depends on broken package nlopt-2.4.2
    "rminer" # depends on broken package nlopt-2.4.2
    "Rmosek" # build is broken
    "RMySQL" # broken build
    "RNAither" # depends on broken package nlopt-2.4.2
    "RnavGraph" # build is broken
    "robustlmm" # depends on broken package nlopt-2.4.2
    "rockchalk" # depends on broken package nlopt-2.4.2
    "RockFab" # broken build
    "ROI_plugin_symphony" # depends on broken package Rsymphony-0.1-20
    "rols" # build is broken
    "ROracle" # Build Is Broken
    "rpanel" # build is broken
    "Rphylopars" # broken build
    "rpubchem" # depends on broken package nlopt-2.4.2
    "RQuantLib" # build is broken
    "rr" # depends on broken package nlopt-2.4.2
    "RSAP" # build is broken
    "rsbml" # build is broken
    "rscala" # build is broken
    "RSDA" # depends on broken package nlopt-2.4.2
    "RStoolbox" # depends on broken package r-caret-6.0-52
    "Rsubread" # Build Is Broken
    "Rsymphony" # build is broken
    "rTableICC" # broken build
    "rTANDEM" # build is broken
    "RTCGA" # depends on broken package r-rvest-0.3.0
    "RTN" # depends on broken package nlopt-2.4.2
    "rugarch" # depends on broken package nlopt-2.4.2
    "rUnemploymentData" # broken build
    "RVAideMemoire" # depends on broken package nlopt-2.4.2
    "RVFam" # depends on broken package nlopt-2.4.2
    "RVideoPoker" # depends on broken package rpanel-1.1-3
    "RWebServices" # broken build
    "ryouready" # depends on broken package nlopt-2.4.2
    "sampleSelection" # depends on broken package nlopt-2.4.2
    "sapFinder" # depends on broken package rTANDEM-1.9.0
    "saps" # broken build
    "scmamp" # broken build
    "sdcMicro" # depends on broken package nlopt-2.4.2
    "sdcMicroGUI" # depends on broken package nlopt-2.4.2
    "SDD" # depends on broken package rpanel-1.1-3
    "seeg" # depends on broken package nlopt-2.4.2
    "sejmRP" # depends on broken package r-rvest-0.3.0
    "sem" # depends on broken package nlopt-2.4.2
    "semdiag" # depends on broken package nlopt-2.4.2
    "semGOF" # depends on broken package nlopt-2.4.2
    "semPlot" # depends on broken package nlopt-2.4.2
    "SensMixed" # depends on broken package r-lme4-1.1-9
    "SensoMineR" # depends on broken package nlopt-2.4.2
    "SeqFeatR" # broken build
    "SeqGrapheR" # Build Is Broken
    "seqTools" # build is broken
    "shinyTANDEM" # depends on broken package rTANDEM-1.9.0
    "SigCheck" # broken build
    "SIMAT" # depends on broken package mzR-2.3.1
    "simPop" # depends on broken package r-VIM-4.4.1
    "simulatorZ" # broken build
    "sirt" # depends on broken package nlopt-2.4.2
    "SJava" # broken build
    "sjPlot" # depends on broken package nlopt-2.4.2
    "snapCGH" # depends on broken package tilingArray-1.47.0
    "snm" # depends on broken package nlopt-2.4.2
    "SOD" # depends on broken package cudatoolkit-5.5.22
    "soilphysics" # depends on broken package rpanel-1.1-3
    "sortinghat" # broken build
    "SoyNAM" # depends on broken package r-lme4-1.1-8
    "spacom" # depends on broken package nlopt-2.4.2
    "spade" # broken build
    "spdynmod" # broken build
    "specificity" # depends on broken package nlopt-2.4.2
    "spocc" # depends on broken package V8-0.6
    "spoccutils" # depends on broken spocc-0.3.0
    "spsann" # depends on broken package r-pedometrics-0.6-2
    "ssmrob" # depends on broken package nlopt-2.4.2
    "Statomica" # broken build
    "stcm" # depends on broken package nlopt-2.4.2
    "stepp" # depends on broken package nlopt-2.4.2
    "Surrogate" # depends on broken package nlopt-2.4.2
    "sybilSBML" # build is broken
    "systemfit" # depends on broken package nlopt-2.4.2
    "systemPipeRdata" # broken build
    "TargetSearch" # depends on broken package mzR-2.3.1
    "TCGAbiolinks" # depends on broken package r-affy-1.47.1
    "TcGSA" # depends on broken package nlopt-2.4.2
    "TDMR" # depends on broken package nlopt-2.4.2
    "TED" # broken build
    "TFBSTools" # depends on broken package DirichletMultinomial-1.11.1
    "tigerstats" # depends on broken package nlopt-2.4.2
    "TKF" # broken build
    "tmle" # broken build
    "tnam" # depends on broken package r-lme4-1.1-9
    "translateSPSS2R" # depends on broken car-2.0-25
    "traseR"
    "TriMatch" # depends on broken package nlopt-2.4.2
    "TSdist" # broken build
    "TSMySQL" # broken build
    "umx" # depends on broken package r-OpenMx-2.2.6
    "userfriendlyscience" # depends on broken package nlopt-2.4.2
    "V8" # build is broken
    "varComp" # depends on broken package r-lme4-1.1-9
    "variancePartition" # depends on broken package lme4-1.1-8
    "VBmix" # broken build
    "VIM" # depends on broken package nlopt-2.4.2
    "VIMGUI" # depends on broken package nlopt-2.4.2
    "vows" # depends on broken package nlopt-2.4.2
    "wfe" # depends on broken package nlopt-2.4.2
    "xcms" # depends on broken package mzR-2.3.1
    "x_ent" # broken build
    "xergm" # depends on broken package nlopt-2.4.2
    "xps" # build is broken
    "ZeligMultilevel" # depends on broken package nlopt-2.4.2
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
