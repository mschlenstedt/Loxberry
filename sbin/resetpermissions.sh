#!/bin/bash

if test $UID -ne 0; then
	echo "This script has to be run as root. Exiting."
	exit 1
fi

if [ ! -d $LBHOMEDIR ]; then
	echo "Cannot find LoxBerry home directory ($LBHOMEDIR). Exiting."
	exit 1
fi

if [ "$LBHOMEDIR" == "" ]; then
	echo "Variable LBHOMEDIR is empty. Exiting."
	exit 1
fi

if [ ! -e "$LBHOMEDIR/config/system/general.cfg" ] && [ ! -e "$LBHOMEDIR/config/system/general.cfg.default" ]; then
	echo "Cannot find general.cfg or general.cfg.default. Something is strange here. Exiting."
	exit 1
fi

echo "LoxBerry home directory is $LBHOMEDIR"

chown -Rv loxberry:loxberry $LBHOMEDIR
chown -Rv root:root $LBHOMEDIR/system/sudoers/
chown -Rv root:root $LBHOMEDIR/system/daemons
chown -Rv root:root $LBHOMEDIR/system/cron/cron.d
chown -Rv root.root $LBHOMEDIR/sbin
chown -Rv root.root $LBHOMEDIR/system/logrotate
chown -Rv root.root $LBHOMEDIR/system/php
chown -Rv root.root $LBHOMEDIR/config/system/installpin.dat
chown -v loxberry.loxberry /etc/timezone
chown -v loxberry.loxberry /etc/localtime

chmod -v 600 $LBHOMEDIR/system/network/interfaces
chmod -v 600 $LBHOMEDIR/config/system/*

chmod -Rv 755 $LBHOMEDIR/libs
chmod -Rv 755 $LBHOMEDIR/sbin
chmod -Rv 755 $LBHOMEDIR/webfrontend/htmlauth/system/*.cgi
chmod -Rv 755 $LBHOMEDIR/webfrontend/htmlauth/system/*/*.cgi
chmod -Rv 755 $LBHOMEDIR/webfrontend/htmlauth/system/*.pl
chmod -Rv 755 $LBHOMEDIR/webfrontend/htmlauth/system/*/*.pl

exit 0
