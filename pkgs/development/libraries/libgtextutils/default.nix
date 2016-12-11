{ stdenv, fetchurl }:

stdenv.mkDerivation {
  name = "libgtextutils-0.7";
  src = fetchurl {
    url = "https://github.com/agordon/libgtextutils/releases/download/0.7/libgtextutils-0.7.tar.gz";
    sha256 = "0jiybkb2z58wa2msvllnphr4js2hvjvh988pavb3mzkgr6ihwbkr";
  };
}
