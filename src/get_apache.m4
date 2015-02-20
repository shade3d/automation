changequote([","])dnl
define(["M4_TARGET"],["get_apache.sh"])dnl
define(["M4_VERSION"],["1.16"])dnl
define(["M4_YUM_PKG"],["Percona-Server-devel-55 make gcc gcc-g++ zlib-devel openssl-devel"])dnl
include(bash.m4)dnl
include(version.m4)dnl
include(apache.m4)dnl
include(os.m4)dnl

APACHE_BRANCH="2.2"

if [ x"$APACHE_PREFIX" = x"none" ]; then
	APACHE_PREFIX=/usr/local/httpd
fi

echo "Installing Apache to ${APACHE_PREFIX}"

echo -n "Checking for current version of Apache2: "
APACHE_BINARY="${APACHE_PREFIX}/bin/httpd"
if [ -x "$APACHE_BINARY" ]; then
	APACHE_CUR_VERSION=`"$APACHE_BINARY" -v | grep version | sed -e 's#^.*/##;s/ .*$//'`
else
	APACHE_CUR_VERSION="none"
fi
echo "$APACHE_CUR_VERSION"

echo -n "Checking for last version of Apache2: "
APACHE_PAGE=`curl -s "http://httpd.apache.org/download.cgi"`
APACHE_ARCHIVE=`echo "$APACHE_PAGE" | grep "tar.bz2" | grep -m1 "$APACHE_BRANCH" | "$SED" -r -e 's/^.*href="//;s/".*$//'`
APACHE_FILENAME=`basename "$APACHE_ARCHIVE"`
APACHE_DIRNAME=`basename "$APACHE_ARCHIVE" .tar.bz2`
APACHE_VERSION=`echo "$APACHE_FILENAME"  | "$SED" -e 's/.*-//;s/.tar.bz2//'`
# do not trust the webpage for the MD5
APACHE_MD5="http://www.apache.org/dist/httpd/$APACHE_FILENAME.md5"

echo "$APACHE_VERSION"

# check if newer
if [ x"$APACHE_VERSION" = x"$APACHE_CUR_VERSION" ]; then
	if [ x"$SCRIPT_FORCE_REINSTALL" = x1 ]; then
		echo "Update of Apache forced with option -f"
	else
		echo "No update needed"
		exit
	fi
fi

if [ ! -f "$APACHE_FILENAME" ]; then
	echo -n "Downloading $APACHE_FILENAME... "
	wget -q -O "$APACHE_FILENAME" "$APACHE_ARCHIVE"
	if [ $? != "0" ]; then
		echo "failed"
		echo "Please restart this script to try another mirror."
		echo "Failed url: $APACHE_ARCHIVE"
		rm -f "$APACHE_FILENAME"
		exit 1
	fi
	echo "done"
fi

echo -n "Checking archive MD5 sum... "
ORIGINAL_MD5=`curl -s "$APACHE_MD5" | grep -m1 "$APACHE_FILENAME" | "$SED" -r -e 's/.*([0-9a-f]{32}).*/\1/'`
if [ "$MD5" = md5sum ]; then
	OUR_MD5=`md5sum "$APACHE_FILENAME" | grep -m1 "$APACHE_FILENAME" | sed -r -e 's/ .*$//'`
else
	OUR_MD5=`md5 -q "$APACHE_FILENAME"`
fi

if [ x"$ORIGINAL_MD5" != x"$OUR_MD5" ]; then
	echo "failed"
	echo "Original MD5: $ORIGINAL_MD5"
	echo "Local MD5   : $OUR_MD5"
	echo "Mirror      : $APACHE_ARCHIVE"
	echo "Please try restarting this script"
	rm -f "$APACHE_FILENAME"
	exit 1
fi
echo "done"

if [ ! -d "$APACHE_DIRNAME" ]; then
	echo -n "Extracting Apache $APACHE_VERSION... "
	tar xjf "$APACHE_FILENAME"
	echo "done"
fi

include(detect_mysql.m4)dnl

cd "$APACHE_DIRNAME"
echo -n "Configuring Apache2... "
LDFLAGS="-L/usr/local/lib" ./configure >configure.log 2>&1 \
--prefix="${APACHE_PREFIX}" --enable-v4-mapped --enable-exception-hook \
--enable-deflate --enable-logio --enable-proxy --enable-proxy-http \
--enable-http --enable-info --enable-vhost-alias --enable-speling --disable-userdir \
--enable-rewrite --enable-so --enable-dav --enable-ssl --with-included-apr \
--enable-authn-dbd --enable-authn-alias --enable-auth-digest --enable-dbd --enable-expires \
--enable-dav-fs --enable-dav-lock --enable-vhost-alias --with-mysql="$MYSQL_PATH" \
--enable-expires --enable-headers --enable-reqtimeout

if [ $? != "0" ]; then
	echo "failed"
	tail configure.log
	exit 1
fi
echo "done"
echo -n "Compiling Apache2... "
make >make.log 2>&1
if [ $? != "0" ]; then
	echo "failed"
	tail make.log
	exit 1
fi
echo "done"
echo -n "Installing Apache2... "
make install >install.log 2>&1
if [ $? != "0" ]; then
	echo "failed"
	tail install.log
	exit 1
fi
echo "done"

echo -n "Checking apache config: "
"${APACHE_PREFIX}/bin/apachectl" configtest

"${APACHE_PREFIX}/bin/httpd" -v

