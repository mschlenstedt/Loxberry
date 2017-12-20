#!/bin/bash

if test $UID -ne 0; then
	echo "This script has to be run as root."
	exit;
fi

if [ ! -d $LBHOMEDIR ]; then
	echo "Cannot find LoxBerry home directory ($LBHOMEDIR)"
	exit 1;
fi
  
echo "LoxBerry home directory is $LBHOMEDIR"

chown -v -R loxberry:loxberry $LBHOMEDIR
chown -v root:root $LBHOMEDIR/system/sudoers/lbdefaults
chmod -v 600 $LBHOMEDIR/system/network/interfaces
chmod -v 600 $LBHOMEDIR/config/system/*

chmod -v 755 -R $LBHOMEDIR/libs
chmod -v 755 $LBHOMEDIR/sbin
chmod -v -R 755 $LBHOMEDIR/sbin/loxberryupdate
chmod -v -R 755 $LBHOMEDIR/templates/system/*
chmod -v -R 755 $LBHOMEDIR/webfrontend/html/system/*
chmod -v -R 755 $LBHOMEDIR/webfrontend/htmlauth/system/*

chown -v root.root $LBHOMEDIR/system/logrotate/logrotate
chown -vR root.root $LBHOMEDIR/sbin/system/*
chown -vR root.root $LBHOMEDIR/sbin/plugins/*

