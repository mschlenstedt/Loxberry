#!/bin/sh
### BEGIN INIT INFO
# Provides:          loxberry
# Required-Start:    $remote_fs $syslog $network $network-online 
# Required-Stop:     $remote_fs $syslog $network $network-online
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: This file starts special things needed by Loxberry.
# Description:       This file starts special things needed by Loxberry.
### END INIT INFO

# Copyright 2016 Michael Schlenstedt, michael@loxberry.de
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Version 1.8

PATH="/sbin:/bin:/usr/sbin:/usr/bin:$LBHOMEDIR/bin:$LBHOMEDIR/sbin"

. /lib/lsb/init-functions
ENVIRONMENT=$(cat /etc/environment)
export $ENVIRONMENT

# ini_parser
# Usage:
# ini_parser <filename> "[SECTION]"
# gives variables $SECTIONsetting
ini_parser() {
    INI_FILE=$1
    INI_SECTION=$2
    eval `sed -e 's/[[:space:]]*\=[[:space:]]*/=/g' \
        -e 's/;.*$//' \
        -e 's/[[:space:]]*$//' \
        -e 's/^[[:space:]]*//' \
        -e "s/^\(.*\)=\([^\"']*\)$/$INI_SECTION\1=\"\2\"/" \
        < $INI_FILE \
        | sed -n -e "/^\[$INI_SECTION\]/,/^\s*\[/{/^[^;].*\=.*/p;}"`
}

