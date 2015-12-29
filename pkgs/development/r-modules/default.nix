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
    "arfima" # broken build
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
    "capm" # depends on broken package htmltools
    "cape" # depends on broken package rgl
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
    "brainR" # depends on broken package rgl
    "brainGraph" # broken build
    "mcaGUI" # depends on broken package bpca
    "bpca" # depends on broken package rgl
    "boral" # depends on broken package R2jags
    "bootsPLS" # depends on broken package rgl
    "bmeta" # depends on broken package R2jags
    "BLCOP" # depends on broken package fPortfolio
    "birdring" # depends on broken package rgl
    "biplotbootGUI" # depends on broken package rgl
    "bios2mds" # depends on broken package rgl
    "Biocomb" # depends on broken package rgl
    "bgmm" # depends on broken package nloptr
    "BEST" # depends on broken package jagsUI
    "BEDASSLE" # depends on broken package rgl
    "bdynsys" # depends on broken package nloptr
    "bdvis" # depends on broken package htmltools
    "bde" # depends on broken package htmltools
    "Bclim" # depends on broken package rgl
    "Bchron" # depends on broken package rgl
    "BCA" # depends on broken package nloptr
    "BBEST" # depends on broken package htmltools
    "BayesMed" # depends on broken package R2jags
    "bayesPop" # depends on broken package bayesLife
    "bayesLife" # depends on broken package nloptr
    "backtestGraphics" # depends on broken package htmltools
    "ath1121501_db" # depends on broken package org_At_tair_db
    "arrayQualityMetrics" # broken build
    "arrayMvout" # depends on broken package rgl
    "ArrayExpressHTS" # broken build
    "mi" # depends on broken package arm
    "interplot" # depends on broken package arm
    "arm" # depends on broken package nloptr
    "Anthropometry" # depends on broken package rgl
    "AnnotationHub" # depends on broken package htmltools
    "animalTrack" # depends on broken package rgl
    "analogueExtra" # depends on broken package rgl
    "ampliQueso" # depends on broken package rgl
    "alsace" # depends on broken package nloptr
    "alphashape3d" # depends on broken package rgl
    "ag_db" # depends on broken package org_At_tair_db
    "AFM" # depends on broken package rgl
    "AgiMicroRna" # depends on broken package affycoretools
    "affycoretools" # depends on broken package ReportingTools
    "AER" # depends on broken package nloptr
    "adhoc" # depends on broken package htmltools
    "adegenet" # depends on broken package htmltools
    "AdaptGauss" # depends on broken package htmltools
    "adabag" # depends on broken package nloptr
    "abd" # depends on broken package nloptr
    "abcdeFBA" # depends on broken package rgl
    "a4Classif" # depends on broken package htmltools
    "a4" # depends on broken package htmltools
    "RefNet" # depends on broken package AnnotationHub
    "pwOmics" # depends on broken package AnnotationHub
    "gwascat" # depends on broken package AnnotationHub
    "grasp2db" # depends on broken package AnnotationHub
    "EnsDb_Rnorvegicus_v79" # depends on broken package AnnotationHub
    "EnsDb_Rnorvegicus_v75" # depends on broken package AnnotationHub
    "EnsDb_Mmusculus_v79" # depends on broken package AnnotationHub
    "EnsDb_Mmusculus_v75" # depends on broken package AnnotationHub
    "EnsDb_Hsapiens_v79" # depends on broken package AnnotationHub
    "EnsDb_Hsapiens_v75" # depends on broken package AnnotationHub
    "REDseq" # depends on broken package AnnotationHub
    "GUIDEseq" # depends on broken package AnnotationHub
    "ggtut" # depends on broken package AnnotationHub
    "FunciSNP" # depends on broken package AnnotationHub
    "ChIPpeakAnno" # depends on broken package AnnotationHub
    "ensembldb" # depends on broken package AnnotationHub
    "AnnotationHubData" # depends on broken package AnnotationHub
    "Zelig" # depends on broken package AER
    "REndo" # depends on broken package AER
    "rdd" # depends on broken package AER
    "clusterSEs" # depends on broken package AER
    "StAMPP" # depends on broken package adegenet
    "strataG" # depends on broken package adegenet
    "popprxl" # depends on broken package adegenet
    "poppr" # depends on broken package adegenet
    "pegas" # depends on broken package adegenet
    "outbreaker" # depends on broken package adegenet
    "PopGenReport" # depends on broken package adegenet
    "mmod" # depends on broken package adegenet
    "hierfstat" # depends on broken package adegenet
    "apex" # depends on broken package adegenet
    "AFLPsim" # depends on broken package adegenet
    "treescape" # depends on broken package adegenet
    "phylosignal" # depends on broken package adegenet
    "adephylo" # depends on broken package adegenet
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
    "caRpools" # broken build
    "Causata" # broken build
    "CCpop" # depends on broken package nlopt-2.4.2
    "ChainLadder" # depends on broken package nlopt-2.4.2
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
    "COHCAP" # build is broken
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
    "diggit" # broken build
    "discSurv" # depends on broken package nlopt-2.4.2
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
    "EnrichedHeatmap" # broken build
    "EnrichmentBrowser" # depends on broken package r-EDASeq-2.3.2
    "episplineDensity" # depends on broken package nlopt-2.4.2
    "epr" # depends on broken package nlopt-2.4.2
    "erma" # depends on broken GenomicFiles-1.5.4
    "ESKNN" # depends on broken package r-caret-6.0-52
    "evobiR" # broken build
    "evolqg" # broken build
    "facopy" # depends on broken package nlopt-2.4.2
    "Factoshiny" # depends on broken package nlopt-2.4.2
    "faoutlier" # depends on broken package nlopt-2.4.2
    "fastR" # depends on broken package nlopt-2.4.2
    "FDRreg" # depends on broken package nlopt-2.4.2
    "FedData" # broken build
    "FindMyFriends" # broken build
    "flowBeads" # broken build
    "flowBin" # broken build
    "flowcatchR" # broken build
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
    "genefu" # broken build
    "genotypeeval" # depends on broken package r-rtracklayer-1.29.12
    "genridge" # depends on broken package nlopt-2.4.2
    "GEWIST" # depends on broken package nlopt-2.4.2
    "gfcanalysis" # broken build
    "gimme" # depends on broken package nlopt-2.4.2
    "gmatrix" # depends on broken package cudatoolkit-5.5.22
    "GPC" # broken build
    "gplm" # depends on broken package nlopt-2.4.2
    "gputools" # depends on broken package cudatoolkit-5.5.22
    "granova" # depends on broken package nlopt-2.4.2
    "graphicalVAR" # depends on broken package nlopt-2.4.2
    "GraphPCA" # depends on broken package nlopt-2.4.2
    "GUIProfiler" # broken build
    "Guitar" # depends on broken package r-GenomicAlignments-1.5.18
    "GWAF" # depends on broken package nlopt-2.4.2
    "h5" # build is broken
    "hbsae" # depends on broken package nlopt-2.4.2
    "HCsnip" # broken build
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
    "IVAS" # depends on broken package nlopt-2.4.2
    "ivpack" # depends on broken package nlopt-2.4.2
    "JAGUAR" # depends on broken package nlopt-2.4.2
    "jetset"
    "joda" # depends on broken package nlopt-2.4.2
    "jomo" # build is broken
    "ldblock" # depends on broken package r-snpStats-1.19.3
    "learnstats" # depends on broken package nlopt-2.4.2
    "lefse" # build is broken
    "lessR" # depends on broken package nlopt-2.4.2
    "lmdme" # build is broken
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
    "MetaLandSim" # broken build
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
    "msa" # broken build
    "MSstats" # depends on broken package nlopt-2.4.2
    "multiDimBio" # depends on broken package nlopt-2.4.2
    "MultiRR" # depends on broken package nlopt-2.4.2
    "muma" # depends on broken package nlopt-2.4.2
    "munsellinterpol"
    "mutossGUI" # build is broken
    "mvinfluence" # depends on broken package nlopt-2.4.2
    "mvMORPH" # broken build
    "myvariant" # depends on broken package r-VariantAnnotation-1.15.31
    "nCal" # depends on broken package nlopt-2.4.2
    "netbenchmark" # build is broken
    "netresponse" # broken build
    "NetSAM" # broken build
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
    "paleotree" # broken build
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
    "predictionet" # broken build
    "predictmeans" # depends on broken package nlopt-2.4.2
    "prLogistic" # depends on broken package nlopt-2.4.2
    "pRolocGUI" # depends on broken package nlopt-2.4.2
    "ProteomicsAnnotationHubData" # depends on broken package r-AnnotationHub-2.1.40
    "PSAboot" # depends on broken package nlopt-2.4.2
    "ptw" # depends on broken nloptr-1.0.4
    "purge" # depends on broken package r-lme4-1.1-9
    "pvca" # depends on broken package nlopt-2.4.2
    "PythonInR"
    "QFRM"
    "qtlnet" # depends on broken package nlopt-2.4.2
    "quantification" # depends on broken package nlopt-2.4.2
    "R2STATS" # depends on broken package nlopt-2.4.2
    "RADami" # broken build
    "raincpc" # build is broken
    "rainfreq" # build is broken
    "RAM" # broken build
    "RareVariantVis" # depends on broken VariantAnnotation-1.15.19
    "rasclass" # depends on broken package nlopt-2.4.2
    "rase" # broken build
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
    "rscala" # build is broken
    "RSDA" # depends on broken package nlopt-2.4.2
    "RStoolbox" # depends on broken package r-caret-6.0-52
    "rTableICC" # broken build
    "rUnemploymentData" # broken build
    "RVAideMemoire" # depends on broken package nlopt-2.4.2
    "RVFam" # depends on broken package nlopt-2.4.2
    "RWebServices" # broken build
    "ryouready" # depends on broken package nlopt-2.4.2
    "saps" # broken build
    "scmamp" # broken build
    "sdcMicroGUI" # depends on broken package nlopt-2.4.2
    "sejmRP" # depends on broken package r-rvest-0.3.0
    "semdiag" # depends on broken package nlopt-2.4.2
    "semGOF" # depends on broken package nlopt-2.4.2
    "semPlot" # depends on broken package nlopt-2.4.2
    "SensMixed" # depends on broken package r-lme4-1.1-9
    "SeqFeatR" # broken build
    "SeqGrapheR" # Build Is Broken
    "seqTools" # build is broken
    "SigCheck" # broken build
    "simPop" # depends on broken package r-VIM-4.4.1
    "simulatorZ" # broken build
    "sjPlot" # depends on broken package nlopt-2.4.2
    "SOD" # depends on broken package cudatoolkit-5.5.22
    "sortinghat" # broken build
    "SoyNAM" # depends on broken package r-lme4-1.1-8
    "spacom" # depends on broken package nlopt-2.4.2
    "spade" # broken build
    "spdynmod" # broken build
    "specificity" # depends on broken package nlopt-2.4.2
    "spoccutils" # depends on broken spocc-0.3.0
    "spsann" # depends on broken package r-pedometrics-0.6-2
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
