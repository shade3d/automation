#!/bin/sh

# Build M4 stuff
for foo in src/*.m4; do
	tgt=`basename "$foo" .m4`.sh
	echo "Building $tgt ..."
	m4 -I src/m4 "$foo" >"$tgt"
done

echo "Building versions.txt ..."

echo "# Version file used by automation script to detect last available version of each one" >versions.txt
grep ^SCRIPT_VERSION= *.sh | sed -e 's/:SCRIPT_VERSION="/ /;s/"//' >>versions.txt