case "$1" in
  start|"")

	# Remove old mountpoints from AutoFS and USB automount (in case they were not
	# unmounted correctly and di not exist anymore)
	rm -r /media/usb/* > /dev/null 2>&1
	rm -r /media/smb/* > /dev/null 2>&1

	# Let fsck run only every 10th boot (only for clean devices)
	tune2fs -c 10 /dev/mmcblk0p2 > /dev/null 2>&1

        # Resize rootfs to maximum if not yet done
        if [ ! -f /boot/rootfsresized ]
        then
          log_action_begin_msg "Resizing Rootfs to maximum on next reboot"
          $LBHOMEDIR/sbin/resize_rootfs > /dev/null 2>&1
          touch /boot/rootfsresized
        fi

	# Create Default config
	log_action_begin_msg "Updating general.cfg etc...."
	$LBHOMEDIR/bin/createconfig.pl
	log_action_end_msg 0

	# Create swap config
	log_action_begin_msg "Configuring swap...."
	$LBHOMEDIR/sbin/setswap.pl
	log_action_end_msg 0

        # Copy manual network configuration if any exists
        if [ -f /boot/network.txt ]
        then
			log_action_begin_msg "Found manual network configuration in /boot. Activating..."
			mv $LBHOMEDIR/system/network/interfaces  $LBHOMEDIR/system/network/interfaces.bkp > /dev/null 2>&1
			cp /boot/network.txt  $LBHOMEDIR/system/network/interfaces > /dev/null 2>&1
			dos2unix /etc/network/interfaces > /dev/null 2>&1
			chown loxberry:loxberry $LBHOMEDIR/system/network/interfaces > /dev/null 2>&1
			mv /boot/network.txt /boot/network.bkp > /dev/null 2>&1
			log_action_cont_msg "Rebooting"
			/sbin/reboot > /dev/null 2>&1
        fi

        # Copy new HTACCESS User/Password Database
        if [ -f $LBHOMEDIR/config/system/htusers.dat.new ]
        then
          log_action_begin_msg "Found new htaccess password database. Activating..."
          mv $LBHOMEDIR/config/system/htusers.dat.new $LBHOMEDIR/config/system/htusers.dat > /dev/null 2>&1
        fi

        # Cleaning Temporary folders
        log_action_begin_msg "Cleaning temporary files and folders..."
        rm -rf $LBHOMEDIR/webfrontend/html/tmp/* > /dev/null 2>&1
		rm -f $LBHOMEDIR/log/system_tmpfs/reboot.required > /dev/null 2>&1

        # Set Date and Time
        if [ -f $LBHOMEDIR/sbin/setdatetime.pl ]
        then
          log_action_begin_msg "Syncing Date/Time with Miniserver or NTP-Server"
          $LBHOMEDIR/sbin/setdatetime.pl > /dev/null 2>&1
        fi

    # Create log folders for all plugins if not existing
	perl $LBHOMEDIR/sbin/createpluginfolders.pl > /dev/null 2>&1
	
	# Copy logdb from SD card to RAM disk
	if [ -e $LBHOMEDIR/data/system/logs_sqlite.dat ]
	then
		cp -f $LBHOMEDIR/data/system/logs_sqlite.dat $LBHOMEDIR/log/system_tmpfs/
		chown loxberry:loxberry $LBHOMEDIR/log/system_tmpfs/logs_sqlite.dat
		chmod +rw $LBHOMEDIR/log/system_tmpfs/logs_sqlite.dat
	fi
		
	# Run Daemons from Plugins and from System
        log_action_begin_msg "Running System Daemons"
        run-parts -v  $LBHOMEDIR/system/daemons/system > /dev/null 
	log_action_end_msg 0
		
        log_action_begin_msg "Running Plugin Daemons"
        run-parts -v --new-session $LBHOMEDIR/system/daemons/plugins > /dev/null 
	log_action_end_msg 0
		
	# Check LoxBerry Update cronjobs
	# Recreate them, if config has enabled them, but do not exist
	ini_parser "$LBSCONFIG/general.cfg" "UPDATE"
	log_action_begin_msg "Checking consistence of LoxBerry Update settings"
	echo Update-Settings: INSTALLTYPE is $UPDATEINSTALLTYPE, INTERVAL is $UPDATEINTERVAL
	if [ "$UPDATEINSTALLTYPE" = "notify" ] ||  [ "$UPDATEINSTALLTYPE" = "install" ]; then
		if [ "$UPDATEINTERVAL" = "1" ] && [ ! -e "$LBHOMEDIR/system/cron/cron.daily/loxberryupdate_cron" ]; then
			log_warning_msg "Recreated daily cronjob"
			ln -s "$LBHOMEDIR/sbin/loxberryupdate_cron.sh" "$LBHOMEDIR/system/cron/cron.daily/loxberryupdate_cron"
			if [ -e "$LBHOMEDIR/system/cron/cron.weekly/loxberryupdate_cron" ]; then rm "$LBHOMEDIR/system/cron/cron.weekly/loxberryupdate_cron"; fi
			if [ -e "$LBHOMEDIR/system/cron/cron.monthly/loxberryupdate_cron" ]; then rm "$LBHOMEDIR/system/cron/cron.monthly/loxberryupdate_cron"; fi
		fi
		if [ "$UPDATEINTERVAL" = "7" ] && [ ! -e "$LBHOMEDIR/system/cron/cron.weekly/loxberryupdate_cron" ]; then
			log_warning_msg "Recreated weekly cronjob"
			ln -s "$LBHOMEDIR/sbin/loxberryupdate_cron.sh" "$LBHOMEDIR/system/cron/cron.weekly/loxberryupdate_cron"
		if [ -e "$LBHOMEDIR/system/cron/cron.daily/loxberryupdate_cron" ]; then rm "$LBHOMEDIR/system/cron/cron.daily/loxberryupdate_cron"; fi
		if [ -e "$LBHOMEDIR/system/cron/cron.monthly/loxberryupdate_cron" ]; then rm "$LBHOMEDIR/system/cron/cron.monthly/loxberryupdate_cron"; fi

		fi
		if [ "$UPDATEINTERVAL" = "30" ] && [ ! -e "$LBHOMEDIR/system/cron/cron.monthly/loxberryupdate_cron" ]; then
			log_warning_msg "Recreated monthly cronjob"
			ln -s "$LBHOMEDIR/sbin/loxberryupdate_cron.sh" "$LBHOMEDIR/system/cron/cron.monthly/loxberryupdate_cron"
			if [ -e "$LBHOMEDIR/system/cron/cron.daily/loxberryupdate_cron" ]; then rm "$LBHOMEDIR/system/cron/cron.daily/loxberryupdate_cron"; fi
			if [ -e "$LBHOMEDIR/system/cron/cron.weekly/loxberryupdate_cron" ]; then rm "$LBHOMEDIR/system/cron/cron.weekly/loxberryupdate_cron"; fi

		fi
	else
		log_action_cont_msg "Updates are disabled, checking and deleting cronjobs"
		if [ -e "$LBHOMEDIR/system/cron/cron.daily/loxberryupdate_cron" ]; then rm "$LBHOMEDIR/system/cron/cron.daily/loxberryupdate_cron"; fi
		if [ -e "$LBHOMEDIR/system/cron/cron.weekly/loxberryupdate_cron" ]; then rm "$LBHOMEDIR/system/cron/cron.weekly/loxberryupdate_cron"; fi
		if [ -e "$LBHOMEDIR/system/cron/cron.monthly/loxberryupdate_cron" ]; then rm "$LBHOMEDIR/system/cron/cron.monthly/loxberryupdate_cron"; fi
	fi
	log_action_end_msg 0
		
	;;
	restart|reload|force-reload|status)
        echo "Error: argument '$1' not supported" >&2
        exit 3
  ;;

  stop)
	# Add "nofail" option to all mounts in /etc/fstab (needed for USB automount to work correctly)
	awk '!/^#/ { if(!match($4, /nofail/)) $4=$4",nofail" } 1' /etc/fstab > /etc/fstab.new
	cp /etc/fstab /etc/fstab.backup
	cat /etc/fstab.new > /etc/fstab
	rm /etc/fstab.new
	
	# Copy logdb from RAM disk to SD card
	if [ -e $LBHOMEDIR/log/system_tmpfs/logs_sqlite.dat ]
	then
		 echo "VACUUM;" | sqlite3 $LBHOMEDIR/log/system_tmpfs/logs_sqlite.dat
		cp -f $LBHOMEDIR/log/system_tmpfs/logs_sqlite.dat $LBHOMEDIR/data/system/
	fi
  ;;

  *)
        echo "Usage: $0 [start|stop]" >&2
        exit 3
  ;;

esac



