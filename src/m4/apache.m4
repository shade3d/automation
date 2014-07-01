if [ x"${APACHE_PREFIX}" = x ]; then
	APACHE_PREFIX="/usr/local/httpd"
fi

if [ ! -d "$APACHE_PREFIX" ]; then
	APACHE_PREFIX=none
	echo "Not using Apache"
else
	echo "Using Apache in ${APACHE_PREFIX}"
fi

