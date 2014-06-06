#!/bin/sh
# This script will convert any linux to gentoo
# It was made to be used on SERVERS !!

# Where to create the gentoo chroot
GENTOO_TMP="/root/gentoo"

# Which mirror to use?
#GENTOO_MIRROR="http://www.gtlib.gatech.edu/pub/gentoo"
#GENTOO_SYNC="rsync://rsync.us.gentoo.org/gentoo-portage"
GENTOO_MIRROR="http://mirror.ovh.net/gentoo-distfiles"
GENTOO_SYNC="rsync://rsync.europe.gentoo.org/gentoo-portage"

# Configure a binhost if you want to speed up process
GENTOO_BINHOST=""

# Should we install base tools (ssh, cron, locate, etc) ?
GENTOO_INSTALL_STUFF="yes"

# Backups of some stuff, like /etc and /var, will be stored there
DATA_BACKUP="/root/previous"

# Which gentoo release to install? amd64 or x86 (or something else?)
# You can only update to the same kind of system, with one exception:
# amd64 -> x86
#
# You can x86 -> amd64 if you first install and reboot on an amd64 kernel
GENTOO_RELEASE="amd64"

# Gentoo version to install ("current" will only work with HTTP mirrors)
GENTOO_VERSION="current"

# Should we use stable or testing ?
GENTOO_USE_TESTING="yes"

#Detect some binaries
WGET=`which wget 2>/dev/null`
RSYNC=`which rsync 2>/dev/null`
CHROOT=`which chroot 2>/dev/null`
BUNZIP2=`which bunzip2 2>/dev/null`
SESTATUS=`which sestatus 2>/dev/null`

if [ x"$WGET" = x ]; then echo "Sorry, you need wget for this to work"; exit 1; fi
if [ x"$RSYNC" = x ]; then echo "Sorry, you need rsync for this to work"; exit 1; fi
if [ x"$CHROOT" = x ]; then echo "Sorry, you need chroot for this to work"; exit 1; fi
if [ x"$BUNZIP2" = x ]; then echo "Sorry, you need bzip2 for this to work"; exit 1; fi

die() {
	echo $1
	exit 1
}

convert_ifconfig() {
	# Those tools will be used after switching to gentoo
	ROUTE=/sbin/route
	IFCONFIG=/sbin/ifconfig
	SED=/bin/sed
	AWK=/usr/bin/awk

	IN_IF=""
	LANG=C "$IFCONFIG" | while read foo; do
		if [ x"$foo" = x ]; then
			IN_IF=""
			continue
		fi
		FIRST=`echo "$foo" | awk '{ print $1 }'`
		case $FIRST in
			eth*)
				echo "# Config for $FIRST"
				IN_IF="$FIRST"
				;;
			inet)
				# got an inet4 addr.
				if [ x"$IN_IF" = x ]; then break; fi
				IP=`echo "$foo" | "$SED" -r -e 's/^.*inet addr:([0-9.]*).*$/\1/'`
				BCAST=`echo "$foo" | "$SED" -r -e 's/^.*Bcast:([0-9.]*).*$/\1/'`
				MASK=`echo "$foo" | "$SED" -r -e 's/^.*Mask:([0-9.]*).*$/\1/'`
				echo "config_${IN_IF}=( \"$IP netmask $MASK\" )"
				;;

			*)
				if [ x"$IN_IF" = x ]; then break; fi
				IN_IF=""
#				echo $IFNAME
#				echo "$foo"
				echo
				;;
		esac
	done

	LANG=C "$ROUTE" -n | while read foo; do
		IF=`echo "$foo" | awk '{ print $8 }'`
		case "$IF" in
			eth*)
				echo "$foo"
				;;
		esac
#		echo "$foo ($IF)"
	#routes_eth0=( "default gw 91.121.140.254" )
	done | while read foo; do
		GW=`echo "$foo" | awk '{ print $2 }'`
		IF=`echo "$foo" | awk '{ print $8 }'`
		NET=`echo "$foo" | awk '{ print $1 }'`
		MASK=`echo "$foo" | awk '{ print $3 }'`
		if [ "$NET" = "0.0.0.0" ]; then
			echo "routes_${IF}=( \"default gw ${GW}\" )"
			continue
		fi
		if [ "$GW" = "0.0.0.0" ]; then
			# this is likely to be an implicit route
