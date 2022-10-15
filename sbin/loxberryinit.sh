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
	# Test if / is writable
	echo -n "Testing root filesystem: "
	touch /readonlycheck
	if [ $? -eq 0 ]; then
	 rm -f /readonlycheck
	 echo "OK"
	else
	 echo "Not OK, try to restore /etc/fstab and reboot in 10s"
	 sleep 10
	 $0 fsrestore
	fi 

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

	# Start LoxBerrys Emergency Webserver
	if [ ! jq -r '.Webserver.Disableemergencywebserver' $LBHOMEDIR/config/system/general.json ]
	then
		echo "Start Emergency Webserver"
		perl $LBHOMEDIR/sbin/emergencywebserver.pl > /dev/null 2>&1 &
	fi
		
	# Run Daemons from Plugins and from System
	echo "Running System Daemons..."
	#run-parts -v $LBHOMEDIR/system/daemons/system > /dev/null 
	for SYSTEMDAEMONS in $LBHOMEDIR/system/daemons/system/*
	do
		echo "Running $SYSTEMDAEMONS..."
	       	$SYSTEMDAEMONS > /dev/null
	done
		
	echo "Preparing Plugin Daemons..."
	#run-parts -v --new-session --test $LBHOMEDIR/system/daemons/plugins |while read PLUGINDAEMONS; do
	for PLUGINDAEMONS in $LBHOMEDIR/system/daemons/plugins/*
	do
		echo "Running $PLUGINDAEMONS..."
		$PLUGINDAEMONS > /dev/null &
		sleep 1
	done

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
	echo "Checking fstab...."
	# Check if there are any missing "nofail"'s...
	COUNT=$(grep -a "^[^#]" /etc/fstab | grep -a -v "nofail" | grep -a -v "/ ext4" | wc -l)
	if [ ${COUNT} -gt 0 ]; then
		echo "Found lines with missing nofail option."
		awk '!/^#/ && !/^\s/ && /^[a-zA-Z0-9]/ { if(!match($4,/nofail/)) $4=$4",nofail" } 1' /etc/fstab > /etc/fstab.new
		sed -i 's/\(\/ ext4 .*\),nofail\(.*\)/\1\2/' /etc/fstab.new # remove nofail for /
		FILESIZE=$(wc -c < /etc/fstab.new)
		ISASCII=$(file /etc/fstab.new | grep -a "ASCII text" | wc -l)
		if [ "$FILESIZE" -gt 50 ] && [ "$ISASCII" -ne 0 ]]; then
			findmnt -F /etc/fstab.new / > /dev/null
			if [ $? -eq 0 ]; then
				echo "New fstab seems to be valid. Deleting original and copy new file."
				cp /etc/fstab /etc/fstab.backup
				mv /etc/fstab.new /etc/fstab
			else
				echo "ERROR patching /etc/fstab (findmnt) - Skipping..."
			fi
		else
			echo "ERROR patching /etc/fstab (filesize/filetype) - Skipping..."
		fi
	else
		echo "Everything OK, nothing to do."
	fi
	echo "Configuring NTP systemd timesync...."
	systemctl disable systemd-timesyncd > /dev/null 2>&1
  ;;

  fsrestore)
	echo "Try to restore /etc/fstab from /etc/fstab.backup ...."
	/bin/mount -o remount,rw /
	stamp=`date '+%Y-%m-%d_%Hh%Mm%Ss'`
	echo "Current /etc/fstab is saved to /etc/fstab.restored_$stamp"
	cp /etc/fstab /etc/fstab.restored_$stamp
	FILESIZE=$(wc -c < /etc/fstab.backup)
	ISASCII=$(file /etc/fstab.backup | grep -a "ASCII text" | wc -l)
	if [ "$FILESIZE" -gt 50 ] && [ "$ISASCII" -ne 0 ]; then
		findmnt -F /etc/fstab.backup / > /dev/null
		if [ $? -eq 0 ]; then
			echo "/etc/fstab.backup seems to be valid. Using it for restoring."
			COPY=1
		else
			echo "/etc/fstab.backup isn't valid (findmnt). Will not use it."
			COPY=0
		fi
	else
		echo "/etc/fstab.backup isn't valid (filesize/filetype). Will not use it."
		COPY=0
	fi
	if [ "$COPY" -ne 0 ]; then
		cp /etc/fstab.backup /etc/fstab 
		if [ $? -eq 0 ]; then
	 		echo "Restore done. Rebooting...."
			echo "Your fstab was broken. We tried to restore it. You have to reboot your LoxBerry now." >> $LBHOMEDIR/log/system_tmpfs/reboot.force
			echo "Your fstab was broken. We tried to restore it. You have to reboot your LoxBerry now." >> $LBHOMEDIR/log/system_tmpfs/reboot.required
		else
	 		echo "Restore failed."
			COPY=0
		fi
	fi

	if [ "$COPY" -eq 0 ] && [ -f "$LBHOMEDIR/config/system/is_raspberry.cfg" ]; then
		echo "Last chance: I will create a default /etc/fstab."
		touch /etc/fstab
		echo "proc /proc proc defaults,nofail 0 0" > /etc/fstab
		echo "PARTUUID=4bd27daf-01 /boot vfat defaults,nofail 0 2" >> /etc/fstab
		echo "PARTUUID=4bd27daf-02 / ext4 defaults,noatime 0 1" >> /etc/fstab
		echo "Your fstab was broken. We tried to restore it. You have to reboot your LoxBerry now." >> $LBHOMEDIR/log/system_tmpfs/reboot.force
		echo "Your fstab was broken. We tried to restore it. You have to reboot your LoxBerry now." >> $LBHOMEDIR/log/system_tmpfs/reboot.required
	fi

  ;;

  *)
        echo "Usage: $0 [start|stop|fsrestore]" >&2
        exit 3
  ;;

esac



