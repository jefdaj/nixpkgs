# This packages BioPerl for Nix. I plan to submit it upstream as a pull request,
# so hopefully it'll be incorporated into nixpkgs and no longer needed here.

# TODO fix up the licenses so they're valid for a pull request

# TODO is perl redundant since we have buildPerlModule?
{ perl, perlPackages }:

let myPerlPackages = with perlPackages; perlPackages // rec {
  # TODO prevent trying this:
  # Waiting for remote acedb regression database to start up.  This may take a few minutes.
  # Couldn't establish connection to database.  Aborting tests.
  AcePerl = buildPerlPackage rec {
    name = "AcePerl-1.92";
    src = fetchurl {
      url = "mirror://cpan/authors/id/L/LD/LDS/${name}.tar.gz";
      sha256 = "2c97ca2be3b859e4a3bc35d706da9829a30aead0206e43f00d0136d995ae783c";
    };
    propagatedBuildInputs = [ CacheCache ];
    meta = {
      # license = stdenv.lib.licenses.unknown;
    };
    dontTest = true;
  };
  AlgorithmMunkres = buildPerlPackage rec {
    name = "Algorithm-Munkres-0.08";
    src = fetchurl {
      url = "mirror://cpan/authors/id/T/TP/TPEDERSE/${name}.tar.gz";
      sha256 = "196bcda3984b179cedd847a7c16666b4f9741c07f611a65490d9e7f4b7a55626";
    };
    meta = {
      description = "Munkres.pm";
      # license = stdenv.lib.licenses.unknown;
    };
  };
 # TODO what's up with this one?
  BioASN1EntrezGene = buildPerlPackage rec {
    name = "Bio-ASN1-EntrezGene-1.72";
    src = fetchurl {
      url = "mirror://cpan/authors/id/C/CJ/CJFIELDS/${name}.tar.gz";
      sha256 = "7f55f69cccfab37d976338ed77d245a62a44b03b7b9954484d8976eab14d575b";
    };
    buildInputs = [ perl ];
    propagatedBuildInputs = [ BioPerl ];
    meta = {
      homepage = http://search.cpan.org/dist/Bio-ASN1-EntrezGene;
      description = "Regular expression-based Perl Parser for NCBI Entrez Gene";
      license = with stdenv.lib.licenses; [ artistic1 gpl1Plus ];
    };
  };
  BioPhylo = buildPerlPackage rec {
    name = "Bio-Phylo-0.58";
    src = fetchurl {
      url = "mirror://cpan/authors/id/R/RV/RVOSA/${name}.tar.gz";
      sha256 = "b8bbd3ea0d2029abac7c8119ef84d607d9c5a226477e8955bc38bac99d44167c";
    };
    meta = {
      homepage = http://biophylo.blogspot.com/;
      description = "An object-oriented Perl toolkit for analyzing and manipulating phyloinformatic data";
      license = with stdenv.lib.licenses; [ artistic1 gpl1Plus ];
    };
  };
  ConvertBinaryC = buildPerlPackage rec {
    name = "Convert-Binary-C-0.78";
    src = fetchurl {
      url = "mirror://cpan/authors/id/M/MH/MHX/${name}.tar.gz";
      sha256 = "24008c3f89117005d308bb2fd2317db6d086a265be6e98855109bbc12a52f2ea";
    };
    meta = {
      homepage = http://search.cpan.org/~mhx/Convert-Binary-C/;
      description = "Binary Data Conversion using C Types";
      license = with stdenv.lib.licenses; [ artistic1 gpl1Plus ];
    };
  };
