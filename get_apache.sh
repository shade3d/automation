#!/bin/bash

# check for correct interpreter
if [ `echo -n | grep -c -- -n` -gt 0 ]; then
	if [ `bash -c 'echo -n | grep -c -- -n'` -gt 0 ]; then
		echo "Can't do anything for you with this bash! :("
		exit 1
	fi
	exec bash "$0" "$@"
fi

OPTS="$@"
SCRIPT_VERSION="1.18"

SCRIPT_FORCE_REINSTALL=0
SCRIPT_FORCE_UPDATE=0

while [ x"$1" != x ]; do
	OPT=$1
	shift
	case "$OPT" in
		-f)
			SCRIPT_FORCE_REINSTALL=1
			;;
		-u)
			SCRIPT_FORCE_UPDATE=1
			;;
		-h)
			echo "Usage: $0 [-f] [-u]"
			exit
			;;
	esac
done

if [ x"$SCRIPT_FORCE_UPDATE" = x1 ]; then
	echo "Updating get_apache.sh, please wait..."
	curl -s "https://raw.githubusercontent.com/MagicalTux/automation/master/get_apache.sh" >get_apache.sh~
	if [ "$?" != "0" ]; then
		echo "An error occured while downloading the new get_apache.sh. Aborting update..."
		exit
	fi
	mv -f get_apache.sh~ get_apache.sh; chmod 0755 get_apache.sh
	exit
fi
# Do we have last version?
echo -n "Checking for last version of get_apache.sh..."
LAST_VERSION=`curl -s "https://raw.githubusercontent.com/MagicalTux/automation/master/versions.txt" | grep "^get_apache.sh" | awk '{ print $2 }'`
if [ x"$LAST_VERSION" != x"$SCRIPT_VERSION" ]; then
	echo "new version available"
	echo "Updating get_apache.sh, please wait..."
	curl -s "https://raw.githubusercontent.com/MagicalTux/automation/master/get_apache.sh" >get_apache.sh~
	if [ "$?" != "0" ]; then
		echo "An error occured while downloading the new get_apache.sh. Aborting update..."
	else
		# We'll do everything in only one line, seems that sh has problems with updates in other cases...
		mv -f get_apache.sh~ get_apache.sh; chmod 0755 get_apache.sh; exec ./get_apache.sh "$OPTS"; exit
	fi
else
	echo
fi

if [ x"${APACHE_PREFIX}" = x ]; then
	APACHE_PREFIX="/usr/local/httpd"
fi

if [ ! -d "$APACHE_PREFIX" ]; then
	APACHE_PREFIX=none
	echo "Not using Apache"
else
	echo "Using Apache in ${APACHE_PREFIX}"
fi

# Detect if we're on a debian machine

case `uname` in
	*BSD)
		MD5=md5
		SED=gsed
		MAKE_PROCESSES=$[ `sysctl -n hw.ncpu` * 2 - 1 ]
		DEFAULT_PATH=/usr
		;;
	Darwin)
		MD5=md5
		SED=gsed
		MAKE_PROCESSES=$[ `sysctl -n hw.ncpu` * 2 - 1 ]
		DEFAULT_PATH=/opt/local
		;;
	*)
		MD5=md5sum
		SED=sed
		MAKE_PROCESSES=$[ `grep -c '^processor' /proc/cpuinfo` * 2 - 1 ]
		DEFAULT_PATH=/usr
		;;
esac

APACHE_BRANCH="2.4"
APR_BRANCH="1.5"

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
	wget --timeout=300 -q -O "$APACHE_FILENAME" "$APACHE_ARCHIVE"
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

# Check for APR
echo -n "Checking for last version of apr and apr-util: "
APR_PAGE=`curl -s "http://apr.apache.org/download.cgi"`
APR_ARCHIVE=`echo "$APR_PAGE" | grep "tar.bz2" | grep -m1 "apr-$APR_BRANCH" | "$SED" -r -e 's/^.*href="//;s/".*$//'`
APR_FILENAME=`basename "$APR_ARCHIVE"`
APR_DIRNAME=`basename "$APR_ARCHIVE" .tar.bz2`
APR_VERSION=`echo "$APR_FILENAME"  | "$SED" -e 's/.*-//;s/.tar.bz2//'`
# do not trust the webpage for the MD5
APR_MD5="http://www.apache.org/dist/apr/$APR_FILENAME.md5"

echo -n "apr-$APR_VERSION "

