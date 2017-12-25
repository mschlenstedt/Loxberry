#!/bin/bash

# Wrapper script to install plugin crontab's into ~/system/cron/cron.d

SUDO=`which sudo`
if [ -x $SUDO ]; then
   if [ $UID -ne 0 ]; then
            exec $SUDO $0 $*
   fi
fi

if [ -z $2 ]; then
   echo "Missing argument."
   echo "Usage: $0 <pluginname> <crontabfile>"
   exit 1
fi

if [ ! -e $LBHOMEDIR/system/cron/cron.d/$1 ]; then
   echo "The crontab does not exist."
   echo "Usage: $0 <pluginname> <crontabfile>"
   exit 1
fi

if [ ! -e $2 ]; then
   echo "File does not exist."
   echo "Usage: $0 <pluginname> <crontabfile>"
   exit 1
fi

SED=`which sed`
$SED  "s/[[:space:]]root[[:space:]]/ loxberry /Ig" $2 > $LBHOMEDIR/system/cron/cron.d/$1
echo "New crontab for $1 installed successfully."

exit 0
