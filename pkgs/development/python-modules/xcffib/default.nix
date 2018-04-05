{ stdenv
, buildPythonPackage
, fetchPypi
, xorg
, cffi
, six
}:

buildPythonPackage rec {
  version = "0.5.1";
  pname = "xcffib";

  src = fetchPypi {
    inherit pname version;
    sha256 = "09gbnmr5vn58mm8xi3fmd7fz6743cks6c46dphnxzwax6zsxmy60";
  };

  patchPhase = ''
    # Hardcode cairo library path
    sed -e 's,ffi\.dlopen(,&"${xorg.libxcb.out}/lib/" + ,' -i xcffib/__init__.py
  '';

  propagatedBuildInputs = [ cffi six ];

  meta = with stdenv.lib; {
    description = "A drop in replacement for xpyb, an XCB python binding";
    homepage = "https://github.com/tych0/xcffib";
    license = licenses.asl20;
    maintainers = with maintainers; [ kamilchm ];
  };
}
