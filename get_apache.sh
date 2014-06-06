#!/bin/sh
SCRIPT_VERSION="1.15"
APACHE_BRANCH="2.2"

if [ x"${APACHE_PREFIX}" = x ]; then
	APACHE_PREFIX="/usr/local/httpd"
fi

# check for correct interpreter
if [ `echo -n | grep -c -- -n` -gt 0 ]; then
	if [ `bash -c 'echo -n | grep -c -- -n'` -gt 0 ]; then
		echo "Can't do anything for you with this bash! :("
		exit 1
	fi
	exec bash "$0" "$@"
fi

# Do we have last version of get_apache.sh?
echo -n "Checking for last version of get_apache.sh..."
LAST_VERSION=`curl -s "http://gitlab.xta.net/internal/automation/raw/master/versions.txt" | grep "^get_apache.sh" | awk '{ print $2 }'`
if [ x"$LAST_VERSION" != x"$SCRIPT_VERSION" ]; then
	echo "new version available"
	echo "Updating get_apache.sh, please wait..."
	curl -s "http://gitlab.xta.net/internal/automation/raw/master/get_apache.sh" >get_apache.sh~
	if [ "$?" != "0" ]; then
		echo "An error occured while downloading the new get_apache.sh. Aborting update..."
	else
		# We'll do everything in only one line, seems that sh has problems with updates in other cases...
		mv -f get_apache.sh~ get_apache.sh; chmod 0755 get_apache.sh; . ./get_apache.sh; exit
	fi
else
	echo
fi

# Check for kind of machine
UNAME=`uname`
SED=sed
MD5=md5sum
case "$UNAME" in
	*BSD)
		MD5=md5
		SED=gsed
		;;
	Darwin)
		MD5=md5
		SED=gsed
		;;
esac

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
	echo "No update needed"
	exit
fi

if [ ! -f "$APACHE_FILENAME" ]; then
	echo -n "Downloading $APACHE_FILENAME... "
	wget -q -O "$APACHE_FILENAME" "$APACHE_ARCHIVE"
	if [ $? != "0" ]; then
		echo "failed"
		echo "Please restart this script to try another mirror."
		echo "Failed url: $APACHE_ARCHIVE"
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
	echo "Please erase $APACHE_FILENAME and restart this script"
	exit 1
fi
echo "done"

if [ ! -d "$APACHE_DIRNAME" ]; then
	echo -n "Extracting Apache $APACHE_VERSION... "
	tar xjf "$APACHE_FILENAME"
	echo "done"
fi

echo -n "Detecting MySQL..."

MYSQL_CONFIG=`PATH=/usr/local/mysql/bin:$PATH which mysql_config 2>/dev/null`
if [ x"$MYSQL_CONFIG" = x ]; then
	MYSQL_CONFIG=`PATH=/usr/local/mysql/bin:/opt/local/bin:$PATH which mysql_config5 2>/dev/null`
fi
if [ x"$MYSQL_CONFIG" = x ]; then
	echo "not found"
	echo "MySQL was not found on this system!"
	exit 1
fi
MYSQL_PATH=`dirname "$MYSQL_CONFIG"`
MYSQL_PATH=`dirname "$MYSQL_PATH"`
echo "Found in $MYSQL_PATH"


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

