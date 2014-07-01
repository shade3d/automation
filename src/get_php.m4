changequote([","])dnl
define(["M4_TARGET"],["get_php.sh"])dnl
define(["M4_VERSION"],["1.57"])dnl
dnl rpm -i http://dl.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm http://rpms.famillecollet.com/enterprise/remi-release-6.rpm
define(["M4_YUM_PKG"],["make gcc gcc-g++ zlib-devel openssl-devel libxml2-devel bzip2-devel libcurl-devel libjpeg-devel libpng-devel freetype-devel gmp-devel libc-client-devel libicu-devel openldap-devel libmcrypt-devel libtidy-devel libxslt-devel git ImageMagick-devel libmemcached-devel libyaml-devel libuuid-devel libmongodb-devel"])dnl
include(bash.m4)dnl
include(version.m4)dnl
include(apache.m4)dnl
include(php.m4)dnl
include(os.m4)dnl

PHP_BRANCH="5"
PHP_PECL="imagick uuid APC memcached/stable svn mailparse mongo git://github.com/MagicalTux/btclib.git git://github.com/MagicalTux/php-git.git stomp yaml proctitle"
# PECL DEPENCIES
# imagick : libmagick6-dev

echo -n "Checking for current version of PHP: "
PHP_BINARY="${PHP_PREFIX}/bin/php"
if [ -x "$PHP_BINARY" ]; then
	PHP_CUR_VERSION=`"$PHP_BINARY" -v | head -n 1 | $SED -e 's/^[^ ]* //;s/ .*$//'`
else
	PHP_CUR_VERSION="none"
fi
echo "$PHP_CUR_VERSION"

echo -n "Checking for last version of PHP $PHP_BRANCH: "
PHP_VERSION=`curl -s http://php.net/downloads.php | grep "PHP $PHP_BRANCH\." | grep -v headsup | head -n 1 | $SED -r -e 's/^.*PHP +//;s/<.*>//;s/ +//g;s/\(.*\)//'`
echo "$PHP_VERSION"

if [ x"$PHP_CUR_VERSION" = x"$PHP_VERSION" ]; then
	if [ x"$SCRIPT_FORCE_REINSTALL" = x1 ]; then
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
	# from/this/mirror allows autodetection to give us closest mirror
	wget -q -O "$PHP_FILE" "http://php.net/get/$PHP_FILE/from/this/mirror"

	if [ $? != "0" ]; then
		echo "Could not download $PHP_FILE"
		rm -f "$PHP_FILE"
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
#	wget -q -O "$PHP_MAIL_PATCH_FILE" "https://raw.githubusercontent.com/Tibanne/automation/master/$PHP_MAIL_PATCH_FILE"
#	if [ $? != "0" ]; then
#		echo "Could not download $PHP_MAIL_PATCH_FILE"
#		exit 1
#	fi
#	echo "done"
#fi

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
else
	cd "$PHP_DIR"
fi

if [ x"$IS_CLEAN" != x"yes" ]; then
	echo -n "Cleaning..."
	make clean >/dev/null 2>&1
	echo
fi

CONFIGURE=()

if [ x"$APACHE_PREFIX" = x"none" ]; then
	CONFIGURE+=("--enable-fpm")
else
	CONFIGURE+=("--with-apxs2=${APACHE_PREFIX}/bin/apxs")
fi

CONFIGURE+=("--prefix=${PHP_PREFIX}" "--enable-inline-optimization")

# encoding stuff
CONFIGURE+=("--with-iconv" "--with-iconv-dir" "--enable-mbstring")
# libintl (ICU)
CONFIGURE+=("--enable-intl" "--with-icu-dir=$DEFAULT_PATH")
# features
CONFIGURE+=("--enable-calendar" "--enable-exif" "--enable-pcntl" "--enable-bcmath" "--with-gettext")
# compression
CONFIGURE+=("--with-zlib" "--with-zlib-dir=$DEFAULT_PATH" "--with-bz2" "--enable-zip")
# MySQL
CONFIGURE+=("--with-mysqli=mysqlnd" "--with-mysql=mysqlnd" "--with-pdo-mysql=mysqlnd")
# GD
CONFIGURE+=("--with-gd" "--enable-gd-native-ttf" "--with-jpeg-dir=$DEFAULT_PATH" "--with-png-dir=$DEFAULT_PATH" "--with-freetype-dir=$DEFAULT_PATH")
# XML
CONFIGURE+=("--enable-wddx" "--with-xmlrpc" "--with-xsl" --with-tidy" "--enable-soap")
# OpenSSL
CONFIGURE+=("--with-openssl" "--with-mhash" "--with-mcrypt" "--with-gmp=$DEFAULT_PATH")
# Network
CONFIGURE+=("--enable-sockets" "--enable-ftp" "--with-curl=$DEFAULT_PATH" "--with-imap" "--with-imap-ssl" "--with-ldap")
# Basic stuff
CONFIGURE+=("--with-config-file-path=${PHP_PREFIX}/lib/php-web" "--disable-cgi")

# detect freetds and use
if [ -f /usr/lib64/libsybdb.so ]; then
	echo "Found MSSQL library, using it"
	CONFIGURE+=("--with-mssql=/usr")
fi

echo -n "Configure... ";
./configure >configure.log 2>&1 "${CONFIGURE[@]}"

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

# if using apache, we need to run that now to limit downtime
if [ x"$APACHE_PREFIX" = x"none" ]; then
	make install >make_install.log 2>&1
else
	env -i "${APACHE_PREFIX}/bin/apachectl" stop >/dev/null 2>&1 || true
	#killall -KILL httpd >/dev/null 2>&1 || true
	make install >make_install.log 2>&1
	env -i "${APACHE_PREFIX}/bin/apachectl" start
fi

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

if [ x"$APACHE_PREFIX" = x"none" ]; then
	echo "You will need to fix the FPM binary"
else
	env -i "${APACHE_PREFIX}/bin/apachectl" stop >/dev/null 2>&1 || true
	#killall -KILL httpd >/dev/null 2>&1 || true
	sleep 1s
	#ipcs -s | grep nobody | perl -e 'while (<STDIN>) { @a=split(/\s+/); print `ipcrm sem $a[1]`}'
	env -i "${APACHE_PREFIX}/bin/apachectl" start
fi
echo ""
echo "Installation complete."
