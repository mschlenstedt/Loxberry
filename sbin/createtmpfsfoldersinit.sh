#!/bin/bash

ENVIRONMENT=$(cat /etc/environment)
export $ENVIRONMENT

PATH="/sbin:/bin:/usr/sbin:/usr/bin::$LBHOMEDIR/bin:$LBHOMEDIR/sbin"
if [ -e /boot/dietpi/.hw_model ]; then
	. /boot/dietpi/.hw_model
	PIVERS=$G_HW_MODEL
else
	PIVERS=`$LBHOMEDIR/bin/showpitype`
fi
MANUALCFG=`jq -r '.Log2ram.Manualconfigured' $LBHOMEDIR/config/system/general.json`
MEM=`cat /proc/meminfo | awk '/MemTotal:/ { print $2 }'`

if [ ! "$MANUALCFG" ] || [ "$MANUALCFG" = 'null' ] || [ "$MANUALCFG" = 'false' ] || [ "$MANUALCFG" = '0' ]; then
	echo "No manual config found. Using defaults..."
	RAM_LOG=$LBHOMEDIR/log/ramlog
	if [ "$PIVERS" = 'type_0' ] || [ "$PIVERS" = 'type_1' ] || [ "$PIVERS" = 'type_2' ] || [ "$PIVERS" -lt '3' ]; then
		SIZE=200M
		ZL2R=false
		COMP_ALG=lz4
		LOG_DISK_SIZE=200M
	else
		SIZE=200M
		ZL2R=true
		COMP_ALG=lz4
		LOG_DISK_SIZE=415M
	fi
	#
	# Start Workaround for Pi4 with 8 GB. zram driver does not work here at the moment...
	# https://github.com/foundObjects/zram-swap/issues/3
	#
	if [[ ( "$PIVERS" = 'type_4' || "$PIVERS" = '4' ) && "$MEM" -gt 4000257 ]]; then
		SIZE=415M
		ZL2R=false
		COMP_ALG=lz4
		LOG_DISK_SIZE=415M
	fi
	#
	# End: Workaround
	#
	JSON=`jq ".Log2ram.Manualconfigured = \"0\"" $LBHOMEDIR/config/system/general.json`
	JSON=`echo $JSON | jq ".Log2ram.Ramlog = \"$RAM_LOG\""`
	JSON=`echo $JSON | jq ".Log2ram.Size = \"$SIZE\""`
	JSON=`echo $JSON | jq ".Log2ram.Zl2r = \"$ZL2R\""`
	JSON=`echo $JSON | jq ".Log2ram.Compalg = \"$COMP_ALG\""`
	JSON=`echo $JSON | jq ".Log2ram.Logdisksize = \"$LOG_DISK_SIZE\""`
	echo $JSON | jq "." > $LBHOMEDIR/config/system/general.json.new
	mv $LBHOMEDIR/config/system/general.json.new $LBHOMEDIR/config/system/general.json
	chown loxberry:loxberry $LBHOMEDIR/config/system/general.json
else
	echo "Using config from $LBHOMEDIR/config/system/general.json..."
	RAM_LOG=`jq -r '.Log2ram.Ramlog' $LBHOMEDIR/config/system/general.json`
	SIZE=`jq -r '.Log2ram.Size' $LBHOMEDIR/config/system/general.json`
	ZL2R=`jq -r '.Log2ram.Zl2r' $LBHOMEDIR/config/system/general.json`
	COMP_ALG=`jq -r '.Log2ram.Compalg' $LBHOMEDIR/config/system/general.json`
	LOG_DISK_SIZE=`jq -r '.Log2ram.Logdisksize' $LBHOMEDIR/config/system/general.json`
fi

