OPTS="$@"
SCRIPT_VERSION="M4_VERSION"

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
	echo "Updating M4_TARGET, please wait..."
	curl -s "https://raw.githubusercontent.com/Tibanne/automation/master/M4_TARGET" >M4_TARGET~
	if [ "$?" != "0" ]; then
		echo "An error occured while downloading the new M4_TARGET. Aborting update..."
		exit
	fi
	mv -f M4_TARGET~ M4_TARGET; chmod 0755 M4_TARGET
	exit
fi
# Do we have last version?
echo -n "Checking for last version of M4_TARGET..."
LAST_VERSION=`curl -s "https://raw.githubusercontent.com/Tibanne/automation/master/versions.txt" | grep "^M4_TARGET" | awk '{ print $2 }'`
if [ x"$LAST_VERSION" != x"$SCRIPT_VERSION" ]; then
	echo "new version available"
	echo "Updating M4_TARGET, please wait..."
	curl -s "https://raw.githubusercontent.com/Tibanne/automation/master/M4_TARGET" >M4_TARGET~
	if [ "$?" != "0" ]; then
		echo "An error occured while downloading the new M4_TARGET. Aborting update..."
	else
		# We'll do everything in only one line, seems that sh has problems with updates in other cases...
		mv -f M4_TARGET~ M4_TARGET; chmod 0755 M4_TARGET; exec ./M4_TARGET "$OPTS"; exit
	fi
else
	echo
fi

