#!/usr/bin/env bash

source $stdenv/setup

# extract files from the Windows executable
mkdir -p $out/lib
unzip $src
sdx.kit unwrap ApE.exe
cp -dpr ApE.vfs $out/lib

# install a wrapper script
mkdir -p $out/bin
cat << EOF > $out/bin/ape
#!/usr/bin/env bash
cd $out/lib/ApE.vfs
${tk}/bin/wish lib/app-AppMain/AppMain.tcl
EOF
chmod +x $out/bin/ape