#   DB_File = buildPerlPackage rec {
#     name = "DB_File-1.838";
#     src = fetchurl {
#       url = "mirror://cpan/authors/id/P/PM/PMQS/${name}.tar.gz";
#       sha256 = "097ab1fd5996c439a2980d950677b7070f835789cf1fd8ba796936947f69e57a";
#     };
#     buildInputs = [ expat db ];
#     meta = {
#       description = "Perl5 access to Berkeley DB version 1.x";
#       license = with stdenv.lib.licenses; [ artistic1 gpl1Plus ];
#     };
#   };
  # TODO this needs gd
  DataStag = buildPerlPackage rec {
    name = "Data-Stag-0.14";
    src = fetchurl {
      url = "mirror://cpan/authors/id/C/CM/CMUNGALL/${name}.tar.gz";
      sha256 = "4ab122508d2fb86d171a15f4006e5cf896d5facfa65219c0b243a89906258e59";
    };
    propagatedBuildInputs = [ IOString ];
    meta = {
      description = "Structured Tags";
      # license = stdenv.lib.licenses.unknown;
    };
  };
  MathDerivative = buildPerlPackage rec {
    name = "Math-Derivative-0.04";
    src = fetchurl {
      url = "mirror://cpan/authors/id/J/JG/JGAMBLE/${name}.tar.gz";
      sha256 = "9bce9db7d8ee4ab0cd42aa9aff33f0601fef180d534037d45eaa705bffb85bca";
    };
    buildInputs = [ ModuleBuild ];
    meta = {
      description = "Numeric 1st and 2nd order differentiation";
      license = with stdenv.lib.licenses; [ artistic1 gpl1Plus ];
    };
  };
  MathSpline = buildPerlPackage rec {
    name = "Math-Spline-0.02";
    src = fetchurl {
      url = "mirror://cpan/authors/id/C/CH/CHORNY/${name}.tar.gz";
      sha256 = "cfd7044483f34e6fa64080bf7c4bc10ff6173410c350066fe65e090c3b81b6e9";
    };
    propagatedBuildInputs = [ MathDerivative ];
    meta = {
      license = with stdenv.lib.licenses; [ artistic1 gpl1Plus ];
    };
  };
  PostScript = buildPerlPackage rec {
    name = "PostScript-0.06";
    src = fetchurl {
      url = "mirror://cpan/authors/id/S/SH/SHAWNPW/${name}.tar.gz";
      sha256 = "64aa477ebf153710e4cd1251a0fa6f964ac34fcd3d9993e299e28064f9eec589";
    };
    meta = {
    };
  };
  SVG = buildPerlPackage rec {
    name = "SVG-2.64";
    src = fetchurl {
      url = "mirror://cpan/authors/id/S/SZ/SZABGAB/${name}.tar.gz";
      sha256 = "73d1e1e79f6cc04f976066e70106099df35be5534eceb5dfd2c1903ecf994acd";
    };
    meta = {
      description = "Perl extension for generating Scalable Vector Graphics (SVG) documents";
      license = with stdenv.lib.licenses; [ artistic1 gpl1Plus ];
    };
  };
  SVGGraph = buildPerlPackage rec {
    name = "SVG-Graph-0.02";
    src = fetchurl {
      url = "mirror://cpan/authors/id/A/AL/ALLENDAY/${name}.tar.gz";
      sha256 = "0de0dfd6c2c6a5fa952e9cc5f56077851fcaea338e1d13915458b351b37061bc";
    };
    propagatedBuildInputs = [ MathDerivative MathSpline SVG StatisticsDescriptive TreeDAG_Node ];
    meta = {
      # license = stdenv.lib.licenses.unknown;
    };
  };
  StatisticsFrequency = buildPerlPackage rec {
    name = "Statistics-Frequency-0.04";
    src = fetchurl {
      url = "mirror://cpan/authors/id/J/JH/JHI/${name}.tar.gz";
      sha256 = "f9ff96a24b5e9eee3bd65f0f6f4bf5f7a20277fb716306a5dc3486fd6ab9ef3e";
    };
    meta = {
      # license = stdenv.lib.licenses.unknown;
    };
  };
  TieCacher = buildPerlPackage rec {
    name = "Tie-Cacher-0.09";
    src = fetchurl {
      url = "mirror://cpan/authors/id/T/TH/THOSPEL/${name}.tar.gz";
      sha256 = "1a617682a6195e7e215fb7aae8c60b90cf4b50be0caada9be145473e789e7259";
    };
    meta = {
      # license = stdenv.lib.licenses.unknown;
    };
  };
  TreeDAG_Node = buildPerlPackage rec {
    name = "Tree-DAG_Node-1.29";
    src = fetchurl {
      url = "mirror://cpan/authors/id/R/RS/RSAVAGE/${name}.tgz";
      sha256 = "2d04eb011aa06cee633c367d1f322b8d937020fde5d5393fad6a26c93725c4a8";
    };
    propagatedBuildInputs = [ FileSlurpTiny ];
    meta = {
      description = "An N-ary tree";
      license = stdenv.lib.licenses.artistic2;
    };
  };
  BioPerl = buildPerlModule rec {
    name = "BioPerl-1.007001";
    src = fetchurl {
      url = "mirror://cpan/authors/id/C/CJ/CJFIELDS/${name}.tar.gz";
      sha256 = "9da1dbcd10452f53194c98c6cc2f604a59124507dcc1e6a8440565f44dd07b40";
    };
    buildInputs = [ ModuleBuild TestMost URI ];
    propagatedBuildInputs = [

      # These were added by nix-generate-from-cpan
      DataStag
      IOString

      # these don't build. any worth fixing?
      # AcePerl
      # HTTPRequestCommon
      # IOCompress
      # IOScalar
      # PostScriptTextBlock
      # XMLDOMXPath
      # XMLParserPerlSAX
      # XMLWriter # unfree?
      # HTTPRequestCommon # actually HTTPMessage?

      # these build, but may not all be worth including
      AlgorithmMunkres
      ArchiveTar
      ArrayCompare
      BioPhylo
      CGI
      Clone
      ConvertBinaryC
      DBDPg
      DBDSQLite
      DBDmysql
      DBI
      # DB_File # issue with incompatible versions (Google "undefined symbol: db_create")
      Error
      GD
      Graph
      GraphViz
      HTMLParser
      HTMLTableExtract
      InlineC
      LWPUserAgent
      ListMoreUtils
      PostScript
      SVG
      SVGGraph
      SetScalar
      SortNaturally
      SpreadsheetParseExcel
      TestPod
      XMLDOM
      XMLLibXML
      XMLParser
      XMLSAX
      XMLSAXWriter
      XMLSimple
      XMLTwig
      YAML

    ];
    meta = {
      description = "Bioinformatics Toolkit";
      license = with stdenv.lib.licenses; [ artistic1 gpl1Plus ];
    };
  };
};

in myPerlPackages.BioPerl
