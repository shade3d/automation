#!/bin/sh
SCRIPT_VERSION="1.56"

if [ x"${APACHE_PREFIX}" = x ]; then
	APACHE_PREFIX="/usr/local/httpd"
fi

if [ x"${PHP_PREFIX}" = x ]; then
	PHP_PREFIX="/usr/local"
fi

PHP_FORCE_REINSTALL=0
PHP_FORCE_REINSTALL=0
GETPHP_FORCE_UPDATE=0

# check for correct interpreter
if [ `echo -n | grep -c -- -n` -gt 0 ]; then
	if [ `bash -c 'echo -n | grep -c -- -n'` -gt 0 ]; then
		echo "Can't do anything for you with this bash! :("
		exit 1
	fi
	exec bash "$0" "$@"
fi

OPTS="$@"

while [ x"$1" != x ]; do
	OPT=$1
	shift
	case "$OPT" in
		-f)
			PHP_FORCE_REINSTALL=1
			;;
		-u)
			GETPHP_FORCE_UPDATE=1
			;;
		-h)
			echo "Usage: $0 [-f] [-u]"
			exit
			;;
	esac
done

if [ x"$GETPHP_FORCE_UPDATE" = x1 ]; then
	echo "Updating get_php.sh, please wait..."
	curl -s "http://gitlab.xta.net/internal/automation/raw/master/get_php.sh" >get_php.sh~
	if [ "$?" != "0" ]; then
		echo "An error occured while downloading the new get_php.sh. Aborting update..."
		exit
	fi
	mv -f get_php.sh~ get_php.sh; chmod 0755 get_php.sh
	exit
fi
# Do we have last version of get_php.sh?
echo -n "Checking for last version of get_php.sh..."
LAST_VERSION=`curl -s "http://gitlab.xta.net/internal/automation/raw/master/versions.txt" | grep "^get_php.sh" | awk '{ print $2 }'`
if [ x"$LAST_VERSION" != x"$SCRIPT_VERSION" ]; then
	echo "new version available"
	echo "Updating get_php.sh, please wait..."
	curl -s "http://gitlab.xta.net/internal/automation/raw/master/get_php.sh" >get_php.sh~
	if [ "$?" != "0" ]; then
		echo "An error occured while downloading the new get_php.sh. Aborting update..."
	else
		# We'll do everything in only one line, seems that sh has problems with updates in other cases...
		mv -f get_php.sh~ get_php.sh; chmod 0755 get_php.sh; exec ./get_php.sh "$OPTS"; exit
	fi
else
	echo
fi

echo "Using Apache in ${APACHE_PREFIX}"

PHP_BRANCH="5"
PHP_PECL="imagick uuid APC memcached/stable svn mailparse mongo git://github.com/MagicalTux/btclib.git git://github.com/MagicalTux/php-git.git stomp yaml proctitle"
# PECL DEPENCIES
# imagick : libmagick6-dev

# Detect if we're on a debian machine

case `uname` in
	*BSD)
		SED=gsed
		MAKE_PROCESSES=$[ `sysctl -n hw.ncpu` * 2 - 1 ]
		DEFAULT_PATH=/usr
		;;
	Darwin)
		SED=gsed
		MAKE_PROCESSES=$[ `sysctl -n hw.ncpu` * 2 - 1 ]
		DEFAULT_PATH=/opt/local
		;;
	*)
		SED=sed
		MAKE_PROCESSES=$[ `grep -c '^processor' /proc/cpuinfo` * 2 - 1 ]
		DEFAULT_PATH=/usr
		;;
esac

echo -n "Checking for current version of PHP: "
PHP_BINARY="${PHP_PREFIX}/bin/php"
if [ -x "$PHP_BINARY" ]; then
	PHP_CUR_VERSION=`"$PHP_BINARY" -v | head -n 1 | sed -e 's/^[^ ]* //;s/ .*$//'`
else
	PHP_CUR_VERSION="none"
fi
echo "$PHP_CUR_VERSION"

echo -n "Checking for last version of PHP $PHP_BRANCH: "
PHP_VERSION=`curl -s http://php.net/downloads.php | grep "PHP $PHP_BRANCH" | grep -m1 "^ *<h1.*>PHP"  | $SED -r -e 's/^.*PHP +//;s/<.*>//;s/ +//g;s/\(.*\)//'`
if [ x"$PHP_VERSION" = x"5.3.0" ]; then
	PHP_VERSION="5.3.1RC1"
fi
echo "$PHP_VERSION"

if [ x"$PHP_CUR_VERSION" = x"$PHP_VERSION" ]; then
	if [ x"$PHP_FORCE_REINSTALL" = x1 ]; then
		echo "Update of PHP forced with option -f"
	else
		echo "No update needed"
		exit
	fi