#			echo "routes_${IF}=( \"-net $NET netmask $MASK dev ${IF}\" )"
			continue
		fi
		echo "routes_${IF}=( \"-net $NET netmask $MASK gw ${GW}\" )"
	done
}

export LANG=C

# Check for selinux (hard fail)

if [ x"$SESTATUS" != x ]; then
	if [ $("$SESTATUS" | awk '{ print $3 }') != disabled ]; then
		die "Please disable selinux first!"
	fi
fi

# Prepare (cleanup & create)
echo "Preparing environnement..."
umount "$GENTOO_TMP/proc" || true
rm -fr "$GENTOO_TMP" || die "rm failed!"
mkdir "$GENTOO_TMP"
cd "$GENTOO_TMP"

echo "Downloading base gentoo files..."
if [ "$GENTOO_VERSION" = "current" ]; then
	# will only work with HTTP
	STAGE3=`"$WGET" -q -O /dev/stdout "${GENTOO_MIRROR}/releases/${GENTOO_RELEASE}/current-stage3/" | grep 'tar.bz2<' | tail -n 1 | sed -e 's/.*stage3/stage3/;s/bz2.*/bz2/'`

	"$WGET" "${GENTOO_MIRROR}/releases/${GENTOO_RELEASE}/current-stage3/${STAGE3}" \
		|| die "Failed to get stage3"
else
	# Let's get a stage3
	"$WGET" "${GENTOO_MIRROR}/releases/${GENTOO_RELEASE}/${GENTOO_VERSION}/stages/stage3-${GENTOO_RELEASE}-${GENTOO_VERSION}.tar.bz2" \
		|| die "Failed to get stage3"

	STAGE3="stage3-${GENTOO_RELEASE}-${GENTOO_VERSION}.tar.bz2"
fi

# And portage too
"$WGET" "${GENTOO_MIRROR}/snapshots/portage-latest.tar.bz2" \
	|| die "Failed to get latest portage tree!"

# Extract it :)
echo "Extracting base gentoo system"
cat "${STAGE3}" | "$BUNZIP2" | tar xp

# remove our stage3
rm -f "${STAGE3}"

# Add stuff for emerge
echo >>etc/make.conf
echo "# Following lines automatically added by convert_to_gentoo.sh" >>etc/make.conf
echo "GENTOO_MIRRORS=\"${GENTOO_MIRROR}\"" >>etc/make.conf
echo "SYNC=\"${GENTOO_SYNC}\"" >>etc/make.conf
if [ x"$GENTOO_USE_TESTING" = x"yes" ]; then
	echo "ACCEPT_KEYWORDS=\"~${GENTOO_RELEASE}\"" >>etc/make.conf
fi
if [ x"$GENTOO_BINHOST" != x ]; then
	echo "PORTAGE_BINHOST=\"${GENTOO_BINHOST}\"" >>etc/make.conf
	echo "FEATURES=\"getbinpkg\"" >>etc/make.conf
fi

mkdir -p etc/portage
echo "sys-apps/portage" >etc/portage/package.unmask

# Mount proc
mount -t proc proc proc

# get networking to work (need resolv)
cp -f /etc/resolv.conf etc

echo "Installing initial portage"
cat "portage-latest.tar.bz2" | "$BUNZIP2" | tar xpC usr
rm -f "portage-latest.tar.bz2"

# Prepare the system from inside
echo "Syncing portage to latest version"
"$CHROOT" . emerge --sync

echo "Updating new gentoo system to latest version (will take a while)"
# update portage
"$CHROOT" . emerge portage
# get files
"$CHROOT" . emerge -DutNf world e2fsprogs-libs e2fsprogs
# remove useless packages (will break wget); don't care about errors
"$CHROOT" . emerge --unmerge ss com_err man-pages e2fsprogs sysvinit
# fix /etc/init.d/functions.sh to avoid breaking when updating binutils
"$CHROOT" . emerge -u openrc udev
# update and reinstall newer packages
"$CHROOT" . emerge -DutN e2fsprogs-libs e2fsprogs world || die "bad portage, please retry again in 24 hours"

