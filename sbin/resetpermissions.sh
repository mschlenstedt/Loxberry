#!/bin/bash

if test $UID -ne 0; then
	echo "This script has to be run as root. Exiting."
	exit 1
fi

# set environment
if [ -f /etc/environment ]; then
	        . /etc/environment
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

#chown -Rv loxberry:loxberry $LBHOMEDIR
#find $LBHOMEDIR -not -path "*skel_syslog*" -exec chown -Rc loxberry:loxberry {} \;

#find $LBHOMEDIR -type d -print | grep -z -v /tmp/excludelist.txt | while read line ; do chown -c loxberry:loxberry $line ; chown -c loxberry:loxberry $line/* ; done


find $LBHOMEDIR ! -path "*ramlog*" ! -path "*skel_syslog*" ! -path "*/system/sudoers*" ! -path "*/system/daemons/system*" -print0 | perl -e '@pipe = split(/\0/, <>); (undef,undef,$uid,$gid) = getpwnam("loxberry");$count=chown $uid, $gid, @pipe;print "chmod loxberry:loxberry: $count files changed\n";'
 
 
chown -Rc root:root $LBHOMEDIR/system/dphys-swapfile
chown -Rc root:root $LBHOMEDIR/system/sudoers/
chown -Rc root:root $LBHOMEDIR/system/daemons
chown -Rc root:root $LBHOMEDIR/system/cron/cron.d
chown -Rc root:root $LBHOMEDIR/sbin
chown -Rc root:root $LBHOMEDIR/system/logrotate
chown -Rc root:root $LBHOMEDIR/system/php
chown -Rc root:root $LBHOMEDIR/config/system/securepin.dat
chown -Rc root:root $LBHOMEDIR/data/system/plugindatabase.json-
chown -Rc root:root $LBHOMEDIR/system/php
chown -Rc loxberry:loxberry /var/log/apache2
chown -Rc loxberry:loxberry /var/cache/apache2
chown -Rc loxberry:loxberry /var/lib/apache2
chown -Rc loxberry:loxberry /var/log/lighttpd
chown -Rc loxberry:loxberry /var/cache/lighttpd
chown -Rc root:root $LBHOMEDIR/system/profile/loxberry.sh
chown -c root:root $LBHOMEDIR/system/vsftpd/vsftpd.conf
chown -c loxberry:loxberry /etc/timezone
chown -c loxberry:loxberry /etc/localtime

chmod -c 600 $LBHOMEDIR/system/network/interfaces
chmod -c 600 $LBHOMEDIR/config/system/*
chmod -c 600 $LBHOMEDIR/data/system/netshares.dat
chmod -c 644 $LBHOMEDIR/config/system/securepin.dat
chmod -c 644 $LBHOMEDIR/data/system/plugindatabase.json-
chmod -c 555 $LBHOMEDIR/system/sudoers
chmod -c 664 $LBHOMEDIR/system/sudoers/lbdefaults
chmod -c 755 $LBHOMEDIR/system/profile
chmod -c 700 $LBHOMEDIR/system/samba/credentials
chmod -c 644 $LBHOMEDIR/system/profile/loxberry.sh
chmod -Rc 644 $LBHOMEDIR/system/logrotate/*

chmod -Rc 755 $LBHOMEDIR/libs
chmod -Rc 755 $LBHOMEDIR/sbin
chmod -c 755 $LBHOMEDIR/bin/*
chmod -Rc 755 $LBHOMEDIR/webfrontend/htmlauth/system/*.cgi
chmod -Rc 755 $LBHOMEDIR/webfrontend/htmlauth/system/*/*.cgi
chmod -Rc 755 $LBHOMEDIR/webfrontend/htmlauth/system/*.pl
chmod -Rc 755 $LBHOMEDIR/webfrontend/htmlauth/system/*/*.pl

exit 0
