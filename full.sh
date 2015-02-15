#!/bin/sh

# check for correct interpreter
if [ `echo -n | grep -c -- -n` -gt 0 ]; then
	if [ `bash -c 'echo -n | grep -c -- -n'` -gt 0 ]; then
		echo "Can't do anything for you with this bash! :("
		exit 1
	fi
	exec bash "$0" "$@"
fi

OPTS="$@"
SCRIPT_VERSION="1.0"

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
	echo "Updating full.sh, please wait..."
	curl -s "https://raw.githubusercontent.com/MagicalTux/automation/master/full.sh" >full.sh~
	if [ "$?" != "0" ]; then
		echo "An error occured while downloading the new full.sh. Aborting update..."
		exit
	fi
	mv -f full.sh~ full.sh; chmod 0755 full.sh
	exit
fi
# Do we have last version?
echo -n "Checking for last version of full.sh..."
LAST_VERSION=`curl -s "https://raw.githubusercontent.com/MagicalTux/automation/master/versions.txt" | grep "^full.sh" | awk '{ print $2 }'`
if [ x"$LAST_VERSION" != x"$SCRIPT_VERSION" ]; then
	echo "new version available"
	echo "Updating full.sh, please wait..."
	curl -s "https://raw.githubusercontent.com/MagicalTux/automation/master/full.sh" >full.sh~
	if [ "$?" != "0" ]; then
		echo "An error occured while downloading the new full.sh. Aborting update..."
	else
		# We'll do everything in only one line, seems that sh has problems with updates in other cases...
		mv -f full.sh~ full.sh; chmod 0755 full.sh; exec ./full.sh "$OPTS"; exit
	fi
else
	echo
fi

