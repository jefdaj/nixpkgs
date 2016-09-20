{ stdenv, fetchFromGitHub, libsndfile, libsamplerate, liblo, libjack2 }:

stdenv.mkDerivation rec {
  name = "dirt-2015-09-28";
  src = fetchFromGitHub {
    repo = "Dirt";
    owner = "tidalcycles";
    rev = "119084dc0fde33bc0bbf5c77828b44484b447ba9";
    sha256 = "1cvn4q7kp2mjbkvkyrknn5k3mmm79qdrbnnpkj51bargng90x1dz";
  };
  buildInputs = [ libsndfile libsamplerate liblo libjack2 ];
  postPatch = ''
    sed -i "s|./samples|$out/share/dirt/samples|" file.h
  '';
  configurePhase = ''
    export PREFIX=$out
  '';
  postInstall = ''
    mkdir -p $out/share/dirt/
    cp -r samples $out/share/dirt/
  '';

  meta = with stdenv.lib; {
    description = "An unimpressive thingie for playing bits of samples with some level of accuracy";
    homepage = "https://github.com/tidalcycles/Dirt";
    license = licenses.gpl3;
    maintainers = with maintainers; [ anderspapitto ];
    platforms = with platforms; linux;
  };
}
