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
    "synapter" # depends on broken package MSnbase
    "proteoQC" # depends on broken package MSnbase
    "Pbase" # depends on broken package MSnbase
    "MSnID" # depends on broken package MSnbase
    "msmsTests" # depends on broken package MSnbase
    "msmsEDA" # depends on broken package MSnbase
    "Prostar" # depends on broken package MSnbase
    "DAPAR" # depends on broken package MSnbase
    "MSnbase" # broken build
    "DBKGrad" # depends on broken package SDD
    "SDD" # broken build
    "colorscience" # depends on broken package munsellinterpol
    "webp" # broken build
    "CopulaDTA" # broken build
    "exomePeak" # broken build
    "munsellinterpol" # broken build
    "munsellinterpol" # broken build
    "synthpop" # depends on broken package coefplot
    "coefplot" # broken build
    "R2jags" # broken build
    "classify" # depends on broken package R2jags
    "CCTpack" # depends on broken package R2jags
    "R2jags" # broken build
    "rJPSGCS" # depends on broken package chopsticks
    "chopsticks" # broken build
    "MBmca" # depends on broken package chipPCR
    "chipPCR" # depends on broken package nloptr
    "Rchemcpp" # depends on broken package ChemmineR
    "RbioRXN" # depends on broken package ChemmineR
    "fmcsR" # depends on broken package ChemmineR
    "eiR" # depends on broken package ChemmineR
    "ChemmineR" # broken build
    "cghMCR" # broken build
    "CALIB" # broken build
    "AtelieR" # depends on broken package polynom
    "AssetPricing" # depends on broken package polynom
    "algstat" # depends on broken package polynom
    "zebrafish_db0" # broken build
    "zebrafish_db" # broken build
    "yri1kgv" # broken build
    "ygs98_db" # broken build
    "yeastRNASeq" # broken build
    "yeastNagalakshmi" # broken build
    "yeast_db0" # broken build
    "yeast2_db" # broken build
    "xtropicalisprobe" # broken build
    "XtraSNPlocs_Hsapiens_dbSNP144_GRCh38" # broken build
    "XtraSNPlocs_Hsapiens_dbSNP144_GRCh37" # broken build
    "XtraSNPlocs_Hsapiens_dbSNP141_GRCh38" # broken build
    "xlaevis2probe" # broken build
    "xenopus_db0" # broken build
    "worm_db0" # broken build
    "wheatprobe" # broken build
    "WES_1KG_WUGSC" # broken build
    "waveTilingData" # broken build
    "u133x3p_db" # broken build
    "u133x3pcdf" # broken build
    "u133aaofav2cdf" # broken build
    "TxDb_Rnorvegicus_BioMart_igis" # broken build
    "TxDb_Mmusculus_UCSC_mm9_knownGene" # broken build
    "TxDb_Hsapiens_UCSC_hg38_knownGene" # broken build
    "TxDb_Hsapiens_UCSC_hg19_knownGene" # broken build
    "TxDb_Celegans_UCSC_ce6_ensGene" # broken build
    "tweeDEseqCountData" # broken build
    "TransferEntropy" # broken build
    "TCGAMethylation450k" # broken build
    "TCGAcrcmRNA" # broken build
    "TBX20BamSubset" # broken build
    "TargetSearchData" # broken build
    "TargetScoreData" # broken build
    "synapterdata" # broken build
    "SVM2CRMdata" # broken build
    "SVM2CRM" # broken build
    "stjudem" # broken build
    "SpikeIn" # broken build
    "SomatiCAData" # broken build
    "SNPlocs_Hsapiens_dbSNP_20120608" # broken build
    "SNPlocs_Hsapiens_dbSNP_20111119" # broken build
    "SNPlocs_Hsapiens_dbSNP_20110815" # broken build
    "SNPlocs_Hsapiens_dbSNP_20101109" # broken build
    "SNPlocs_Hsapiens_dbSNP_20100427" # broken build
    "SNPlocs_Hsapiens_dbSNP_20090506" # broken build
    "SNPlocs_Hsapiens_dbSNP144_GRCh38" # broken build
    "SNPlocs_Hsapiens_dbSNP144_GRCh37" # broken build
    "SNPlocs_Hsapiens_dbSNP142_GRCh37" # broken build
    "SNPlocs_Hsapiens_dbSNP141_GRCh38" # broken build
    "SNPhoodData" # broken build
    "SNAGEEdata" # broken build
    "SNAGEE" # broken build
    "SIFT_Hsapiens_dbSNP137" # broken build
    "SIFT_Hsapiens_dbSNP132" # broken build
    "shinyMethylData" # broken build
    "SHDZ_db" # broken build
    "seventyGeneData" # broken build
    "seqCNA_annot" # broken build
    "seqCNA" # broken build
    "seqc" # broken build
    "seq2pathway_data" # broken build
    "seq2pathway" # broken build
    "SemDist" # broken build
    "SCLCBam" # broken build
    "rwgcod_db" # broken build
    "rtu34_db" # broken build
    "RTCGA_rnaseq" # broken build
    "RTCGA_mutations" # broken build
    "RTCGA_clinical" # broken build
    "RRreg" # depends on broken package nloptr
    "rRDPData" # broken build
    "RRBSdata" # broken build
    "Rothermel" # broken build
    "Roberts2005Annotation_db" # broken build
    "rnu34_db" # broken build
    "RnBeads_rn5" # broken build
    "RnBeads_mm9" # broken build
    "RnBeads_mm10" # broken build
    "RnBeads_hg38" # broken build
    "RnBeads_hg19" # broken build
    "RnaSeqTutorial" # broken build
    "RNAseqData_HNRNPC_bam_chr14" # broken build
    "RnAgilentDesign028282_db" # broken build
    "rmumps" # broken build
    "RmiR_Hs_miRNA" # broken build
    "RmiR_hsa" # broken build
    "RmiR" # broken build
    "RMassBankData" # broken build
    "RIPSeekerData" # broken build
    "ri16cod_db" # broken build
    "rheumaticConditionWOLLBOLD" # broken build
    "rgug4131a_db" # broken build
    "rgug4130a_db" # broken build
    "rgug4105a_db" # broken build
    "rguatlas4k_db" # broken build
    "rgu34c_db" # broken build
    "rgu34b_db" # broken build
    "rgu34a_db" # broken build
    "reactome_db" # broken build
    "rcellminerData" # broken build
    "rat_db0" # broken build
    "rat2302_db" # broken build
    "ragene21sttranscriptcluster_db" # broken build
    "ragene21stprobeset_db" # broken build
    "ragene20sttranscriptcluster_db" # broken build
    "ragene20stprobeset_db" # broken build
    "ragene11sttranscriptcluster_db" # broken build
    "ragene11stprobeset_db" # broken build
    "ragene10sttranscriptcluster_db" # broken build
    "ragene10stprobeset_db" # broken build
    "raex10sttranscriptcluster_db" # broken build
    "raex10stprobeset_db" # broken build
    "rae230b_db" # broken build
    "rae230a_db" # broken build
    "r10kcod_db" # broken build
    "QDNAseq_mm10" # broken build
    "QDNAseq_hg19" # broken build
    "PWMEnrich_Hsapiens_background" # broken build
    "PWMEnrich_Dmelanogaster_background" # broken build
    "pumadata" # broken build
    "polynom" # broken build
    "tsoutliers" # depends on broken package polynom
    "ldamatch" # depends on broken package polynom
    "iterpc" # depends on broken package polynom
    "hwwntest" # depends on broken package polynom
    "polynom" # broken build
    "pRolocdata" # broken build
    "prebsdata" # broken build
    "porcine_db" # broken build
    "PolyPhen_Hsapiens_dbSNP131" # broken build
    "POCRCannotation_db" # broken build
    "pig_db0" # broken build
    "phastCons7way_UCSC_hg38" # broken build
    "phastCons100way_UCSC_hg38" # broken build
    "phastCons100way_UCSC_hg19" # broken build
    "PFAM_db" # broken build
    "pedbarrayv9_db" # broken build
    "pedbarrayv10_db" # broken build
    "pd_zebrafish" # broken build
    "pd_zebgene_1_1_st" # broken build
    "pd_zebgene_1_0_st" # broken build
    "pd_x_tropicalis" # broken build
    "pd_wheat" # broken build
    "pd_vitis_vinifera" # broken build
    "pd_u133_x3p" # broken build
    "pd_soygene_1_1_st" # broken build
    "pd_soygene_1_0_st" # broken build
    "pd_soybean" # broken build
    "pd_rusgene_1_1_st" # broken build
    "pd_rusgene_1_0_st" # broken build
    "pd_rta_1_0" # broken build
    "pd_rjpgene_1_1_st" # broken build
    "pd_rjpgene_1_0_st" # broken build
    "pd_rice" # broken build
    "pd_rhesus" # broken build
    "pd_rhegene_1_1_st" # broken build
    "pd_rhegene_1_0_st" # broken build
    "pd_rcngene_1_1_st" # broken build
    "pd_rcngene_1_0_st" # broken build
    "pd_ragene_2_1_st" # broken build
    "pd_ragene_2_0_st" # broken build
    "pd_ragene_1_1_st_v1" # broken build
    "pd_ragene_1_0_st_v1" # broken build
    "pd_raex_1_0_st_v1" # broken build
    "pd_rabgene_1_1_st" # broken build
    "pd_rabgene_1_0_st" # broken build
    "pd_porgene_1_1_st" # broken build
    "pd_porgene_1_0_st" # broken build
    "pd_poplar" # broken build
    "pd_plasmodium_anopheles" # broken build
    "pd_ovigene_1_1_st" # broken build
    "pd_ovigene_1_0_st" # broken build
    "pd_nugo_mm1a520177" # broken build
    "pd_mu11ksuba" # broken build
    "pd_mta_1_0" # broken build
    "pd_mogene_2_1_st" # broken build
    "pd_mogene_2_0_st" # broken build
    "pd_mogene_1_1_st_v1" # broken build
    "pd_mogene_1_0_st_v1" # broken build
    "pd_moex_1_0_st_v1" # broken build
    "pd_moe430b" # broken build
    "pd_medicago" # broken build
    "pd_medgene_1_1_st" # broken build
    "pd_medgene_1_0_st" # broken build
    "pd_margene_1_1_st" # broken build
    "pd_margene_1_0_st" # broken build
    "pd_mapping50k_xba240" # broken build
    "pd_mapping50k_hind240" # broken build
    "pd_mapping250k_sty" # broken build
    "pd_mapping250k_nsp" # broken build
    "pd_hugene_2_1_st" # broken build
    "pd_hugene_2_0_st" # broken build
    "pd_hugene_1_1_st_v1" # broken build
    "pd_hugene_1_0_st_v1" # broken build
    "pd_huex_1_0_st_v2" # broken build
    "pd_ht_hg_u133a" # broken build
    "pd_hta_2_0" # broken build
    "pd_hg_u95d" # broken build
    "pd_hg_u95a" # broken build
    "pd_hg_u219" # broken build
    "pd_hg_u133_plus_2" # broken build
    "pd_hg_u133b" # broken build
    "pd_hg_u133a" # broken build
    "pd_guigene_1_1_st" # broken build
    "pd_guigene_1_0_st" # broken build
    "pd_genomewidesnp_6" # broken build
    "pd_genomewidesnp_5" # broken build
    "pd_fingene_1_1_st" # broken build
    "pd_fingene_1_0_st" # broken build
    "pd_felgene_1_1_st" # broken build
    "pd_felgene_1_0_st" # broken build
    "pd_feinberg_mm8_me_hx1" # broken build
    "pd_feinberg_hg18_me_hx1" # broken build
    "pd_equgene_1_1_st" # broken build
    "pd_equgene_1_0_st" # broken build
    "pd_elegene_1_1_st" # broken build
    "pd_elegene_1_0_st" # broken build
    "pd_e_coli_2" # broken build
    "pd_drosophila_2" # broken build
    "pd_drogene_1_1_st" # broken build
    "pd_drogene_1_0_st" # broken build
    "pd_cytogenetics_array" # broken build
    "pd_cyrgene_1_1_st" # broken build
    "pd_cyrgene_1_0_st" # broken build
    "pd_cyngene_1_1_st" # broken build
    "pd_cyngene_1_0_st" # broken build
    "pd_cotton" # broken build
    "pd_citrus" # broken build
    "pd_chogene_2_1_st" # broken build
    "pd_chogene_2_0_st" # broken build
    "pd_chigene_1_1_st" # broken build
    "pd_chigene_1_0_st" # broken build
    "pd_chicken" # broken build
    "pd_celegans" # broken build
    "pd_canine_2" # broken build
    "pd_canine" # broken build
    "pd_cangene_1_1_st" # broken build
    "pd_cangene_1_0_st" # broken build
    "pd_bovgene_1_1_st" # broken build
    "pd_bovgene_1_0_st" # broken build
    "pd_atdschip_tiling" # broken build
    "pd_aragene_1_1_st" # broken build
    "pd_aragene_1_0_st" # broken build
    "pd_081229_hg18_promoter_medip_hx1" # broken build
    "pcaGoPromoter_Rn_rn4" # broken build
    "pcaGoPromoter_Mm_mm9" # broken build
    "pcaGoPromoter_Hs_hg19" # broken build
    "paxtoolsr" # broken build
    "PathNetData" # broken build
    "pasillaBamSubset" # broken build
    "PartheenMetaData_db" # broken build
    "parathyroidSE" # broken build
    "PANTHER_db" # broken build
    "PANDA" # broken build
    "org_Ss_eg_db" # broken build
    "org_Sc_sgd_db" # broken build
    "org_Rn_eg_db" # broken build
    "org_Pt_eg_db" # broken build
    "org_Mmu_eg_db" # broken build
    "org_Mm_eg_db" # broken build
    "org_Hs_ipi_db" # broken build
    "SEPA" # depends on broken package org_Hs_eg_db
    "rTRMui" # depends on broken package org_Hs_eg_db
    "pathview" # depends on broken package org_Hs_eg_db
    "AnnotationHubData" # depends on broken package org_Hs_eg_db
    "org_Hs_eg_db" # broken build
    "org_Dr_eg_db" # broken build
    "org_Dm_eg_db" # broken build
    "org_Ce_eg_db" # broken build
    "org_Bt_eg_db" # broken build
    "org_At_tair_db" # broken build
    "OperonHumanV3_db" # broken build
    "openssl" # broken build
    "oligoData" # broken build
    "nugomm1a520177_db" # broken build
    "nugohs1a520180_db" # broken build
    "Norway981_db" # broken build
    "NGScopyData" # broken build
    "Neve2006" # broken build
    "NanoStringQCPro" # broken build
    "mwgcod_db" # broken build
    "mvoutData" # broken build
    "MUGAExampleData" # broken build
    "Mu22v3_db" # broken build
    "mu19ksubc_db" # broken build
    "mu19ksubb_db" # broken build
    "mu19ksuba_db" # broken build
    "Mu15v1_db" # broken build
    "mu11ksubb_db" # broken build
    "mu11ksuba_db" # broken build
    "mtbls2" # broken build
    "mta10sttranscriptcluster_db" # broken build
    "mta10stprobeset_db" # broken build
    "msdata" # broken build
    "MRIaggr" # broken build
    "mpedbarray_db" # broken build
    "mouse_db0" # broken build
    "mouse430a2frmavecs" # broken build
    "mouse430a2_db" # broken build
    "mouse4302frmavecs" # broken build
    "mouse4302_db" # broken build
    "mosaicsExample" # broken build
    "mogene21sttranscriptcluster_db" # broken build
    "mogene21stprobeset_db" # broken build
    "mogene20sttranscriptcluster_db" # broken build
    "mogene20stprobeset_db" # broken build
    "mogene11sttranscriptcluster_db" # broken build
    "mogene11stprobeset_db" # broken build
    "mogene10stv1probe" # broken build
    "mogene_1_0_st_v1frmavecs" # broken build
    "mogene10sttranscriptcluster_db" # broken build
    "mogene10stprobeset_db" # broken build
    "MoExExonProbesetLocation" # broken build
    "moex10sttranscriptcluster_db" # broken build
    "moex10stprobeset_db" # broken build
    "moe430b_db" # broken build
    "moe430a_db" # broken build
    "MMDiffBamSubset" # broken build
    "MmAgilentDesign026655_db" # broken build
    "mm24kresogen_db" # broken build
    "mitoODEdata" # broken build
    "mitoODE" # broken build
    "miRNATarget" # broken build
    "miRNAtap_db" # broken build
    "mirIntegrator" # broken build
    "miRcompData" # broken build
    "miRcomp" # broken build
    "minionSummaryData" # broken build
    "mi16cod_db" # broken build
    "mgug4122a_db" # broken build
    "mgug4121a_db" # broken build
    "mgug4120a_db" # broken build
    "mgug4104a_db" # broken build
    "mguatlas5k_db" # broken build
    "mgu74cv2_db" # broken build
    "mgu74c_db" # broken build
    "mgu74bv2_db" # broken build
    "mgu74b_db" # broken build
    "mgu74av2_db" # broken build
    "mgu74a_db" # broken build
    "MethylAidData" # broken build
    "metaMSdata" # broken build
    "MeSH_Zma_eg_db" # broken build
    "MeSH_Xla_eg_db" # broken build
    "MeSH_Spo_972h_eg_db" # broken build
    "MeSH_Sce_S288c_eg_db" # broken build
    "MeSH_Rno_eg_db" # broken build
    "MeSH_Ptr_eg_db" # broken build
    "MeSH_Osa_eg_db" # broken build
    "MeSH_Mtr_eg_db" # broken build
    "MeSH_Mmu_eg_db" # broken build
    "MeSH_Hsa_eg_db" # broken build
    "MeSH_Eco_O157_H7_EDL933_eg_db" # broken build
    "MeSH_Eco_K12_MG1655_eg_db" # broken build
    "MeSH_Eco_IAI1_eg_db" # broken build
    "MeSH_Eco_HS_eg_db" # broken build
    "MeSH_Eco_55989_eg_db" # broken build
    "MeSH_Dya_eg_db" # broken build
    "MeSH_Dvi_eg_db" # broken build
    "MeSH_Dsi_eg_db" # broken build
    "MeSH_Dse_eg_db" # broken build
    "MeSH_Dre_eg_db" # broken build
    "MeSH_Dpe_eg_db" # broken build
    "MeSH_Dme_eg_db" # broken build
    "MeSH_Dgr_eg_db" # broken build
    "MeSH_Der_eg_db" # broken build
    "MeSH_Ddi_AX4_eg_db" # broken build
    "MeSH_db" # broken build
    "MeSH_Dan_eg_db" # broken build
    "MeSH_Cja_eg_db" # broken build
    "MeSH_Cin_eg_db" # broken build
    "MeSH_Cfa_eg_db" # broken build
    "MeSH_Cbr_eg_db" # broken build
    "MeSH_Cal_SC5314_eg_db" # broken build
    "MeSH_Bsu_TUB10_eg_db" # broken build
    "MeSH_Bfl_eg_db" # broken build
    "MeSH_Ath_eg_db" # broken build
    "MeSH_Ame_eg_db" # broken build
    "MeSH_Aga_PEST_eg_db" # broken build
    "MeSH_Aca_eg_db" # broken build
    "MEDIPSData" # broken build
    "MEALData" # broken build
    "mBvs" # broken build
    "MAQCsubsetILM" # broken build
    "MAQCsubsetAFX" # broken build
    "MAQCsubset" # broken build
    "maqcExpression4plex" # broken build
    "mammaPrintData" # broken build
    "maizeprobe" # broken build
    "MafDb_ExAC_r0_3_sites" # broken build
    "MafDb_ESP6500SI_V2_SSA137" # broken build
    "MafDb_ALL_wgs_phase3_release_v5b_20130502" # broken build
    "MafDb_ALL_wgs_phase1_release_v3_20101123" # broken build
    "m20kcod_db" # broken build
    "m10kcod_db" # broken build
    "LungCancerACvsSCCGEO" # broken build
    "lumiRatIDMapping" # broken build
    "lumiRatAll_db" # broken build
    "lumiMouseIDMapping" # broken build
    "lumiMouseAll_db" # broken build
    "lumiHumanIDMapping" # broken build
    "lumiHumanAll_db" # broken build
    "lumiBarnes" # broken build
    "motifStack" # broken build
    "LowMACA" # depends on broken package motifStack
    "dagLogo" # depends on broken package motifStack
    "motifStack" # broken build
    "ListerEtAlBSseq" # broken build
    "fastLiquidAssociation" # depends on broken package LiquidAssociation
    "LiquidAssociation" # broken build
    "leeBamViews" # broken build
    "LAPOINTE_db" # broken build
    "kidpack" # broken build
    "keggorthology" # broken build
    "KEGGdzPathwaysGEO" # broken build
    "KEGGandMetacoreDzPathwaysGEO" # broken build
    "jetset" # broken build
    "JazaeriMetaData_db" # broken build
    "JASPAR2014" # broken build
    "ITALICSData" # broken build
    "ITALICS" # broken build
    "indac_db" # broken build
    "ind1KG" # broken build
    "illuminaRatv1_db" # broken build
    "illuminaMousev2_db" # broken build
    "illuminaMousev1p1_db" # broken build
    "illuminaMousev1_db" # broken build
    "illuminaHumanWGDASLv4_db" # broken build
    "illuminaHumanWGDASLv3_db" # broken build
    "illuminaHumanv4_db" # broken build
    "illuminaHumanv3_db" # broken build
    "illuminaHumanv2_db" # broken build
    "illuminaHumanv2BeadID_db" # broken build
    "illuminaHumanv1_db" # broken build
    "IlluminaHumanMethylation450kprobe" # broken build
    "IlluminaHumanMethylation450k_db" # broken build
    "minfiData" # depends on broken package IlluminaHumanMethylation450kanno_ilmn12_hg19
    "IlluminaHumanMethylation450kanno_ilmn12_hg19" # broken build
    "IlluminaHumanMethylation27k_db" # broken build
    "IlluminaDataTestFiles" # broken build
    "nloptr" # broken build
    "seqHMM" # depends on broken package nloptr
    "iClick" # depends on broken package nloptr
    "rugarch" # depends on broken package nloptr
    "variancePartition" # depends on broken package nloptr
    "tnam" # depends on broken package nloptr
    "RLRsim" # depends on broken package nloptr
    "pedigreemm" # depends on broken package nloptr
    "simr" # depends on broken package nloptr
    "pbkrtest" # depends on broken package nloptr
    "omics" # depends on broken package nloptr
    "piecewiseSEM" # depends on broken package nloptr
    "lmerTest" # depends on broken package nloptr
    "refund" # depends on broken package nloptr
    "gamm4" # depends on broken package nloptr
    "fishmethods" # depends on broken package nloptr
    "lme4" # depends on broken package nloptr
    "nloptr" # broken build
    "hwgcod_db" # broken build
    "HuO22_db" # broken build
    "humanStemCell" # broken build
    "humanomniexpress12v1bCrlmm" # broken build
    "humanomni5quadv1bCrlmm" # broken build
    "humanomni25quadv1bCrlmm" # broken build
    "humanomni1quadv1bCrlmm" # broken build
    "human_db0" # broken build
    "humancytosnp12v2p1hCrlmm" # broken build
    "human660quadv1aCrlmm" # broken build
    "human650v3aCrlmm" # broken build
    "human610quadv1bCrlmm" # broken build
    "human550v3bCrlmm" # broken build
    "human370v1cCrlmm" # broken build
    "human370quadv3cCrlmm" # broken build
    "human1mv1cCrlmm" # broken build
    "human1mduov3bCrlmm" # broken build
    "hugene21sttranscriptcluster_db" # broken build
    "hugene21stprobeset_db" # broken build
    "hugene20sttranscriptcluster_db" # broken build
    "hugene20stprobeset_db" # broken build
    "hugene11sttranscriptcluster_db" # broken build
    "hugene11stprobeset_db" # broken build
    "hugene10stv1probe" # broken build
    "hugene_1_0_st_v1frmavecs" # broken build
    "hugene10sttranscriptcluster_db" # broken build
    "hugene10stprobeset_db" # broken build
    "huex_1_0_st_v2frmavecs" # broken build
    "huex10sttranscriptcluster_db" # broken build
    "huex10stprobeset_db" # broken build
    "hu6800_db" # broken build
    "hu35ksubd_db" # broken build
    "hu35ksubc_db" # broken build
    "hu35ksubb_db" # broken build
    "hu35ksuba_db" # broken build
    "hthgu133b_db" # broken build
    "hthgu133afrmavecs" # broken build
    "hthgu133a_db" # broken build
    "hta20sttranscriptcluster_db" # broken build
    "hta20stprobeset_db" # broken build
    "monocle" # depends on broken package HSMMSingleCell
    "HSMMSingleCell" # broken build
    "HsAgilentDesign026652_db" # broken build
    "Hs6UG171_db" # broken build
    "hs25kresogen_db" # broken build
    "hom_Rn_inp_db" # broken build
    "hom_Mm_inp_db" # broken build
    "hom_Hs_inp_db" # broken build
    "hom_Dr_inp_db" # broken build
    "hom_Dm_inp_db" # broken build
    "hom_Ce_inp_db" # broken build
    "hom_At_inp_db" # broken build
    "hmyriB36" # broken build
    "Hiiragi2013" # broken build
    "HiCDataLymphoblast" # broken build
    "HiCDataHumanIMR90" # broken build
    "hi16cod_db" # broken build
    "hguqiagenv3_db" # broken build
    "hgug4845a_db" # broken build
    "hgug4112a_db" # broken build
    "hgug4111a_db" # broken build
    "hgug4110b_db" # broken build
    "hgug4101a_db" # broken build
    "hgug4100a_db" # broken build
    "hguDKFZ31_db" # broken build
    "hgubeta7_db" # broken build
    "hguatlas13k_db" # broken build
    "hgu95e_db" # broken build
    "hgu95dprobe" # broken build
    "hgu95d_db" # broken build
    "hgu95c_db" # broken build
    "hgu95b_db" # broken build
    "hgu95av2_db" # broken build
    "hgu95av2" # broken build
    "hgu95aprobe" # broken build
    "hgu95a_db" # broken build
    "hgu219_db" # broken build
    "hgu133plus2frmavecs" # broken build
    "hgu133plus2_db" # broken build
    "hgu133b_db" # broken build
    "hgu133afrmavecs" # broken build
    "hgu133a_db" # broken build
    "hgu133a2frmavecs" # broken build
    "hgu133a2_db" # broken build
    "hgfocus_db" # broken build
    "healthyFlowData" # broken build
    "HD2013SGI" # broken build
    "hcg110_db" # broken build
    "harbChIP" # broken build
    "hapmapsnp6" # broken build
    "hapmapsnp5" # broken build
    "hapmap500ksty" # broken build
    "hapmap500knsp" # broken build
    "hapmap370k" # broken build
    "hapmap100kxba" # broken build
    "hapmap100khind" # broken build
    "h5vcData" # broken build
    "h5vc" # broken build
    "h20kcod_db" # broken build
    "h10kcod_db" # broken build
    "GSVAdata" # broken build
    "GSBenchMark" # broken build
    "grndata" # broken build
    "gridGraphics" # broken build
    "RMallow" # broken build
    "QuartPAC" # depends on broken package RMallow
    "GraphPAC" # depends on broken package RMallow
    "RMallow" # broken build
    "goTools" # broken build
    "goProfiles" # broken build
    "MCRestimate" # depends on broken package golubEsets
    "golubEsets" # broken build
    "WGCNA" # depends on broken package GO_db
    "TROM" # depends on broken package GO_db
    "topGO" # depends on broken package GO_db
    "stringgaussnet" # depends on broken package GO_db
    "SLGI" # depends on broken package GO_db
    "Rattus_norvegicus" # depends on broken package GO_db
    "Mus_musculus" # depends on broken package GO_db
    "mdgsa" # depends on broken package GO_db
    "gwascat" # depends on broken package GO_db
    "Homo_sapiens" # depends on broken package GO_db
    "GOSim" # depends on broken package GO_db
    "tRanslatome" # depends on broken package GO_db
    "Rcpi" # depends on broken package GO_db
    "ppiPre" # depends on broken package GO_db
    "BiSEp" # depends on broken package GO_db
    "GOSemSim" # depends on broken package GO_db
    "GOFunction" # depends on broken package GO_db
    "GO_db" # broken build
    "GGdata" # broken build
    "geuvStore" # broken build
    "geuvPack" # broken build
    "GEOsearch" # broken build
    "genomewidesnp6Crlmm" # broken build
    "genomewidesnp5Crlmm" # broken build
    "genomationData" # broken build
    "rgsepd" # depends on broken package geneLenDataBase
    "goseq" # depends on broken package geneLenDataBase
    "geneLenDataBase" # broken build
    "gcspikelite" # broken build
    "gahgu95ecdf" # broken build
    "gahgu95dcdf" # broken build
    "gahgu95ccdf" # broken build
    "gahgu95bcdf" # broken build
    "gahgu95av2cdf" # broken build
    "PREDAsampledata" # depends on broken package gahgu133plus2cdf
    "gahgu133plus2cdf" # broken build
    "gahgu133bcdf" # broken build
    "gahgu133acdf" # broken build
    "FunctionalNetworks" # broken build
    "FunciSNP_data" # broken build
    "fly_db0" # broken build
    "flowWorkspaceData" # broken build
    "FlowSorted_DLPFC_450k" # broken build
    "FlowSorted_Blood_450k" # broken build
    "flowFitExampleData" # broken build
    "ncdfFlow" # depends on broken package flowCore
    "flowViz" # depends on broken package flowCore
    "QUALIFIER" # depends on broken package flowCore
    "flowWorkspace" # depends on broken package flowCore
    "flowUtils" # depends on broken package flowCore
    "plateCore" # depends on broken package flowCore
    "flowVS" # depends on broken package flowCore
    "flowStats" # depends on broken package flowCore
    "FlowSOM" # depends on broken package flowCore
    "flowMeans" # depends on broken package flowCore
    "flowFP" # depends on broken package flowCore
    "flowDiv" # depends on broken package flowCore
    "openCyto" # depends on broken package flowCore
    "flowType" # depends on broken package flowCore
    "flowMerge" # depends on broken package flowCore
    "flowClust" # depends on broken package flowCore
    "flowCore" # broken build
    "Fletcher2013b" # depends on broken package Fletcher2013a
    "Fletcher2013a" # broken build
    "ffpeExampleData" # broken build
    "FEM" # broken build
    "FDb_UCSC_snp137common_hg19" # broken build
    "FDb_UCSC_snp135common_hg19" # broken build
    "skewr" # depends on broken package FDb_InfiniumMethylation_hg19
    "RnBeads" # depends on broken package FDb_InfiniumMethylation_hg19
    "missMethyl" # depends on broken package FDb_InfiniumMethylation_hg19
    "wateRmelon" # depends on broken package FDb_InfiniumMethylation_hg19
    "methyAnalysis" # depends on broken package FDb_InfiniumMethylation_hg19
    "iCheck" # depends on broken package FDb_InfiniumMethylation_hg19
    "lumi" # depends on broken package FDb_InfiniumMethylation_hg19
    "ffpe" # depends on broken package FDb_InfiniumMethylation_hg19
    "methylumi" # depends on broken package FDb_InfiniumMethylation_hg19
    "MethylAid" # depends on broken package FDb_InfiniumMethylation_hg19
    "FDb_InfiniumMethylation_hg19" # broken build
    "FDb_InfiniumMethylation_hg18" # broken build
    "FANTOM3and4CAGE" # broken build
    "facsDorit" # broken build
    "facopy_annot" # broken build
    "xcms" # broken build
    "xcms" # broken build
    "estrogen" # broken build
    "erma" # broken build
    "EnsDb_Rnorvegicus_v79" # broken build
    "EnsDb_Mmusculus_v79" # broken build
    "EnsDb_Mmusculus_v75" # broken build
    "EnsDb_Hsapiens_v79" # broken build
    "EnsDb_Hsapiens_v75" # broken build
    "encoDnaseI" # broken build
    "ELMER" # broken build
    "effects" # depends on broken package nloptr
    "ecoliLeucine" # broken build
    "ecd" # depends on broken package polynom
    "EatonEtAlChIPseq" # broken build
    "dyebiasexamples" # broken build
    "DvDdata" # broken build
    "dsQTL" # broken build
    "DrugVsDiseasedata" # broken build
    "drosophila2_db" # broken build
    "drosophila2cdf" # broken build
    "drosgenome1_db" # broken build
    "dressCheck" # broken build
    "dpcR" # depends on broken package nloptr
    "ReactomePA" # depends on broken package DOSE
    "DOSE" # broken build
    "DonaPLLP2013" # broken build
    "DMRcatedata" # broken build
    "MEAL" # depends on broken package DMRcate
    "DMRcate" # broken build
    "DmelSGI" # broken build
    "DirichletMultinomial" # broken build
    "diggitdata" # broken build
    "DeSousa2013" # broken build
    "derfinderData" # broken build
    "ilc" # depends on broken package demography
    "demography" # broken build
    "davidTiling" # broken build
    "curatedOvarianData" # broken build
    "curatedCRCData" # broken build
    "curatedBreastData" # broken build
    "curatedBladderData" # broken build
    "crmPack" # broken build
    "cosmiq" # depends on broken package xcms
    "COSMIC_67" # broken build
    "CopyNumber450kData" # broken build
    "CopywriteR" # depends on broken package CopyhelpeR
    "CopyhelpeR" # broken build
    "COPDSexualDimorphism_data" # broken build
    "conumee" # broken build
    "ConnectivityMap" # broken build
    "compEpiTools" # broken build
    "CoCiteStats" # broken build
    "MatrixRider" # depends on broken package CNEr
    "TFBSTools" # depends on broken package CNEr
    "CNEr" # broken build
    "DrugVsDisease" # depends on broken package cMap2data
    "cMap2data" # broken build
    "clusterProfiler" # broken build
    "ChIPXpressData" # broken build
    "ChIPXpress" # broken build
    "ChIPseeker" # broken build
    "GUIDEseq" # depends on broken package ChIPpeakAnno
    "FunciSNP" # depends on broken package ChIPpeakAnno
    "ChIPpeakAnno" # broken build
    "chipenrich_data" # broken build
    "ChimpHumanBrainData" # broken build
    "chicken_db0" # broken build
    "ggtut" # depends on broken package cheung2010
    "cheung2010" # broken build
    "ChemmineDrugs" # broken build
    "charmData" # broken build
    "ChAMPdata" # broken build
    "ChAMP" # broken build
    "cgdv17" # broken build
    "ceuhm3" # broken build
    "ceu1kgv" # broken build
    "ceu1kg" # broken build
    "celegans_db" # broken build
    "ccTutorial" # broken build
    "CCl4" # broken build
    "ppiStats" # depends on broken package Category
    "meshr" # depends on broken package Category
    "RforProteomics" # depends on broken package Category
    "interactiveDisplay" # depends on broken package Category
    "gCMAPWeb" # depends on broken package Category
    "gCMAP" # depends on broken package Category
    "ExpressionView" # depends on broken package Category
    "eisa" # depends on broken package Category
    "RNAinteractMAPK" # depends on broken package Category
    "RNAinteract" # depends on broken package Category
    "imageHTS" # depends on broken package Category
    "canceR" # depends on broken package Category
    "phenoTest" # depends on broken package Category
    "Mulder2012" # depends on broken package Category
    "HTSanalyzeR" # depends on broken package Category
    "gespeR" # depends on broken package Category
    "coRNAi" # depends on broken package Category
    "cellHTS2" # depends on broken package Category
    "Category" # broken build
    "canine_db0" # broken build
    "caninecdf" # broken build
    "cancerdata" # broken build
    "BSgenome_Vvinifera_URGI_IGGP12Xv2" # broken build
    "BSgenome_Vvinifera_URGI_IGGP12Xv0" # broken build
    "BSgenome_Osativa_MSU_MSU7" # broken build
    "BSgenome_Gaculeatus_UCSC_gasAcu1_masked" # broken build
    "BSgenome_Gaculeatus_UCSC_gasAcu1" # broken build
    "BSgenome_Ecoli_NCBI_20080805" # broken build
    "BSgenome_Dmelanogaster_UCSC_dm6" # broken build
    "BSgenome_Dmelanogaster_UCSC_dm3_masked" # broken build
    "BSgenome_Dmelanogaster_UCSC_dm3" # broken build
    "BSgenome_Dmelanogaster_UCSC_dm2_masked" # broken build
    "BSgenome_Dmelanogaster_UCSC_dm2" # broken build
    "BSgenome_Celegans_UCSC_ce6" # broken build
    "REDseq" # depends on broken package BSgenome_Celegans_UCSC_ce2
    "BSgenome_Celegans_UCSC_ce2" # broken build
    "BSgenome_Celegans_UCSC_ce10" # broken build
    "BSgenome_Athaliana_TAIR_TAIR9" # broken build
    "BSgenome_Amellifera_UCSC_apiMel2_masked" # broken build
    "BSgenome_Amellifera_UCSC_apiMel2" # broken build
    "BSgenome_Alyrata_JGI_v1" # broken build
    "bronchialIL13" # broken build
    "breastCancerVDX" # broken build
    "breastCancerUPP" # broken build
    "breastCancerUNT" # broken build
    "breastCancerTRANSBIG" # broken build
    "breastCancerNKI" # broken build
    "breastCancerMAINZ" # broken build
    "bovine_db" # broken build
    "beadarrayExampleData" # broken build
    "Basic4Cseq" # broken build
    "BAGS" # broken build
    "AshkenazimSonChr21" # broken build
    "ARRmNormalization" # broken build
    "ARRmData" # broken build
    "arabidopsis_db0" # broken build
    "PCpheno" # depends on broken package apComplex
    "ScISI" # depends on broken package apComplex
    "apComplex" # broken build
    "MMDiff" # depends on broken package AnnotationForge
    "ChIPQC" # depends on broken package AnnotationForge
    "DiffBind" # depends on broken package AnnotationForge
    "systemPipeR" # depends on broken package AnnotationForge
    "ReportingTools" # depends on broken package AnnotationForge
    "CompGO" # depends on broken package AnnotationForge
    "BACA" # depends on broken package AnnotationForge
    "RDAVIDWebService" # depends on broken package AnnotationForge
    "ProCoNA" # depends on broken package AnnotationForge
    "mvGST" # depends on broken package AnnotationForge
    "MineICA" # depends on broken package AnnotationForge
    "maGUI" # depends on broken package AnnotationForge
    "LANDD" # depends on broken package AnnotationForge
    "categoryCompare" # depends on broken package AnnotationForge
    "attract" # depends on broken package AnnotationForge
    "GOstats" # depends on broken package AnnotationForge
    "GGHumanMethCancerPanelv1_db" # depends on broken package AnnotationForge
    "AnnotationForge" # broken build
    "webbioc" # depends on broken package annaffy
    "PGSEA" # depends on broken package annaffy
    "annaffy" # broken build
    "AnalysisPageServer" # broken build
    "AmpAffyExample" # broken build
    "ALLMLL" # broken build
    "AffymetrixDataTestFiles" # broken build
    "affycompData" # broken build
    "adSplit" # broken build
    "adme16cod_db" # broken build
    "ABAEnrichment" # depends on broken package ABAData
    "ABAData" # broken build
    "a4Reporting" # broken build
    "a4Base" # broken build
    "CARrampsOcl" # broken build
    "CardinalWorkflows" # broken build
    "CAFE" # broken build
    "BTSPAS" # broken build
    "bsseqData" # broken build
    "BSgenome_Tguttata_UCSC_taeGut2" # broken build
    "BSgenome_Tguttata_UCSC_taeGut1" # broken build
    "BSgenome_Sscrofa_UCSC_susScr3" # broken build
    "BSgenome_Rnorvegicus_UCSC_rn6" # broken build
    "BSgenome_Rnorvegicus_UCSC_rn5" # broken build
    "BSgenome_Rnorvegicus_UCSC_rn4" # broken build
    "BSgenome_Ptroglodytes_UCSC_panTro3" # broken build
    "BSgenome_Ptroglodytes_UCSC_panTro2" # broken build
    "BSgenome_Mmusculus_UCSC_mm9" # broken build
    "BSgenome_Mmusculus_UCSC_mm8" # broken build
    "BSgenome_Mmusculus_UCSC_mm10" # broken build
    "BSgenome_Mmulatta_UCSC_rheMac3" # broken build
    "BSgenome_Mmulatta_UCSC_rheMac2" # broken build
    "BSgenome_Mfuro_UCSC_musFur1" # broken build
    "BSgenome_Mfascicularis_NCBI_5_0" # broken build
    "BSgenome_Hsapiens_UCSC_hg38" # broken build
    "BSgenome_Hsapiens_UCSC_hg19" # broken build
    "BSgenome_Hsapiens_UCSC_hg18" # broken build
    "BSgenome_Hsapiens_UCSC_hg17" # broken build
    "BSgenome_Hsapiens_NCBI_GRCh38" # broken build
    "BSgenome_Hsapiens_1000genomes_hs37d5" # broken build
    "BSgenome_Ggallus_UCSC_galGal4" # broken build
    "BSgenome_Ggallus_UCSC_galGal3" # broken build
    "BSgenome_Drerio_UCSC_danRer7" # broken build
    "BSgenome_Drerio_UCSC_danRer6" # broken build
    "BSgenome_Drerio_UCSC_danRer5" # broken build
    "BSgenome_Drerio_UCSC_danRer10" # broken build
    "BSgenome_Cfamiliaris_UCSC_canFam3" # broken build
    "BSgenome_Cfamiliaris_UCSC_canFam2" # broken build
    "BSgenome_Btaurus_UCSC_bosTau8" # broken build
    "BSgenome_Btaurus_UCSC_bosTau6" # broken build
    "BSgenome_Btaurus_UCSC_bosTau4" # broken build
    "BSgenome_Btaurus_UCSC_bosTau3" # broken build
    "BSgenome_Athaliana_TAIR_04232008" # broken build
    "BSgenome_Amellifera_BeeBase_assembly4" # broken build
    "bovine_db0" # broken build
    "blowtorch" # broken build
    "blimaTestingData" # broken build
    "biotools" # broken build
    "BiGGR" # broken build
    "BeadArrayUseCases" # broken build
    "bcrypt" # broken build
    "BaySIC" # broken build
    "bayesmix" # broken build
    "bayescount" # broken build
    "BANOVA" # broken build
    "bamdit" # broken build
    "auRoc" # broken build
    "annmap" # broken build
    "Affymoe4302Expr" # broken build
    "Affyhgu133Plus2Expr" # broken build
    "Affyhgu133aExpr" # broken build
    "VIM" # depends on broken package car
    "translateSPSS2R" # depends on broken package car
    "sampleSelection" # depends on broken package car
    "erer" # depends on broken package car
    "systemfit" # depends on broken package car
    "seeg" # depends on broken package car
    "sdcMicro" # depends on broken package car
    "RTN" # depends on broken package car
    "rockchalk" # depends on broken package car
    "RcmdrMisc" # depends on broken package car
    "RcmdrPlugin_Export" # depends on broken package car
    "Rcmdr" # depends on broken package car
    "plsRglm" # depends on broken package car
    "splm" # depends on broken package car
    "Rchoice" # depends on broken package car
    "pglm" # depends on broken package car
    "plm" # depends on broken package car
    "mosaic" # depends on broken package car
    "mixlm" # depends on broken package car
    "miceadds" # depends on broken package car
    "ITEMAN" # depends on broken package car
    "heplots" # depends on broken package car
    "funcy" # depends on broken package car
    "FSA" # depends on broken package car
    "TextoMineR" # depends on broken package car
    "SensoMineR" # depends on broken package car
    "pcaBootPlot" # depends on broken package car
    "ClustGeo" # depends on broken package car
    "FactoMineR" # depends on broken package car
    "TriMatch" # depends on broken package car
    "ez" # depends on broken package car
    "extRemes" # depends on broken package car
    "dynlm" # depends on broken package car
    "drc" # depends on broken package car
    "DJL" # depends on broken package car
    "Deducer" # depends on broken package car
    "TLBC" # depends on broken package car
    "pRoloc" # depends on broken package car
    "LOGIT" # depends on broken package car
    "preprocomb" # depends on broken package car
    "caretEnsemble" # depends on broken package car
    "caret" # depends on broken package car
    "car" # depends on broken package nloptr
    "metaMS" # depends on broken package CAMERA
    "specmine" # depends on broken package CAMERA
    "MAIT" # depends on broken package CAMERA
    "flagme" # depends on broken package CAMERA
    "CAMERA" # depends on broken package xcms
    "BSgenome_Tguttata_UCSC_taeGut1_masked" # depends on broken package BSgenome_Tguttata_UCSC_taeGut1
    "BSgenome_Sscrofa_UCSC_susScr3_masked" # depends on broken package BSgenome_Sscrofa_UCSC_susScr3
    "BSgenome_Rnorvegicus_UCSC_rn5_masked" # depends on broken package BSgenome_Rnorvegicus_UCSC_rn5
    "BSgenome_Rnorvegicus_UCSC_rn4_masked" # depends on broken package BSgenome_Rnorvegicus_UCSC_rn4
    "BSgenome_Ptroglodytes_UCSC_panTro3_masked" # depends on broken package BSgenome_Ptroglodytes_UCSC_panTro3
    "BSgenome_Ptroglodytes_UCSC_panTro2_masked" # depends on broken package BSgenome_Ptroglodytes_UCSC_panTro2
    "BSgenome_Mmusculus_UCSC_mm9_masked" # depends on broken package BSgenome_Mmusculus_UCSC_mm9
    "BSgenome_Mmusculus_UCSC_mm8_masked" # depends on broken package BSgenome_Mmusculus_UCSC_mm8
    "BSgenome_Mmusculus_UCSC_mm10_masked" # depends on broken package BSgenome_Mmusculus_UCSC_mm10
    "DOQTL" # depends on broken package BSgenome_Mmusculus_UCSC_mm10
    "BSgenome_Mmulatta_UCSC_rheMac3_masked" # depends on broken package BSgenome_Mmulatta_UCSC_rheMac3
    "BSgenome_Mmulatta_UCSC_rheMac2_masked" # depends on broken package BSgenome_Mmulatta_UCSC_rheMac2
    "BSgenome_Hsapiens_UCSC_hg38_masked" # depends on broken package BSgenome_Hsapiens_UCSC_hg38
    "BSgenome_Hsapiens_UCSC_hg19_masked" # depends on broken package BSgenome_Hsapiens_UCSC_hg19
    "traseR" # depends on broken package BSgenome_Hsapiens_UCSC_hg19
    "motifRG" # depends on broken package BSgenome_Hsapiens_UCSC_hg19
    "CODEX" # depends on broken package BSgenome_Hsapiens_UCSC_hg19
    "oneChannelGUI" # depends on broken package BSgenome_Hsapiens_UCSC_hg19
    "chimera" # depends on broken package BSgenome_Hsapiens_UCSC_hg19
    "BSgenome_Hsapiens_UCSC_hg18_masked" # depends on broken package BSgenome_Hsapiens_UCSC_hg18
    "BSgenome_Hsapiens_UCSC_hg17_masked" # depends on broken package BSgenome_Hsapiens_UCSC_hg17
    "BSgenome_Ggallus_UCSC_galGal4_masked" # depends on broken package BSgenome_Ggallus_UCSC_galGal4
    "BSgenome_Ggallus_UCSC_galGal3_masked" # depends on broken package BSgenome_Ggallus_UCSC_galGal3
    "BSgenome_Drerio_UCSC_danRer7_masked" # depends on broken package BSgenome_Drerio_UCSC_danRer7
    "InPAS" # depends on broken package BSgenome_Drerio_UCSC_danRer7
    "cleanUpdTSeq" # depends on broken package BSgenome_Drerio_UCSC_danRer7
    "BSgenome_Drerio_UCSC_danRer6_masked" # depends on broken package BSgenome_Drerio_UCSC_danRer6
    "BSgenome_Drerio_UCSC_danRer5_masked" # depends on broken package BSgenome_Drerio_UCSC_danRer5
    "BSgenome_Cfamiliaris_UCSC_canFam3_masked" # depends on broken package BSgenome_Cfamiliaris_UCSC_canFam3
    "BSgenome_Cfamiliaris_UCSC_canFam2_masked" # depends on broken package BSgenome_Cfamiliaris_UCSC_canFam2
    "BSgenome_Btaurus_UCSC_bosTau6_masked" # depends on broken package BSgenome_Btaurus_UCSC_bosTau6
    "BSgenome_Btaurus_UCSC_bosTau4_masked" # depends on broken package BSgenome_Btaurus_UCSC_bosTau4
    "BSgenome_Btaurus_UCSC_bosTau3_masked" # depends on broken package BSgenome_Btaurus_UCSC_bosTau3
    "brms" # depends on broken package htmltools
    "brainGraph" # broken build
    "boral" # depends on broken package R2jags
    "bmeta" # depends on broken package R2jags
    "BLCOP" # depends on broken package fPortfolio
    "bgmm" # depends on broken package nloptr
    "BEST" # depends on broken package jagsUI
    "bdynsys" # depends on broken package nloptr
    "BCA" # depends on broken package nloptr
    "BayesMed" # depends on broken package R2jags
    "bayesPop" # depends on broken package bayesLife
    "bayesLife" # depends on broken package nloptr
    "ath1121501_db" # depends on broken package org_At_tair_db
    "arrayQualityMetrics" # broken build
    "arrayMvout" # depends on broken package rgl
    "ArrayExpressHTS" # broken build
    "mi" # depends on broken package arm
    "interplot" # depends on broken package arm
    "arm" # depends on broken package nloptr
    "alsace" # depends on broken package nloptr
    "ag_db" # depends on broken package org_At_tair_db
    "AgiMicroRna" # depends on broken package affycoretools
    "affycoretools" # depends on broken package ReportingTools
    "AER" # depends on broken package nloptr
    "adhoc" # depends on broken package htmltools
    "adabag" # depends on broken package nloptr
    "abd" # depends on broken package nloptr
    "a4" # depends on broken package htmltools
    "Zelig" # depends on broken package AER
    "REndo" # depends on broken package AER
    "rdd" # depends on broken package AER
    "clusterSEs" # depends on broken package AER
    "Actigraphy" # Build Is Broken
    "afex" # depends on broken package nlopt-2.4.2
    "agRee" # depends on broken package nlopt-2.4.2
    "aLFQ" # depends on broken package nlopt-2.4.2
    "alr3" # depends on broken package nlopt-2.4.2
    "alr4" # depends on broken package nlopt-2.4.2
    "alsace" # depends on broken nloptr-1.0.4
    "anacor" # depends on broken package nlopt-2.4.2
    "aods3" # depends on broken package nlopt-2.4.2
    "apaTables" # depends on broken package r-car-2.1-0
    "apt" # depends on broken package nlopt-2.4.2
    "ArfimaMLM" # depends on broken package nlopt-2.4.2
    "ART" # depends on broken package ar-car-2.1-0
    "ARTool" # depends on broken package nlopt-2.4.2
    "AutoModel" # depends on broken package r-car-2.1-0
    "bapred" # depends on broken package r-lme4-1.1-9
    "bartMachine" # depends on broken package nlopt-2.4.2
    "bayesDem" # depends on broken package nlopt-2.4.2
    "Bayesthresh" # depends on broken package nlopt-2.4.2
    "BBRecapture" # depends on broken package nlopt-2.4.2
    "BIFIEsurvey" # depends on broken package nlopt-2.4.2
    "bigGP" # build is broken
    "bioassayR" # broken build
    "BiodiversityR" # depends on broken package nlopt-2.4.2
    "birte" # build is broken
    "blmeco" # depends on broken package nlopt-2.4.2
    "blme" # depends on broken package nlopt-2.4.2
    "bmd" # depends on broken package nlopt-2.4.2
    "bmem" # depends on broken package nlopt-2.4.2
    "bootnet" # depends on broken package nlopt-2.4.2
    "boss" # depends on broken package nlopt-2.4.2
    "BradleyTerry2" # depends on broken package nlopt-2.4.2
    "BrailleR" # broken build
    "BRugs" # build is broken
    "BubbleTree" # depends on broken package r-biovizBase-1.17.2
    "CADFtest" # depends on broken package nlopt-2.4.2
    "cAIC4" # depends on broken package nlopt-2.4.2
    "candisc" # depends on broken package nlopt-2.4.2
    "carcass" # depends on broken package nlopt-2.4.2
    "Causata" # broken build
    "CCpop" # depends on broken package nlopt-2.4.2
    "ChainLadder" # depends on broken package nlopt-2.4.2
    "ChIPComp" # depends on broken package r-Rsamtools-1.21.18
    "chipenrich" # build is broken
    "chipPCR" # depends on broken nloptr-1.0.4
    "climwin" # depends on broken package nlopt-2.4.2
    "CLME" # depends on broken package nlopt-2.4.2
    "clpAPI" # build is broken
    "clusterPower" # depends on broken package nlopt-2.4.2
    "clusterSEs" # depends on broken AER-1.2-4
    "ClustGeo" # depends on broken FactoMineR-1.31.3
    "CNORfuzzy" # depends on broken package nlopt-2.4.2
    "CNVPanelizer" # depends on broken cn.mops-1.15.1
    "colorscience"
    "compendiumdb" # broken build
    "conformal" # depends on broken package nlopt-2.4.2
    "corHMM" # depends on broken package nlopt-2.4.2
    "CosmoPhotoz" # depends on broken package nlopt-2.4.2
    "covmat" # depends on broken package r-VIM-4.4.1
    "cpgen" # depends on broken package r-pedigreemm-0.3-3
    "cplexAPI" # build is broken
    "CrypticIBDcheck" # depends on broken package nlopt-2.4.2
    "ctsem" # depends on broken package r-OpenMx-2.2.6
    "cudaBayesreg" # build is broken
    "curvHDR" # broken build
    "cytofkit" # broken build
    "dagbag" # build is broken
    "DAMisc" # depends on broken package nlopt-2.4.2
    "datafsm" # depends on broken package r-caret-6.0-52
    "dbConnect" # broken build
    "DeducerExtras" # depends on broken package nlopt-2.4.2
    "DeducerPlugInExample" # depends on broken package nlopt-2.4.2
    "DeducerPlugInScaling" # depends on broken package nlopt-2.4.2
    "DeducerSpatial" # depends on broken package nlopt-2.4.2
    "DeducerSurvival" # depends on broken package nlopt-2.4.2
    "DeducerText" # depends on broken package nlopt-2.4.2
    "DiagTest3Grp" # depends on broken package nlopt-2.4.2
    "difR" # depends on broken package nlopt-2.4.2
    "DistatisR" # depends on broken package nlopt-2.4.2
    "diveRsity" # depends on broken package nlopt-2.4.2
    "doMPI" # build is broken
    "dpa" # depends on broken package nlopt-2.4.2
    "dpcR" # depends on broken nloptr-1.0.4
    "drfit" # depends on broken package nlopt-2.4.2
    "drsmooth" # depends on broken package nlopt-2.4.2
    "dupRadar" # depends on broken package r-Rsubread-1.19.5
    "easyanova" # depends on broken package nlopt-2.4.2
    "edge" # depends on broken package nlopt-2.4.2
    "eeptools" # depends on broken package nlopt-2.4.2
    "EffectLiteR" # depends on broken package nlopt-2.4.2
    "EMA" # depends on broken package nlopt-2.4.2
    "EnQuireR" # depends on broken package nlopt-2.4.2
    "EnrichmentBrowser" # depends on broken package r-EDASeq-2.3.2
    "episplineDensity" # depends on broken package nlopt-2.4.2
    "epr" # depends on broken package nlopt-2.4.2
    "erma" # depends on broken GenomicFiles-1.5.4
    "ESKNN" # depends on broken package r-caret-6.0-52
    "evobiR" # broken build
    "facopy" # depends on broken package nlopt-2.4.2
    "Factoshiny" # depends on broken package nlopt-2.4.2
    "faoutlier" # depends on broken package nlopt-2.4.2
    "fastR" # depends on broken package nlopt-2.4.2
    "FDRreg" # depends on broken package nlopt-2.4.2
    "flowBeads" # broken build
    "flowBin" # broken build
    "flowCHIC" # broken build
    "flowClean" # broken build
    "flowDensity" # depends on broken package nlopt-2.4.2
    "flowFit" # broken build
    "flowMatch" # broken build
    "flowPeaks" # build is broken
    "flowQB" # broken build
    "flowQ" # build is broken
    "flowTrans" # broken build
    "freqweights" # depends on broken package nlopt-2.4.2
    "fscaret" # depends on broken package nlopt-2.4.2
    "fxregime" # depends on broken package nlopt-2.4.2
    "gamclass" # depends on broken package nlopt-2.4.2
    "gcmr" # depends on broken package nlopt-2.4.2
    "GDAtools" # depends on broken package nlopt-2.4.2
    "genridge" # depends on broken package nlopt-2.4.2
    "GEWIST" # depends on broken package nlopt-2.4.2
    "gimme" # depends on broken package nlopt-2.4.2
    "gmatrix" # depends on broken package cudatoolkit-5.5.22
    "GPC" # broken build
    "gplm" # depends on broken package nlopt-2.4.2
    "gputools" # depends on broken package cudatoolkit-5.5.22
    "granova" # depends on broken package nlopt-2.4.2
    "graphicalVAR" # depends on broken package nlopt-2.4.2
    "GraphPCA" # depends on broken package nlopt-2.4.2
    "GUIProfiler" # broken build
    "GWAF" # depends on broken package nlopt-2.4.2
    "h5" # build is broken
    "hbsae" # depends on broken package nlopt-2.4.2
    "hierGWAS"
    "HierO" # Build Is Broken
    "highriskzone"
    "HilbertVisGUI" # Build Is Broken
    "HiPLARM" # Build Is Broken
    "HistDAWass" # depends on broken package nlopt-2.4.2
    "HLMdiag" # depends on broken package nlopt-2.4.2
    "HydeNet" # broken build
    "hysteresis" # depends on broken package nlopt-2.4.2
    "IATscores" # depends on broken package nlopt-2.4.2
    "ibd" # depends on broken package nlopt-2.4.2
    "iccbeta" # depends on broken package nlopt-2.4.2
    "ifaTools" # depends on broken package r-OpenMx-2.2.6
    "imager" # broken build
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
    "IVAS" # depends on broken package nlopt-2.4.2
    "ivpack" # depends on broken package nlopt-2.4.2
    "JAGUAR" # depends on broken package nlopt-2.4.2
    "jetset"
    "joda" # depends on broken package nlopt-2.4.2
    "jomo" # build is broken
    "learnstats" # depends on broken package nlopt-2.4.2
    "lefse" # build is broken
    "LMERConvenienceFunctions" # depends on broken package nlopt-2.4.2
    "lmSupport" # depends on broken package nlopt-2.4.2
    "LogisticDx" # depends on broken package nlopt-2.4.2
    "longpower" # depends on broken package nlopt-2.4.2
    "LOST" # broken build
    "mAPKL" # build is broken
    "maPredictDSC" # depends on broken package nlopt-2.4.2
    "marked" # depends on broken package nlopt-2.4.2
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
    "metacom" # broken build
    "metagear" # build is broken
    "metaMix" # build is broken
    "metaplus" # depends on broken package nlopt-2.4.2
    "Metatron" # depends on broken package nlopt-2.4.2
    "metaX" # depends on broken package r-CAMERA-1.25.2
    "micEconAids" # depends on broken package nlopt-2.4.2
    "micEconCES" # depends on broken package nlopt-2.4.2
    "micEconSNQP" # depends on broken package nlopt-2.4.2
    "MigClim" # Build Is Broken
    "migui" # depends on broken package nlopt-2.4.2
    "missDeaths"
    "missMDA" # depends on broken package nlopt-2.4.2
    "mixAK" # depends on broken package nlopt-2.4.2
    "MixMAP" # depends on broken package nlopt-2.4.2
    "mlmRev" # depends on broken package nlopt-2.4.2
    "MLSeq" # depends on broken package nlopt-2.4.2
    "mlVAR" # depends on broken package nlopt-2.4.2
    "mongolite" # build is broken
    "monogeneaGM" # broken build
    "motifbreakR" # depends on broken package r-BSgenome-1.37.5
    "MSstats" # depends on broken package nlopt-2.4.2
    "multiDimBio" # depends on broken package nlopt-2.4.2
    "MultiRR" # depends on broken package nlopt-2.4.2
    "muma" # depends on broken package nlopt-2.4.2
    "munsellinterpol"
    "mutossGUI" # build is broken
    "mvinfluence" # depends on broken package nlopt-2.4.2
    "mvMORPH" # broken build
    "nCal" # depends on broken package nlopt-2.4.2
    "netbenchmark" # build is broken
    "netresponse" # broken build
    "NGScopy"
    "NHPoisson" # depends on broken package nlopt-2.4.2
    "nlts" # broken build
    "nonrandom" # depends on broken package nlopt-2.4.2
    "NORRRM" # build is broken
    "npIntFactRep" # depends on broken package nlopt-2.4.2
    "NSM3" # broken build
    "OmicsMarkeR" # depends on broken package nlopt-2.4.2
    "ordBTL" # depends on broken package nlopt-2.4.2
    "ordPens" # depends on broken package r-lme4-1.1-9
    "OUwie" # depends on broken package nlopt-2.4.2
    "pacman" # broken build
    "PADOG" # build is broken
    "pamm" # depends on broken package nlopt-2.4.2
    "panelAR" # depends on broken package nlopt-2.4.2
    "papeR" # depends on broken package nlopt-2.4.2
    "parboost" # depends on broken package nlopt-2.4.2
    "parma" # depends on broken package nlopt-2.4.2
    "PatternClass" # build is broken
    "PBD" # broken build
    "PBImisc" # depends on broken package nlopt-2.4.2
    "pcaBootPlot" # depends on broken FactoMineR-1.31.3
    "pcaL1" # build is broken
    "pequod" # depends on broken package nlopt-2.4.2
    "PharmacoGx"
    "PhenStat" # depends on broken package nlopt-2.4.2
    "phia" # depends on broken package nlopt-2.4.2
    "phylocurve" # depends on broken package nlopt-2.4.2
    "plfMA" # broken build
    "plsRbeta" # depends on broken package nlopt-2.4.2
    "plsRcox" # depends on broken package nlopt-2.4.2
    "pmclust" # build is broken
    "pmm" # depends on broken package nlopt-2.4.2
    "pomp" # depends on broken package nlopt-2.4.2
    "predictmeans" # depends on broken package nlopt-2.4.2
    "prLogistic" # depends on broken package nlopt-2.4.2
    "pRolocGUI" # depends on broken package nlopt-2.4.2
    "ProteomicsAnnotationHubData" # depends on broken package r-AnnotationHub-2.1.40
    "PSAboot" # depends on broken package nlopt-2.4.2
    "ptw" # depends on broken nloptr-1.0.4
    "pvca" # depends on broken package nlopt-2.4.2
    "PythonInR"
    "QFRM"
    "qtlnet" # depends on broken package nlopt-2.4.2
    "quantification" # depends on broken package nlopt-2.4.2
    "R2STATS" # depends on broken package nlopt-2.4.2
    "RADami" # broken build
    "raincpc" # build is broken
    "rainfreq" # build is broken
    "RareVariantVis" # depends on broken VariantAnnotation-1.15.19
    "rasclass" # depends on broken package nlopt-2.4.2
    "RBerkeley"
    "Rblpapi" # broken build
    "rbundler" # broken build
    "rcellminer" # broken build
    "rCGH" # depends on broken package r-affy-1.47.1
    "RchyOptimyx" # broken build
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
    "Rcplex" # Build Is Broken
    "RcppAPT" # Build Is Broken
    "RcppRedis" # build is broken
    "rcrypt" # broken build
    "rddtools" # depends on broken package r-AER-1.2-4
    "rDEA" # build is broken
    "RDieHarder" # build is broken
    "recluster" # broken build
    "referenceIntervals" # depends on broken package nlopt-2.4.2
    "refund_shiny" # depends on broken package r-refund-0.1-13
    "regRSM" # broken build
    "REST" # depends on broken package nlopt-2.4.2
    "Rgnuplot"
    "rLindo" # build is broken
    "rMAT" # build is broken
    "rmgarch" # depends on broken package nlopt-2.4.2
    "rminer" # depends on broken package nlopt-2.4.2
    "RNAither" # depends on broken package nlopt-2.4.2
    "RnavGraph" # build is broken
    "robustlmm" # depends on broken package nlopt-2.4.2
    "RockFab" # broken build
    "rols" # build is broken
    "Rphylopars" # broken build
    "rpubchem" # depends on broken package nlopt-2.4.2
    "RQuantLib" # build is broken
    "rr" # depends on broken package nlopt-2.4.2
    "RSAP" # build is broken
    "RSDA" # depends on broken package nlopt-2.4.2
    "RStoolbox" # depends on broken package r-caret-6.0-52
    "rTableICC" # broken build
    "rUnemploymentData" # broken build
    "RVAideMemoire" # depends on broken package nlopt-2.4.2
    "RVFam" # depends on broken package nlopt-2.4.2
    "RWebServices" # broken build
    "ryouready" # depends on broken package nlopt-2.4.2
    "sdcMicroGUI" # depends on broken package nlopt-2.4.2
    "semdiag" # depends on broken package nlopt-2.4.2
    "semGOF" # depends on broken package nlopt-2.4.2
    "semPlot" # depends on broken package nlopt-2.4.2
    "SensMixed" # depends on broken package r-lme4-1.1-9
    "SeqFeatR" # broken build
    "SeqGrapheR" # Build Is Broken
    "seqTools" # build is broken
    "simPop" # depends on broken package r-VIM-4.4.1
    "sjPlot" # depends on broken package nlopt-2.4.2
    "SOD" # depends on broken package cudatoolkit-5.5.22
    "sortinghat" # broken build
    "SoyNAM" # depends on broken package r-lme4-1.1-8
    "spacom" # depends on broken package nlopt-2.4.2
    "spade" # broken build
    "specificity" # depends on broken package nlopt-2.4.2
    "spoccutils" # depends on broken spocc-0.3.0
    "ssmrob" # depends on broken package nlopt-2.4.2
    "Statomica" # broken build
    "stcm" # depends on broken package nlopt-2.4.2
    "stepp" # depends on broken package nlopt-2.4.2
    "Surrogate" # depends on broken package nlopt-2.4.2
    "sybilSBML" # build is broken
    "systemPipeRdata" # broken build
    "TCGAbiolinks" # depends on broken package r-affy-1.47.1
    "TcGSA" # depends on broken package nlopt-2.4.2
    "TDMR" # depends on broken package nlopt-2.4.2
    "TED" # broken build
    "tigerstats" # depends on broken package nlopt-2.4.2
    "TKF" # broken build
    "tmle" # broken build
    "translateSPSS2R" # depends on broken car-2.0-25
    "traseR"
    "TSdist" # broken build
    "TSMySQL" # broken build
    "umx" # depends on broken package r-OpenMx-2.2.6
    "userfriendlyscience" # depends on broken package nlopt-2.4.2
    "varComp" # depends on broken package r-lme4-1.1-9
    "VBmix" # broken build
    "VIMGUI" # depends on broken package nlopt-2.4.2
    "vows" # depends on broken package nlopt-2.4.2
    "wfe" # depends on broken package nlopt-2.4.2
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