fi

PHP_FILE="php-$PHP_VERSION.tar.bz2"
PHP_SUHOSIN_FILE="suhosin-patch-$PHP_VERSION-0.9.7.patch.gz"
PHP_MAIL_PATCH_FILE="php-mail-header.patch"
PHP_DIR="php-web-$PHP_VERSION"


if [ ! -f "$PHP_FILE" ]; then
	echo -n "Downloading PHP $PHP_VERSION..."
	if [ x"$PHP_VERSION" = x"5.3.1RC1" ]; then
		wget -q -O "$PHP_FILE" "http://downloads.php.net/johannes/${PHP_FILE}"
	else
		wget -q -O "$PHP_FILE" "http://php.net/get/$PHP_FILE/from/this/mirror"
	fi
	if [ $? != "0" ]; then
		echo "Could not download $PHP_FILE"
		exit 1
	fi
	echo "done"
fi
# download suhosin
#if [ ! -f "$PHP_SUHOSIN_FILE" ]; then
#	echo -n "Downloading PHP SUHOSIN for PHP$PHP_VERSION..."
#	wget -q -O "$PHP_SUHOSIN_FILE" "http://download.suhosin.org/$PHP_SUHOSIN_FILE"
#	if [ $? != "0" ]; then
#		echo "Could not download $PHP_SUHOSIN_FILE"
#		exit 1
#	fi
#	echo "done"
#fi

# download mail patch
#if [ ! -f "$PHP_MAIL_PATCH_FILE" ]; then
#	echo -n "Downloading $PHP_MAIL_PATCH_FILE ..."
#	wget -q -O "$PHP_MAIL_PATCH_FILE" "http://gitlab.xta.net/internal/automation/raw/master/$PHP_MAIL_PATCH_FILE"
#	if [ $? != "0" ]; then
#		echo "Could not download $PHP_MAIL_PATCH_FILE"
#		exit 1
#	fi
#	echo "done"
#fi

# download php 5.3.2 fix
IS_CLEAN=no
if [ ! -d "$PHP_DIR" ]; then
	echo -n "Extracting PHP... "
	IS_CLEAN=yes
	tar xjf "$PHP_FILE"
	if [ $? != "0" ]; then
		echo "failed"
		exit 1
	fi
	mv "php-$PHP_VERSION" "$PHP_DIR"
	echo "done"
	cd "$PHP_DIR"
#	echo -n "Applying SUHOSIN patch..."
#	cat "../$PHP_SUHOSIN_FILE" | gunzip | patch -p1 -s
#	echo "done"
#	echo -n "Applying mail patch..."
#	cat "../$PHP_MAIL_PATCH_FILE" | patch -p1 -s
#	echo "done"
	if [ x"$PHP_VERSION" = x"5.3.2" ]; then
		echo -n "Applying 5.3.2 fix..."
		cat "../$PHP_FIX_PATCH" | patch -p0 -s
		echo "done"
	fi
else
	cd "$PHP_DIR"
fi

if [ x"$IS_CLEAN" != x"yes" ]; then
	echo -n "Cleaning..."
	make clean >/dev/null 2>&1
	echo
fi

echo -n "Detecting MySQL..."

MYSQL_CONFIG=`PATH=/usr/local/mysql/bin:$PATH which mysql_config 2>/dev/null`
if [ x"$MYSQL_CONFIG" = x ]; then
	MYSQL_CONFIG=`PATH=/usr/local/mysql/bin:/opt/local/bin:$PATH which mysql_config5 2>/dev/null`
fi
if [ x"$MYSQL_CONFIG" = x ]; then
	echo "not found"
	echo "MySQL was not found on this system!"
fi
MYSQL_PATH=`dirname "$MYSQL_CONFIG"`
MYSQL_PATH=`dirname "$MYSQL_PATH"`
echo "Found in $MYSQL_PATH"

EXTRA_FLAGS=""

# detect freetds and use
if [ -f /usr/lib64/libsybdb.so ]; then
	echo "Found MSSQL library, using it"
	EXTRA_FLAGS="--with-mssql=/usr"
fi

