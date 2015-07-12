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
SCRIPT_VERSION="1.68"

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
	echo "Updating get_php.sh, please wait..."
	curl -s "https://raw.githubusercontent.com/MagicalTux/automation/master/get_php.sh" >get_php.sh~
	if [ "$?" != "0" ]; then
		echo "An error occured while downloading the new get_php.sh. Aborting update..."
		exit
	fi
	mv -f get_php.sh~ get_php.sh; chmod 0755 get_php.sh
	exit
fi
# Do we have last version?
echo -n "Checking for last version of get_php.sh..."
LAST_VERSION=`curl -s "https://raw.githubusercontent.com/MagicalTux/automation/master/versions.txt" | grep "^get_php.sh" | awk '{ print $2 }'`
if [ x"$LAST_VERSION" != x"$SCRIPT_VERSION" ]; then
	echo "new version available"
	echo "Updating get_php.sh, please wait..."
	curl -s "https://raw.githubusercontent.com/MagicalTux/automation/master/get_php.sh" >get_php.sh~
	if [ "$?" != "0" ]; then
		echo "An error occured while downloading the new get_php.sh. Aborting update..."
	else
		# We'll do everything in only one line, seems that sh has problems with updates in other cases...
		mv -f get_php.sh~ get_php.sh; chmod 0755 get_php.sh; exec ./get_php.sh "$OPTS"; exit
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

if [ x"${PHP_PREFIX}" = x ]; then
	PHP_PREFIX="/usr/local"
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

PHP_BRANCH="5"

# allow override of php branch easily (TODO: make this a ini file one day)
if [ -f php_branch.txt ]; then
	PHP_BRANCH=`cat php_branch.txt`
fi

if [ x"$PHP_PECL" = x ]; then
	# default set of PECL modules
	PHP_PECL="imagick uuid memcached/stable mailparse git://github.com/MagicalTux/php-git.git stomp yaml proctitle git://github.com/preillyme/v8js.git"
fi
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
	wget --timeout=300 -q -O "$PHP_FILE" "http://php.net/get/$PHP_FILE/from/this/mirror"

	if [ $? != "0" ]; then
		echo "Could not download $PHP_FILE"
		rm -f "$PHP_FILE"
		exit 1
	fi
	echo "done"
fi

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
CONFIGURE+=("--enable-wddx" "--with-xmlrpc" "--with-xsl" "--with-tidy" "--enable-soap")
# OpenSSL
CONFIGURE+=("--with-openssl" "--with-mhash" "--with-mcrypt" "--with-gmp=$DEFAULT_PATH")
# Network
CONFIGURE+=("--enable-sockets" "--enable-ftp" "--with-curl=$DEFAULT_PATH" "--with-imap" "--with-imap-ssl")
# Basic stuff
CONFIGURE+=("--with-config-file-path=${PHP_PREFIX}/lib/php-web" "--disable-cgi")

# detect freetds and use
if [ -f /usr/lib64/libsybdb.so ]; then
	echo "Found MSSQL library, using it"
	CONFIGURE+=("--with-mssql=/usr")
fi

if [ `ldd /usr/lib/libc-client.so | grep -c libgssapi` -gt 0 ]; then
	# libc-client uses krb, need to enable it
	CONFIGURE+=("--with-kerberos")
fi

echo -n "Configure... ";

# force linking of libstdc++ by default since it is required but PHP doesn't handle it right
LIBS="-lstdc++" ./configure >configure.log 2>&1 "${CONFIGURE[@]}"

if [ x"$?" != x"0" ]; then
	echo "FAILED"
	tail configure.log
	exit 1
fi

echo ""
echo -n "Compiling..."
make -j"$MAKE_PROCESSES" >make.log 2>&1

if [ x"$?" != x"0" ]; then
	echo "FAILED"
	tail make.log
	exit 1
