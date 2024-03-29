#!/bin/bash

if test $UID -ne 0; then
  echo "This script has to be run as root. Exiting."
  exit 1
fi

if [ ! $1 ]; then
	echo "Give a Commit Hash from https://github.com/raspberrypi/rpi-firmware as first parameter."
	exit
fi

echo ""
echo "Note: Use this script *after* you have upgraded to the target OS version. Otherwise checksums may be incorrect."
echo ""

if [ -e /boot.tmp ]; then
	echo "/boot.tmp exists. Will not continue."
	exit 1
fi

if [ -e /root.tmp ]; then
	echo "/root.tmp exists. Will not continue."
	exit 1
fi

mkdir -p /boot.tmp
mkdir -p /root.tmp

# Use this Firmware hash
HASH=$1

SKIP_WARNING=1 SKIP_BACKUP=1 BRANCH=stable WANT_PI4=1 WANT_32BIT=1 SKIP_CHECK_PARTITION=1 BOOT_PATH=/boot.tmp ROOT_PATH=/root.tmp /usr/bin/rpi-update $HASH

echo ""
echo ""
echo "Results:"
echo "--------"
echo ""
echo -n "GIT Firmware Hash:   "
cat /boot.tmp/.firmware_revision

echo -n "dirtree Checksum is: "
/opt/loxberry/bin/dirtree_md5.pl --path=/boot.tmp

rm -r /boot.tmp
rm -r /root.tmp
