{ stdenv, fetchurl, cmake, zlib }:

stdenv.mkDerivation rec {
  name = "diamond-${version}";
  version = "0.9.29";

  src = fetchurl {
    url = "https://github.com/bbuchfink/diamond/archive/v${version}.tar.gz";
    sha256 = "0dd69c97c4dhfk1yhhg218s62pwy3mmyxnp32vbgqysagd0wdklw";
  };

  nativeBuildInputs = [ cmake ];
  buildInputs = [ zlib ];

  meta = with stdenv.lib; {
    description = "Accelerated BLAST compatible local sequence aligner";
    longDescription = ''
      A sequence aligner for protein and translated DNA
      searches and functions as a drop-in replacement for the NCBI BLAST
      software tools. It is suitable for protein-protein search as well as
      DNA-protein search on short reads and longer sequences including contigs
      and assemblies, providing a speedup of BLAST ranging up to x20,000.

      DIAMOND is developed by Benjamin Buchfink. Feel free to contact him for support (Email Twitter).

      If you use DIAMOND in published research, please cite
      B. Buchfink, Xie C., D. Huson,
      "Fast and sensitive protein alignment using DIAMOND",
      Nature Methods 12, 59-60 (2015).
        '';
    homepage = https://github.com/bbuchfink/diamond;
    license = {
      fullName = "University of Tuebingen, Benjamin Buchfink";
      url = https://raw.githubusercontent.com/bbuchfink/diamond/master/src/COPYING;
    };
    maintainers = [ maintainers.metabar ];
  };
}