createFolders () {
	echo "Creating folders in $RAM_LOG..."
	if [ $RAM_LOG ]; then
		rm -rf $RAM_LOG/*
	fi
	if [ ! -e /boot/dietpi/.hw_model ]; then # Only legacy / pure old Raspbian Image
		mkdir -p $RAM_LOG/var/log
		chown -R root:root $RAM_LOG/var/log
		chmod -R 755 $RAM_LOG/var/log
		mkdir -p $RAM_LOG/tmp
		chown -R root:root $RAM_LOG/tmp
		chmod -R 777 $RAM_LOG/tmp
		mkdir -p $RAM_LOG/var/tmp
		chown -R root:root $RAM_LOG/var/tmp
		chmod -R 777 $RAM_LOG/var/tmp
	fi
	mkdir -p $RAM_LOG/log/plugins
	chown -R loxberry:loxberry $RAM_LOG/log/plugins
	chmod -R 755 $RAM_LOG/log/plugins
	mkdir -p $RAM_LOG/log/system_tmpfs
	chown -R loxberry:loxberry $RAM_LOG/log/system_tmpfs
	chmod -R 755 $RAM_LOG/log/system_tmpfs

	echo "Binding systemfolders to temporary folders in $RAM_LOG..."
	if [ ! -e /boot/dietpi/.hw_model ]; then # Only legacy / pure old Raspbian Image
		cp -ra /var/log/* $RAM_LOG/var/log
		rm -rf /var/log/*
		mount --bind $RAM_LOG/var/log /var/log
		mount --bind $RAM_LOG/tmp /tmp
		mount --bind $RAM_LOG/var/tmp /var/tmp
	fi
	mount --bind $RAM_LOG/log/plugins $LBHOMEDIR/log/plugins
	mount --bind $RAM_LOG/log/system_tmpfs $LBHOMEDIR/log/system_tmpfs
}

createZramLogDrive () {
	# Check Zram Class created
	if [ ! -d "/sys/class/zram-control" ]; then
		modprobe zram
		RAM_DEV='0'
	else
		RAM_DEV=$(cat /sys/class/zram-control/hot_add)
	fi
	echo ${COMP_ALG} > /sys/block/zram${RAM_DEV}/comp_algorithm
	echo ${LOG_DISK_SIZE} > /sys/block/zram${RAM_DEV}/disksize
	echo ${SIZE} > /sys/block/zram${RAM_DEV}/mem_limit
	mke2fs -t ext4 /dev/zram${RAM_DEV} > /dev/null 2>&1
}

wait_for () {
	i=0
	while ! grep -qs "$1" /proc/mounts; do
		echo "Waiting for $1 coming up..."
		sleep 0.1
		((i++))
		if [[ "$i" == '50' ]]; then
			break
		fi
	done
}

case "$1" in

start)

	# No tmpfs on Virtual Machines and natice PCs
	if  [ "$G_HW_MODEL" = '20' ] || [ "$G_HW_MODEL" = '21' ]; then
		echo "This is a virtual machine or PC - no tmpfs needed."
		# Create log folders for all plugins if not existing
		echo "Create log folders for all installed plugins"
		perl $LBHOMEDIR/sbin/createpluginfolders.pl > /dev/null 2>&1
		exit 0
	fi

	if [ ! -d $RAM_LOG ]; then
		mkdir -p ${RAM_LOG}
	fi

	if [ "$ZL2R" = true ]; then
		createZramLogDrive
		mount -t ext4 -o nosuid,nodev,user=log2ram /dev/zram${RAM_DEV} ${RAM_LOG}/
	else
		mount -t tmpfs -o nosuid,nodev,mode=0755,size=${SIZE} log2ram ${RAM_LOG}/
	fi

	wait_for $RAM_LOG

	echo "Creating temporary system folders..."
	createFolders

	echo "Restoring Syslog and LoxBerry system log folders..."
	if [ ! -e /boot/dietpi/.hw_model ]; then # Only legacy / pure old Raspbian Image
		cp -ra $LBHOMEDIR/log/skel_syslog/* /var/log
		cp -ra $LBHOMEDIR/log/skel_system/* $LBHOMEDIR/log/system_tmpfs

		echo "Restoring DHCP leases..."
		if ls $LBHOMEDIR/system/dhcp/*.leases 2>/dev/null 1>&2; then
			cp -a $LBHOMEDIR/system/dhcp/*.leases /var/lib/dhcp/
		fi
	else
		# For compatibility create Symlink for Apache logs
		ln -s /var/log/apache2 $LBHOMEDIR/log/system_tmpfs/apache2
	fi

	# Copy logdb from SD card to RAM disk
	if [ -e $LBHOMEDIR/log/system/logs_sqlite.dat.bkp ]; then
	        echo "Copy back Backup of Logs SQLite Database..."
		cp -f $LBHOMEDIR/log/system/logs_sqlite.dat.bkp $LBHOMEDIR/log/system_tmpfs/logs_sqlite.dat
		chown loxberry:loxberry $LBHOMEDIR/log/system_tmpfs/logs_sqlite.dat
		chmod +rw $LBHOMEDIR/log/system_tmpfs/logs_sqlite.dat
	fi
	
	# Copy CloudDNS cache from SD card to RAM disk
	if [ -e $LBHOMEDIR/log/system/clouddns_cache.bkp ]; then
	        echo "Copy back CloudDNS cache"
		cp -f $LBHOMEDIR/log/system/clouddns_cache.bkp $LBHOMEDIR/log/system_tmpfs/clouddns_cache.json
		chown loxberry:loxberry $LBHOMEDIR/log/system_tmpfs/clouddns_cache.json
		chmod +rw $LBHOMEDIR/log/system_tmpfs/clouddns_cache.json
	fi

	# Create log folders for all plugins if not existing
	echo "Create log folders for all installed plugins"
	perl $LBHOMEDIR/sbin/createpluginfolders.pl > /dev/null 2>&1

	exit 0
;;

stop)

	# No tmpfs on Virtual Machines
	if  [ "$G_HW_MODEL" = '20' ] || [ "$G_HW_MODEL" = '21' ]; then
		echo "This is a virtual machine or PC - no tmpfs needed. Good Bye."
		exit 0
	fi

	# Skel for system logs, LB system logs and LB plugin logs
	echo "Backing up Syslog and LoxBerry system log folders..."
	if [ -d $LBHOMEDIR/log/skel_system/ ]; then
		cp -ra $LBHOMEDIR/log/system_tmpfs/* $LBHOMEDIR/log/skel_system/
		find $LBHOMEDIR/log/skel_system/ -type f -exec rm {} \;
	fi
	if [ ! -e /boot/dietpi/.hw_model ]; then # Only legacy / pure old Raspbian Image
		if [ -d $LBHOMEDIR/log/skel_syslog/ ]; then
			cp -ra /var/log/* $LBHOMEDIR/log/skel_syslog/
			find $LBHOMEDIR/log/skel_syslog/ -type f -exec rm {} \;
		fi
		echo "Backing up DCHP leases..."
		if [ ! -d $LBHOMEDIR/system/dhcp ]; then
			mkdir $LBHOMEDIR/system/dhcp
		fi
		if ls /var/lib/dhcp/*.leases 2>/dev/null 1>&2; then
			cp -a /var/lib/dhcp/*.leases $LBHOMEDIR/system/dhcp/
		fi
	fi

	# Copy logdb from RAM disk to SD card
	if [ -e $LBHOMEDIR/log/system_tmpfs/logs_sqlite.dat ]; then
		echo "VACUUM;" | sqlite3 $LBHOMEDIR/log/system_tmpfs/logs_sqlite.dat
		sqlite3 $LBHOMEDIR/log/system_tmpfs/logs_sqlite.dat ".backup '$LBHOMEDIR/log/system/logs_sqlite.dat.bkp'"
	fi
	
	if [ -e /run/shm/clouddns_cache.json ]; then
        	echo "Backup CloudDNS cache to SD..."
		cp -f $LBHOMEDIR/log/system_tmpfs/clouddns_cache.json $LBHOMEDIR/log/system/clouddns_cache.bkp
	fi
	
	exit 0
;;
  
*)

        echo "Usage: $0 [start|stop]" >&2
        exit 3

;;
esac