fi

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
	PECL_CONFIGURE=()
	if [ `echo "$foo" | grep -c '^git://'` = "1" ]; then
		# git repo
		NAME=`echo "$foo" | sed -e 's#.*/##;s/\.git$//'`
		echo -n "$NAME"
		if [ -d "$NAME" ]; then
			cd "$NAME"
			git pull -n -q
		else
			git clone -q "$foo" "$NAME"
			cd "$NAME"
		fi
		if [ "$NAME" = "php-git" ]; then
			echo -n "[libgit2:"
			if [ ! -d libgit2/build ]; then
				git submodule init -q
				git submodule update -q
				mkdir libgit2/build
				cd libgit2/build
				cmake -DCMAKE_BUILD_TYPE=Debug -DBUILD_SHARED_LIBS=OFF -DBUILD_CLAR=OFF -DCMAKE_C_FLAGS=-fPIC -DUSE_SSH=ON .. >../../libgit2_cmake_init.log 2>&1
				cmake --build . >../../libgit2_cmake_compile.log 2>&1
				cd ../..
			elif [ ! -f libgit2/build/libgit2.a ]; then
				# erased by make clean
				cd libgit2/build
				cmake --build . >../../libgit2_cmake_compile.log 2>&1
				cd ../..
			fi
			echo -n "ok]"
			PECL_CONFIGURE+=("--enable-git2-debug")
		fi
		if [ "$NAME" = "memcached/stable" ]; then
			PECL_CONFIGURE+=("--disable-memcached-sasl")
		fi
		if [ "$NAME" = "v8js" ]; then
			if [ ! -f /usr/lib/libv8.so ]; then
				# get v8 from git (repo is huge, get ready for >100MB dl)
				echo -n "[v8:pull.."
					if [ -d v8 ]; then
					cd v8
					git pull -n -q
				else
					git clone -q https://github.com/v8/v8.git
					cd v8
				fi
				# version 3.30.00 is known to work with this ext
				if [ ! -d depot_tools ]; then
					svn checkout -q http://src.chromium.org/svn/trunk/tools/depot_tools
					# small handler for python to help point to python2.7
					echo '#!/bin/sh' >depot_tools/python
					echo 'if [ -x /usr/bin/python2.7 ]; then' >>depot_tools/python
					echo '	exec /usr/bin/python2.7 "$@"' >>depot_tools/python
					echo 'else' >>depot_tools/python
					echo '	exec python "$@"' >>depot_tools/python
					echo 'fi' >>depot_tools/python
					chmod +x depot_tools/python
				fi
				echo -n "dep.."
				PATH="`pwd`/depot_tools:$PATH" make dependencies >../v8_dep.log 2>&1
				echo -n "build.."
				PATH="`pwd`/depot_tools:$PATH" make native GYPFLAGS="-Duse_system_icu=1 -Dcomponent=shared_library -Dv8_enable_backtrace=1 -Darm_fpu=default -Darm_float_abi=default" -j"$MAKE_PROCESSES" >../v8_make.log 2>&1

				echo -n "install.."
				cp out/native/lib.target/libv8.so /usr/lib/libv8.so
				echo -e "create /usr/lib/libv8_libplatform.a\naddlib out/native/obj.target/tools/gyp/libv8_libplatform.a\naddlib out/native/obj.target/tools/gyp/libv8_libbase.a\nsave\nend" | ar -M
				cp include/v8* /usr/include
				cp -r include/libplatform /usr/include

				# Uninstall: rm -fr /usr/lib/libv8.so /usr/lib/libv8_libplatform.a /usr/include/v8* /usr/include/libplatform

				echo -n "ok]"
				cd ..
			fi
		fi
		echo -n "[git] "
		"${PHP_PREFIX}/bin/phpize" >phpize.log 2>&1 || ( echo -n "[fail] " && continue )
		./configure >configure.log 2>&1 "${PECL_CONFIGURE[@]}"
		if [ "$NAME" = "php-git" ]; then
			# special case, linking ssh2 in php-git is a pain, so we cheat our way out (-Wl required because if using -l libtool will move it)
			sed -r -i 's/^(GIT2_SHARED_LIBADD = .*)$/\1 -Wl,-lssh2/' Makefile
		fi
		make -j"$MAKE_PROCESSES" >make.log 2>&1
		cp modules/* "${PHP_PREFIX}/lib/php_mod"
		cd ..
		continue
	fi

	echo -n "$foo"
	curl -s "https://pecl.php.net/get/$foo" | tar xzf /dev/stdin >/dev/null 2>&1
	foo=`echo "$foo" | cut -d/ -f1`
	dr=`find . -name "$foo*" -type d | head -n1`
	if [ x"$dr" = x ]; then
		continue;
	fi
	pecl_version=`echo "$dr" | $SED -e 's/^.*-//'`
	cd $dr
	echo -n "[$pecl_version] "
	"${PHP_PREFIX}/bin/phpize" >phpize.log 2>&1 || ( echo -n "[fail] " && continue )
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
