#!/bin/bash

if test $UID -ne 0; then
  echo "This script has to be run as root. Exiting."
  exit 1
fi

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

SKIP_WARNING=1 SKIP_BACKUP=1 BRANCH=stable WANT_PI4=1 SKIP_CHECK_PARTITION=1 BOOT_PATH=/boot.tmp ROOT_PATH=/root.tmp /usr/bin/rpi-update

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
