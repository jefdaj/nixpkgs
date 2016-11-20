# TODO check if any of the dependencies can be removed
# TODO archive the tarball in case it goes away?

{ stdenv, fetchurl, cairo, pango, zlib, pythonPackages }:

stdenv.mkDerivation rec {
  version = "0.9.0";
  name = "seqtrace-${version}";
  src = fetchurl {
    url = "https://storage.googleapis.com/google-code-archive-downloads/v2/code.google.com/seqtrace/${name}.tar.gz";
    sha256 = "16lcv7b7shr9byil53y1g1i4pzxlj6fc2z3fsg16iizyyiq86ws8";
  };
  buildInputs = with pythonPackages; [
    # cairocffi cairosvg
    cairo
    pango
    pygobject2
    pygtk
    pyperclip
    zlib
  ];
  installPhase = ''
    # copy everything into the package as-is
    mkdir -p $out/src
    cp -R * $out/src
    # launch seqtrace.py from a wrapper script
    mkdir -p $out/bin
    cat << EOF > $out/bin/seqtrace
    export PYTHONPATH=$PYTHONPATH
    cd $out/src
    python seqtrace.py
    EOF
    chmod +x $out/bin/seqtrace
  '';
}
