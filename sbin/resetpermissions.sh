#!/bin/bash
if [ ! -d $LBHOMEDIR ]; then
	echo "Cannot find LoxBerry home directory ($LBHOMEDIR)"
	exit 1;
fi
  

echo "LoxBerry home directory is $LBHOMEDIR"

chown -v -R loxberry.loxberry $LBHOMEDIR
chmod -v 600 $LBHOMEDIR/system/network/interfaces
chmod -v 600 $LBHOMEDIR/config/system/*

chmod -v 755 -R $LBHOMEDIR/libs
chmod -v 755 $LBHOMEDIR/sbin
chmod -v -R 755 $LBHOMEDIR/sbin/loxberryupdate
chmod -v -R 755 $LBHOMEDIR/templates/system/*
chmod -v -R 755 $LBHOMEDIR/webfrontend/html/system/*
chmod -v -R 755 $LBHOMEDIR/webfrontend/htmlauth/system/*

chown -v root.root $LBHOMEDIR/system/logrotate/logrotate
