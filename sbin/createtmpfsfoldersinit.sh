#!/bin/sh
### BEGIN INIT INFO
# Provides:          createtmpfsfolder
# Required-Start:    $local_fs
# Required-Stop:     
# Default-Start:     2 3 4 5
# Default-Stop:      
# X-Start-Before:    cron nmbd smbd samba-ad-dc bootlogs apache2 lighttpd
# Short-Description: create log folders on tmpfs after mountall
# Description:       This file creates needed folders in syslog and
#                    loxberry system log folders.
### END INIT INFO


. /lib/lsb/init-functions
ENVIRONMENT=$(cat /etc/environment)
export $ENVIRONMENT

PATH="/sbin:/bin:/usr/sbin:/usr/bin:/opt/loxberry/bin:/opt/loxberry/sbin:$LBHOMEDOR/bin:$LBHOMEDIR/sbin"
PIVERS=`$LBHOMEDIR/bin/showpitype`
MANUALCFG=`jq -r '.Log2ram.Manualconfigured' $LBHOMEDIR/config/system/general.json`

if [ ! "$MANUALCFG" ] || [ "$MANUALCFG" = 'null' ]; then
	echo "No manual config found. Using defaults..."
	RAM_LOG=$LBHOMEDIR/log/ramlog
	if [ "$PIVERS" = 'type_0' ] || [ "$PIVERS" = 'type_1' ]; then
		SIZE=50M
		ZL2R=false
		COMP_ALG=lz4
		LOG_DISK_SIZE=50M
	else
		SIZE=120M
		ZL2R=true
		COMP_ALG=lz4
		LOG_DISK_SIZE=250M
	fi
	JSON=`jq ".Ram2Log.Manualconfigured = \"0\"" $LBHOMEDIR/config/system/general.json`
	JSON=`echo $JSON | jq ".Ram2Log.Ramlog = \"$RAM_LOG\""`
	JSON=`echo $JSON | jq ".Ram2Log.Size = \"$SIZE\""`
	JSON=`echo $JSON | jq ".Ram2Log.Zl2r = \"$ZL2R\""`
	JSON=`echo $JSON | jq ".Ram2Log.Compalg = \"$COMP_ALG\""`
	JSON=`echo $JSON | jq ".Ram2Log.Logdisksize = \"$LOG_DISK_SIZE\""`
	echo $JSON | jq "." > $LBHOMEDIR/config/system/general.json.new
	mv $LBHOMEDIR/config/system/general.json.new $LBHOMEDIR/config/system/general.json
else
	echo "Using config from $LBHOMEDIR/config/system/general.json..."
	RAM_LOG=`jq -r '.Log2ram.Ramlog' $LBHOMEDIR/config/system/general.json`
	SIZE=`jq -r '.Log2ram.Size' $LBHOMEDIR/config/system/general.json`
	ZL2R=`jq -r '.Log2ram.Zl2r' $LBHOMEDIR/config/system/general.json`
	COMP_ALG=`jq -r '.Log2ram.Compalg' $LBHOMEDIR/config/system/general.json`
	LOG_DISK_SIZE=`jq -r '.Log2ram.Logdisksize' $LBHOMEDIR/config/system/general.json`
fi