APR_UTIL_ARCHIVE=`echo "$APR_PAGE" | grep "tar.bz2" | grep -m1 "apr-util-$APR_BRANCH" | "$SED" -r -e 's/^.*href="//;s/".*$//'`
APR_UTIL_FILENAME=`basename "$APR_UTIL_ARCHIVE"`
APR_UTIL_DIRNAME=`basename "$APR_UTIL_ARCHIVE" .tar.bz2`
APR_UTIL_VERSION=`echo "$APR_UTIL_FILENAME"  | "$SED" -e 's/.*-//;s/.tar.bz2//'`
# do not trust the webpage for the MD5
APR_UTIL_MD5="http://www.apache.org/dist/apr/$APR_UTIL_FILENAME.md5"

echo "apr-util-$APR_UTIL_VERSION"


if [ ! -d "$APACHE_DIRNAME" ]; then
	echo -n "Extracting Apache $APACHE_VERSION... "
	tar xjf "$APACHE_FILENAME"
	echo "done"
fi

if [ ! -d "$APACHE_DIRNAME/srclib/$APR_DIRNAME" ]; then
	if [ ! -f "$APR_FILENAME" ]; then
		echo -n "Downloading $APR_FILENAME... "
		wget --timeout=300 -q -O "$APR_FILENAME" "$APR_ARCHIVE"
		if [ $? != "0" ]; then
			echo "failed"
			echo "Please restart this script to try another mirror."
			echo "Failed url: $APR_ARCHIVE"
			rm -f "$APR_FILENAME"
			exit 1
		fi
		echo "done"
	fi

	echo -n "Checking archive MD5 sum... "
	ORIGINAL_MD5=`curl -s "$APR_MD5" | grep -m1 "$APR_FILENAME" | "$SED" -r -e 's/.*([0-9a-f]{32}).*/\1/'`
	if [ "$MD5" = md5sum ]; then
		OUR_MD5=`md5sum "$APR_FILENAME" | grep -m1 "$APR_FILENAME" | sed -r -e 's/ .*$//'`
	else
		OUR_MD5=`md5 -q "$APR_FILENAME"`
	fi

	if [ x"$ORIGINAL_MD5" != x"$OUR_MD5" ]; then
		echo "failed"
		echo "Original MD5: $ORIGINAL_MD5"
		echo "Local MD5   : $OUR_MD5"
		echo "Mirror      : $APR_ARCHIVE"
		echo "Please try restarting this script"
		rm -f "$APR_FILENAME"
		exit 1
	fi
	echo "done"

	echo -n "Extracting apr $APR_VERSION... "
	tar xjf "$APR_FILENAME" -C "$APACHE_DIRNAME/srclib/"
	echo "done"
	ln -snf "$APR_DIRNAME" "$APACHE_DIRNAME/srclib/apr"
fi

if [ ! -d "$APACHE_DIRNAME/srclib/$APR_UTIL_DIRNAME" ]; then
	if [ ! -f "$APR_UTIL_FILENAME" ]; then
		echo -n "Downloading $APR_UTIL_FILENAME... "
		wget --timeout=300 -q -O "$APR_UTIL_FILENAME" "$APR_UTIL_ARCHIVE"
		if [ $? != "0" ]; then
			echo "failed"
			echo "Please restart this script to try another mirror."
			echo "Failed url: $APR_UTIL_ARCHIVE"
			rm -f "$APR_UTIL_FILENAME"
			exit 1
		fi
		echo "done"
	fi

	echo -n "Checking archive MD5 sum... "
	ORIGINAL_MD5=`curl -s "$APR_UTIL_MD5" | grep -m1 "$APR_UTIL_FILENAME" | "$SED" -r -e 's/.*([0-9a-f]{32}).*/\1/'`
	if [ "$MD5" = md5sum ]; then
		OUR_MD5=`md5sum "$APR_UTIL_FILENAME" | grep -m1 "$APR_UTIL_FILENAME" | sed -r -e 's/ .*$//'`
	else
		OUR_MD5=`md5 -q "$APR_UTIL_FILENAME"`
	fi

	if [ x"$ORIGINAL_MD5" != x"$OUR_MD5" ]; then
		echo "failed"
		echo "Original MD5: $ORIGINAL_MD5"
		echo "Local MD5   : $OUR_MD5"
		echo "Mirror      : $APR_UTIL_ARCHIVE"
		echo "Please try restarting this script"
		rm -f "$APR_UTIL_FILENAME"
		exit 1
	fi
	echo "done"

	echo -n "Extracting apr-util $APR_UTIL_VERSION... "
	tar xjf "$APR_UTIL_FILENAME" -C "$APACHE_DIRNAME/srclib/"
	echo "done"
	ln -snf "$APR_UTIL_DIRNAME" "$APACHE_DIRNAME/srclib/apr-util"
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

