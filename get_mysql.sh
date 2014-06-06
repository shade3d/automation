#!/bin/sh
SCRIPT_VERSION="1.1"
# Do we have last version of get_mysql.sh?
echo -n "Checking for last version of get_mysql.sh..."
LAST_VERSION=`curl -s "http://ookoo.org/svn/snip/automation/versions.txt" | grep "^get_mysql.sh" | awk '{ print $2 }'`
if [ x"$LAST_VERSION" != x"$SCRIPT_VERSION" ]; then
	echo "new version available"
	echo "Updating get_mysql.sh, please wait..."
	curl -s "http://ookoo.org/svn/snip/automation/get_mysql.sh" >get_mysql.sh~
	if [ "$?" != "0" ]; then
		echo "An error occured while downloading the new get_mysql.sh. Aborting update..."
	else
		# We'll do everything in only one line, seems that sh has problems with updates in other cases...
		mv -f get_mysql.sh~ get_mysql.sh; chmod 0755 get_mysql.sh; . get_mysql.sh; exit
	fi
else
	echo
fi

MYSQL_BRANCH="5.0"

case `uname -m` in
	x86_64)
		MYSQL_BUILD="linux-x86_64-glibc23"
		;;
	*)
		MYSQL_BUILD="linux-i686-glibc23"
		;;
esac

echo -n "Checking for last version of MySQL $MYSQL_BRANCH ($MYSQL_BUILD): "
FILES_LIST_PAGE=`curl -s "http://dev.mysql.com/downloads/mysql/$MYSQL_BRANCH.html"`
LAST_VERSION_MIX=`echo "$FILES_LIST_PAGE" | grep Downloads | grep "$MYSQL_BUILD"`
LAST_VERSION_FILE=`echo "$LAST_VERSION_MIX" | grep -v MD5 | sed -r -e 's/(.*)".*/\1/;s/.*"//;s/.*MySQL-[^/]+\///;s/([^/]*)\/.*/\1/'`
LAST_VERSION_MD5=`echo "$LAST_VERSION_MIX" | grep "MD5" | sed -r -e 's/.*([a-f0-9]{32}).*/\1/'`
LAST_VERSION_STR=`echo "$LAST_VERSION_FILE" | cut -d- -f2`

if [ x"$LAST_VERSION_STR" = x ]; then
	echo "Not found"
	echo "Please report this problem to karpeles@ookoo.org"
	exit 1
fi

echo "$LAST_VERSION_STR"

if [ ! -f "$LAST_VERSION_FILE" ]; then
	echo -n "Best-guess mirror (given by mysql.com): "
	MIRROR_LIST_PAGE=`curl -s "http://dev.mysql.com/get/Downloads/MySQL-$MYSQL_BRANCH/$LAST_VERSION_FILE/from/pick"`
	BEST_MIRROR=`echo "$MIRROR_LIST_PAGE" | grep "$LAST_VERSION_FILE" | grep -v "pick" | sed -e 's/a href/\n/g' | grep '/get/Download' | head -n1 | sed -r -e 's/^[^"]*"//;s/([^"])".*/\1/'`
	BEST_MIRROR_NAME=`echo "$BEST_MIRROR" | sed -r -e 's#.*from/((ht|f)tp://[^/]+)/.*#\1#'`
	echo "$BEST_MIRROR_NAME"

	echo "Downloading MySQL $LAST_VERSION_STR ..."
	curl '-#' -L "http://dev.mysql.com$BEST_MIRROR" >"$LAST_VERSION_FILE"
fi

echo -n "Checking file MD5..."
FILE_MD5=`md5sum -b "$LAST_VERSION_FILE" | awk '{ print $1 }'`
if [ x"$FILE_MD5" != x"$LAST_VERSION_MD5" ]; then
	echo "Error"
	echo "   Local MD5: $FILE_MD5"
	echo "Expected MD5: $LAST_VERSION_MD5"
	exit 1
fi
echo "ok"

echo -n "Preparing MySQL environnement..."
# Ok, we need a mysql user, and various stuff...
# adduser -d /usr/local/mysql -r -s /bin/false mysql