createFolders () {
	log_action_cont_msg "Creating folders in $RAM_LOG..."
	if [ $RAM_LOG ]; then
		rm -rf $RAM_LOG/*
	fi
	mkdir -p $RAM_LOG/var/log
	chown -R daemon:daemon $RAM_LOG/var/log
	chmod -R 755 $RAM_LOG/var/log
	mkdir -p $RAM_LOG/tmp
	chown -R root:root $RAM_LOG/tmp
	chmod -R 777 $RAM_LOG/tmp
	mkdir -p $RAM_LOG/var/tmp
	chown -R root:root $RAM_LOG/var/tmp
	chmod -R 777 $RAM_LOG/var/tmp
	mkdir -p $RAM_LOG/log/plugins
	chown -R loxberry:loxberry $RAM_LOG/log/plugins
	chmod -R 755 $RAM_LOG/log/plugins
	mkdir -p $RAM_LOG/log/system_tmpfs
	chown -R loxberry:loxberry $RAM_LOG/log/system_tmpfs
	chmod -R 755 $RAM_LOG/log/system_tmpfs

	log_action_cont_msg "Binding systemfolders to temporary folders in $RAM_LOG..."
	cp -ra /var/log/* $RAM_LOG/var/log
	rm -rf /var/log/*
	mount --bind $RAM_LOG/var/log /var/log
	mount --bind $RAM_LOG/tmp /tmp
	mount --bind $RAM_LOG/var/tmp /var/tmp
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

start|"")

	if [ ! -d $RAM_LOG ]; then
		mkdir -p ${RAM_LOG}
	fi

	if [ "$ZL2R" = true ]; then
		createZramLogDrive
		mount -t ext4 -o nosuid,noexec,nodev,user=log2ram /dev/zram${RAM_DEV} ${RAM_LOG}/
	else
		mount -t tmpfs -o nosuid,noexec,nodev,mode=0755,size=${SIZE} log2ram ${RAM_LOG}/
	fi

	wait_for $RAM_LOG

	log_action_begin_msg "Creating temporary system folders..."
	createFolders
	log_action_end_msg 0

	log_action_begin_msg "Restoring Syslog and LoxBerry system log folders..."
	cp -ra $LBHOMEDIR/log/skel_syslog/* /var/log
	cp -ra $LBHOMEDIR/log/skel_system/* $LBHOMEDIR/log/system_tmpfs
	log_action_end_msg 0

	# Copy logdb from SD card to RAM disk
	if [ -e $LBHOMEDIR/log/system/logs_sqlite.dat.bkp ]; then
	        log_action_begin_msg "Copy back Backup of Logs SQLite Database"
		cp -f $LBHOMEDIR/log/system/logs_sqlite.dat.bkp $LBHOMEDIR/log/system_tmpfs/logs_sqlite.dat
		chown loxberry:loxberry $LBHOMEDIR/log/system_tmpfs/logs_sqlite.dat
		chmod +rw $LBHOMEDIR/log/system_tmpfs/logs_sqlite.dat
		log_action_end_msg 0
	fi
	
	# Copy CloudDNS cache from SD card to RAM disk
	if [ -e $LBHOMEDIR/log/system/clouddns_cache.bkp ]; then
	        log_action_begin_msg "Copy back CloudDNS cache"
		cp -f $LBHOMEDIR/log/system/clouddns_cache.bkp $LBHOMEDIR/log/system_tmpfs/clouddns_cache.json
		chown loxberry:loxberry $LBHOMEDIR/log/system_tmpfs/clouddns_cache.json
		chmod +rw $LBHOMEDIR/log/system_tmpfs/clouddns_cache.json
		log_action_end_msg 0
	fi

	exit 0

;;

stop)

	# Copy logdb from RAM disk to SD card
	if [ -e $LBHOMEDIR/log/system_tmpfs/logs_sqlite.dat ]; then
		echo "VACUUM;" | sqlite3 $LBHOMEDIR/log/system_tmpfs/logs_sqlite.dat
		sqlite3 $LBHOMEDIR/log/system_tmpfs/logs_sqlite.dat ".backup '$LBHOMEDIR/log/system/logs_sqlite.dat.bkp'"
		# cp -f $LBHOMEDIR/log/system_tmpfs/logs_sqlite.dat $LBHOMEDIR/log/system/logs_sqlite.dat.bkp
	fi
	
	if [ -e /run/shm/clouddns_cache.json ]; then
        	log_action_begin_msg "Backup CloudDNS cache to SD"
		cp -f $LBHOMEDIR/log/system_tmpfs/clouddns_cache.json $LBHOMEDIR/log/system/clouddns_cache.bkp
		log_action_end_msg 0
	fi
	
	exit 0
;;
  
*)

        echo "Usage: $0 [start|stop]" >&2
        exit 3

;;
esac
