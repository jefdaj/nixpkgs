#!/usr/bin/env bash

source $stdenv/setup
PATH=$maven/bin:$PATH

# build tarql
mkdir $TMP/src
ln -s $mavenRepo $TMP/m2
export MAVEN_OPTS="-Dmaven.repo.local=$TMP/m2"
cp -R $src/* $TMP/src
cd $TMP/src
mvn package appassembler:assemble

# install libs
mkdir -p $out/lib
cp -R $TMP/src/target/appassembler/lib/* $out/lib

# install wrapper script
mkdir -p $out/bin
cat > $out/bin/tarql << EOF
#!/usr/bin/env bash
CLASSPATH=\$(echo \$(ls $out/lib/*.jar) | sed 's/ /:/g')
exec $jdk/bin/java \\
  \$JAVA_OPTS \\
  -classpath \$CLASSPATH \\
  -Dapp.name="tarql" \\
  -Dapp.pid="\$\$" \\
  -Dapp.repo=$out/lib \\
  -Dapp.home=$out \\
  -Dbasedir=$out \\
  org.deri.tarql.tarql \\
  "\$@"
EOF
chmod +x $out/bin/tarql
