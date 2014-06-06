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
