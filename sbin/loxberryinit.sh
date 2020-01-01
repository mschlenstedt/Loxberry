#!/bin/sh
PATH="/sbin:/bin:/usr/sbin:/usr/bin:$LBHOMEDIR/bin:$LBHOMEDIR/sbin"

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
  start)

	# Remove old mountpoints from AutoFS and USB automount (in case they were not
	# unmounted correctly and di not exist anymore)
	echo "Cleaning old mount points...."
	for folder in /media/usb/*
	do
		if [ -d ${folder} ]
		then
			if  ! mount | grep -q ${folder}
			then
				rm -r ${folder} > /dev/null 2>&1
			fi
		fi
	done

	for folder in /media/smb/*
	do
		if [ -d ${folder} ]
		then
			if  ! mount | grep -q ${folder}
			then
				rm -r ${folder} > /dev/null 2>&1
			fi
		fi
	done

	# Let fsck run only every 10th boot (only for clean devices)
	tune2fs -c 10 /dev/mmcblk0p2 

	# Resize rootfs to maximum if not yet done
	# This is done by index.cgi now
	# if [ ! -f /boot/rootfsresized ]
	# then
	#   echo "Resizing Rootfs to maximum on next reboot"
	#   $LBHOMEDIR/sbin/resize_rootfs > /dev/null 2>&1
	#   touch /boot/rootfsresized
	#   log_action_end_msg 0
	# fi

	# Create Default config
	echo "Updating general.cfg etc...."
	$LBHOMEDIR/bin/createconfig.pl

	# Create swap config
	if [ -f /boot/rootfsresized ]
	then
		echo "Configuring swap...."
		$LBHOMEDIR/sbin/setswap.pl
	else
		echo "Deactivating swap - rootfs seems not to be resized yet...."
		service dphys-swapfile stop
		swapoff -a
		rm -rf /var/swap
	fi

	# Copy manual network configuration if any exists
	if [ -f /boot/network.txt ]
	then
		echo "Found manual network configuration in /boot. Activating..."
		mv $LBHOMEDIR/system/network/interfaces  $LBHOMEDIR/system/network/interfaces.bkp > /dev/null 2>&1
		cp /boot/network.txt  $LBHOMEDIR/system/network/interfaces > /dev/null 2>&1
		dos2unix $LBHOMEDIR/system/network/interfaces > /dev/null 2>&1
		chown loxberry:loxberry $LBHOMEDIR/system/network/interfaces > /dev/null 2>&1
		mv /boot/network.txt /boot/network.bkp > /dev/null 2>&1
		echo "Rebooting"
		/sbin/reboot > /dev/null 2>&1
	fi

	# Copy new HTACCESS User/Password Database
	if [ -f $LBHOMEDIR/config/system/htusers.dat.new ]
	then
		echo "Found new htaccess password database. Activating..."
		mv $LBHOMEDIR/config/system/htusers.dat.new $LBHOMEDIR/config/system/htusers.dat > /dev/null 2>&1
	fi

	# Cleaning Temporary folders
	echo "Cleaning temporary files and folders..."
	rm -rf $LBHOMEDIR/webfrontend/html/tmp/* > /dev/null 2>&1
	rm -f $LBHOMEDIR/log/system_tmpfs/reboot.required > /dev/null 2>&1
	rm -f $LBHOMEDIR/log/system_tmpfs/reboot.force > /dev/null 2>&1

	# Set Date and Time
	if [ -f $LBHOMEDIR/sbin/setdatetime.pl ]
	then
		echo "Syncing Date/Time with Miniserver or NTP-Server"
		$LBHOMEDIR/sbin/setdatetime.pl > /dev/null 2>&1
	fi

	# Create log folders for all plugins if not existing
	echo "Create log folders for all installed plugins"
	perl $LBHOMEDIR/sbin/createpluginfolders.pl > /dev/null 2>&1
		
	# Run Daemons from Plugins and from System
	echo "Running System Daemons..."
	run-parts -v $LBHOMEDIR/system/daemons/system > /dev/null 
		
	echo "Running Plugin Daemons..."
	run-parts -v --new-session $LBHOMEDIR/system/daemons/plugins > /dev/null 
		
	# Check LoxBerry Update cronjobs
	# Recreate them, if config has enabled them, but do not exist
	ini_parser "$LBSCONFIG/general.cfg" "UPDATE"
	echo "Checking consistence of LoxBerry Update settings..."
	echo "Update-Settings: INSTALLTYPE is $UPDATEINSTALLTYPE, INTERVAL is $UPDATEINTERVAL"
	if [ "$UPDATEINSTALLTYPE" = "notify" ] ||  [ "$UPDATEINSTALLTYPE" = "install" ]; then
		if [ "$UPDATEINTERVAL" = "1" ] && [ ! -e "$LBHOMEDIR/system/cron/cron.daily/loxberryupdate_cron" ]; then
			echo "Recreated daily cronjob"
			ln -s "$LBHOMEDIR/sbin/loxberryupdate_cron.sh" "$LBHOMEDIR/system/cron/cron.daily/loxberryupdate_cron"
			if [ -e "$LBHOMEDIR/system/cron/cron.weekly/loxberryupdate_cron" ]; then rm "$LBHOMEDIR/system/cron/cron.weekly/loxberryupdate_cron"; fi
			if [ -e "$LBHOMEDIR/system/cron/cron.monthly/loxberryupdate_cron" ]; then rm "$LBHOMEDIR/system/cron/cron.monthly/loxberryupdate_cron"; fi
		fi
		if [ "$UPDATEINTERVAL" = "7" ] && [ ! -e "$LBHOMEDIR/system/cron/cron.weekly/loxberryupdate_cron" ]; then
			echo "Recreated weekly cronjob"
			ln -s "$LBHOMEDIR/sbin/loxberryupdate_cron.sh" "$LBHOMEDIR/system/cron/cron.weekly/loxberryupdate_cron"
		if [ -e "$LBHOMEDIR/system/cron/cron.daily/loxberryupdate_cron" ]; then rm "$LBHOMEDIR/system/cron/cron.daily/loxberryupdate_cron"; fi
		if [ -e "$LBHOMEDIR/system/cron/cron.monthly/loxberryupdate_cron" ]; then rm "$LBHOMEDIR/system/cron/cron.monthly/loxberryupdate_cron"; fi

		fi
		if [ "$UPDATEINTERVAL" = "30" ] && [ ! -e "$LBHOMEDIR/system/cron/cron.monthly/loxberryupdate_cron" ]; then
			echo "Recreated monthly cronjob"
			ln -s "$LBHOMEDIR/sbin/loxberryupdate_cron.sh" "$LBHOMEDIR/system/cron/cron.monthly/loxberryupdate_cron"
			if [ -e "$LBHOMEDIR/system/cron/cron.daily/loxberryupdate_cron" ]; then rm "$LBHOMEDIR/system/cron/cron.daily/loxberryupdate_cron"; fi
			if [ -e "$LBHOMEDIR/system/cron/cron.weekly/loxberryupdate_cron" ]; then rm "$LBHOMEDIR/system/cron/cron.weekly/loxberryupdate_cron"; fi

		fi
	else
		echo "Updates are disabled, checking and deleting cronjobs..."
		if [ -e "$LBHOMEDIR/system/cron/cron.daily/loxberryupdate_cron" ]; then rm "$LBHOMEDIR/system/cron/cron.daily/loxberryupdate_cron"; fi
		if [ -e "$LBHOMEDIR/system/cron/cron.weekly/loxberryupdate_cron" ]; then rm "$LBHOMEDIR/system/cron/cron.weekly/loxberryupdate_cron"; fi
		if [ -e "$LBHOMEDIR/system/cron/cron.monthly/loxberryupdate_cron" ]; then rm "$LBHOMEDIR/system/cron/cron.monthly/loxberryupdate_cron"; fi
	fi
	exit 0
  ;;
	
  stop)
	# Add "nofail" option to all mounts in /etc/fstab (needed for USB automount to work correctly)
	echo "Configuring fstab...."
	awk '!/^#/ && !/^\s/ && /^[a-zA-Z0-9]/ { if(!match($4,/nofail/)) $4=$4",nofail" } 1' /etc/fstab > /etc/fstab.new
	sed -i 's/\(\/ ext4 .*\),nofail\(.*\)/\1\2/' /etc/fstab.new # remove nofail for /
	cp /etc/fstab /etc/fstab.backup
	cat /etc/fstab.new > /etc/fstab
	rm /etc/fstab.new
	echo "Configuring NTP systemd timesync...."
	systemctl disable systemd-timesyncd > /dev/null 2>&1
  ;;

  *)
        echo "Usage: $0 [start|stop]" >&2
        exit 3
  ;;

esac