echo -n "Configure... ";
./configure >configure.log 2>&1 \
--with-apxs2="${APACHE_PREFIX}/bin/apxs" --prefix="${PHP_PREFIX}" --enable-ftp --with-iconv \
--with-mysqli="$MYSQL_CONFIG" --with-mysql="$MYSQL_PATH" --enable-calendar --enable-fpm \
--enable-exif --enable-wddx --enable-inline-optimization --with-gd \
--with-zlib --enable-gd-native-ttf --with-jpeg-dir="$DEFAULT_PATH" --with-png-dir="$DEFAULT_PATH" \
--with-zlib-dir="$DEFAULT_PATH" --with-freetype-dir="$DEFAULT_PATH" --with-openssl="$DEFAULT_PATH" \
--with-curl="$DEFAULT_PATH" --with-zlib-dir="$DEFAULT_PATH" --enable-intl --with-icu-dir="$DEFAULT_PATH" \
--with-xmlrpc --with-xsl --with-tidy --with-iconv-dir --enable-sockets \
--enable-soap --enable-mbstring --with-imap --with-imap-ssl --with-bz2 \
--with-pdo-mysql="$MYSQL_PATH" --enable-pcntl --enable-bcmath \
--with-mhash --with-mcrypt --with-gmp="$DEFAULT_PATH" --with-gettext --with-ldap \
--with-config-file-path="${PHP_PREFIX}/lib/php-web" --disable-cgi --enable-zip $EXTRA_FLAGS

if [ x"$?" != x"0" ]; then
	echo "FAILED"
	tail configure.log
	exit 1
fi

echo ""
echo -n "Compiling..."
make -j"$MAKE_PROCESSES" >make.log 2>&1
echo ""
echo -n "Installing..."
if [ ! -d "${PHP_PREFIX}/lib/php-web" ]; then
	mkdir -p "${PHP_PREFIX}/lib/php-web"
	cp "${PHP_PREFIX}/lib/php.ini" "${PHP_PREFIX}/lib/php-web/php.ini"
fi
env -i "${APACHE_PREFIX}/bin/apachectl" stop >/dev/null 2>&1 || true
#killall -KILL httpd >/dev/null 2>&1 || true
make install >make_install.log 2>&1
env -i "${APACHE_PREFIX}/bin/apachectl" start

echo
echo -n "Configuring PECL modules..."
mkdir -p "${PHP_PREFIX}/lib/php_mod"
cat "${PHP_PREFIX}/lib/php-web/php.ini" | grep -v '^extension' >/tmp/php.ini
mv -f /tmp/php.ini "${PHP_PREFIX}/lib/php-web/php.ini"
echo "extension_dir = ${PHP_PREFIX}/lib/php_mod" >>"${PHP_PREFIX}/lib/php-web/php.ini"
mkdir -p mod
cd mod
for foo in $PHP_PECL; do
	if [ `echo "$foo" | grep -c '^git://'` = "1" ]; then
		# git repo
		NAME=`echo "$foo" | sed -e 's#.*/##;s/\.git$//'`
		echo -n "$NAME"
		if [ -d "$NAME" ]; then
			cd "$NAME"
			git pull -n
		else
			git clone -q "$foo" "$NAME"
			cd "$NAME"
		fi
		echo -n "[git] "
		"${PHP_PREFIX}/bin/phpize" >phpize.log 2>&1
		if [ $? != 0 ]; then
			continue;
		fi
		./configure >configure.log 2>&1
		make -j"$MAKE_PROCESSES" >make.log 2>&1
		cp modules/* "${PHP_PREFIX}/lib/php_mod"
		cd ..
		continue
	fi
	# git://github.com/libgit2/php-git.git

	echo -n "$foo"
	curl -s "http://pecl.php.net/get/$foo" | tar xzf /dev/stdin >/dev/null 2>&1
	foo=`echo "$foo" | cut -d/ -f1`
	dr=`find . -name "$foo*" -type d | head -n1`
	if [ x"$dr" = x ]; then
		continue;
	fi
	pecl_version=`echo "$dr" | $SED -e 's/^.*-//'`
	echo -n "[$pecl_version] "
	cd $dr
	"${PHP_PREFIX}/bin/phpize" >phpize.log 2>&1
	if [ $? != 0 ]; then
		continue;
	fi
	./configure >configure.log 2>&1
	make -j"$MAKE_PROCESSES" >make.log 2>&1
	cp modules/* "${PHP_PREFIX}/lib/php_mod"
	cd ..
done
cd ..
for foo in ${PHP_PREFIX}/lib/php_mod/*.so; do
	foo=`basename "$foo"`
	if [ x"$foo" = x'*.so' ]; then
		break;
	fi
	echo "extension = $foo" >>"${PHP_PREFIX}/lib/php-web/php.ini"
done

env -i "${APACHE_PREFIX}/bin/apachectl" stop >/dev/null 2>&1 || true
#killall -KILL httpd >/dev/null 2>&1 || true
sleep 1s
#ipcs -s | grep nobody | perl -e 'while (<STDIN>) { @a=split(/\s+/); print `ipcrm sem $a[1]`}'
env -i "${APACHE_PREFIX}/bin/apachectl" start
echo ""
echo "Installation complete."