echo "Fixing OpenRC"
"$CHROOT" . rsync -a /usr/share/openrc/runlevels/ /etc/runlevels/

echo "Fixing CA certificates"
"$CHROOT" . find -L /etc/ssl/certs -type l -exec rm -f {} \;
"$CHROOT" . update-ca-certificates

if [ x"$GENTOO_INSTALL_STUFF" = x"yes" ]; then
	echo "Installing extra tools..."
	"$CHROOT" . emerge openssh mlocate vixie-cron ntp syslog-ng logrotate vim iproute2

	"$CHROOT" . rc-update add sshd default
	"$CHROOT" . rc-update add vixie-cron default
	"$CHROOT" . rc-update add syslog-ng default
	"$CHROOT" . rc-update add ntp-client default
	"$CHROOT" . rc-update add ntpd default
fi

# cleanup downloaded files
rm -f usr/portage/distfiles/*

# Force update of config files (we didn't touch anything yet)
echo "-5" | "$CHROOT" . etc-update

# Copy some config files from base system
cp -f /etc/fstab /etc/resolv.conf /etc/mtab etc

# Unmount proc
umount proc || true

# Backup /etc and /var
mkdir "${DATA_BACKUP}" || true
"$RSYNC" -a --one-file-system /etc "${DATA_BACKUP}/"
"$RSYNC" -a --one-file-system /var "${DATA_BACKUP}/"

# Ask for the user for a password
echo "Please choose a root password for your new gentoo system"
"$CHROOT" . passwd || die "No root password set, cancelling"

echo "I am about to erase your current system and replace it with this new gentoo"
echo "If you are sure you want to do that, wait 15 secs and press RETURN"
echo "If not, press CTRL+C NOW!!!"

sleep 15
echo "Press RETURN to continue..."
read

# Make sure /dev is not a mount
umount -l /dev || true

if [ "${GENTOO_RELEASE}" = "amd64" ]; then
	echo "Fixing potentially broken lib dirs on root system"

	if [ ! -L /usr/lib ]; then
		ln -snf lib_old /usr/lib_new
		mv /usr/lib /usr/lib_old; mv /usr/lib_new /usr/lib
	fi
#	if [ ! -L /lib ]; then
		# this one is tricky
# this does not work, it will just screw you
#		ln -snf lib_old /lib_new
#		mv /lib /lib_old; mv /lib_new /lib
#	fi
fi

if [ -f "/usr/local/frontpage/version5.0/apache-fp/_vti_bin/fpexe" ]; then
	echo "fpexe found, maybe from cpanel. Forcing chattr -i"
	chattr -i /usr/local/frontpage/version5.0/apache-fp/_vti_bin/fpexe || true
fi

echo "Erasing root system and replacing with gentoo..."
# Ok, let's erase~ :)
"$RSYNC" -a --delete-before "${GENTOO_TMP}/" "/" \
	--exclude /boot --exclude /proc --exclude /home --exclude /root --exclude /lib/modules \
	--exclude /dev/pts --exclude /sys --exclude /tmp --exclude "${DATA_BACKUP}" || \
	true
ldconfig

mkdir -p /sys /dev/pts || true

echo "Generating network config"
convert_ifconfig >/etc/conf.d/net

echo "Updating environnement..."
env-update

# Ok, we are now in a gentoo system!
. /etc/profile

echo "Removing gentoo template..."
/bin/rm -fr "${GENTOO_TMP}"

echo "Please make sure everything is OK, install a new kernel (emerge gentoo-sources genkernel && genkernel all)"
echo "and restart your system (you can also install grub if you want)"
echo
echo "REMEMBER TO EDIT /etc/conf.d/net !!"
echo
echo "Please run: . /etc/profile"
echo "On each of your shells to finish the switch."
echo
echo "DO NOT RUN SCRIPTS IN /etc/init.d NOW, IT MIGHT REBOOT YOUR SYSTEM!!"

