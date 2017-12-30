#!/bin/bash

if test $UID -ne 0; then
	echo "$0: This script has to be run as root. Exiting.<br>"
	exit 1
fi

if [ ! -d $LBHOMEDIR ]; then
	echo "$0: Cannot find LoxBerry home directory ($LBHOMEDIR). Exiting.<br>"
	exit 1
fi

if [ "$LBHOMEDIR" == "" ]; then
	echo "$0: Variable LBHOMEDIR is empty. Exiting.<br>"
	exit 1
fi

if [ ! -e "$LBHOMEDIR/config/system/general.cfg" ] && [ ! -e "$LBHOMEDIR/config/system/general.cfg.default" ]; then
	echo "$0: Cannot find general.cfg or general.cfg.default. Something is strange here. Exiting.<br>"
	exit 1
fi

echo "$0: LoxBerry home directory is $LBHOMEDIR<br>"
