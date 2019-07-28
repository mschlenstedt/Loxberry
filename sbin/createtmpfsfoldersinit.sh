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

case "$1" in
  start|"")

	log_action_begin_msg "Creating temporary system folders..."
        if [ -d /dev/shm ]
        then

		log_action_cont_msg "Creating folders in /dev/shm..."
		mkdir -p /dev/shm/loxberry/var/log
		chown -R daemon:daemon /dev/shm/loxberry/var/log
		chmod -R 755 /dev/shm/loxberry/var/log
		mkdir -p /dev/shm/loxberry/tmp
		chown -R root:root /dev/shm/loxberry/tmp
		chmod -R 777 /dev/shm/loxberry/tmp
		mkdir -p /dev/shm/loxberry/var/tmp
		chown -R root:root /dev/shm/loxberry/var/tmp
		chmod -R 777 /dev/shm/loxberry/var/tmp
		mkdir -p /dev/shm/loxberry/log/plugins
		chown -R loxberry:loxberry /dev/shm/loxberry/log/plugins
		chmod -R 755 /dev/shm/loxberry/log/plugins
		mkdir -p /dev/shm/loxberry/log/system_tmpfs
		chown -R loxberry:loxberry /dev/shm/loxberry/log/system_tmpfs
		chmod -R 755 /dev/shm/loxberry/log/system_tmpfs

		log_action_cont_msg "Binding systemfolders to temporary folders in /dev/shm..."
		cp -ra /var/log/* /dev/shm/loxberry/var/log
		rm -rf /var/log/* 
		mount --bind /dev/shm/loxberry/var/log /var/log
		mount --bind /dev/shm/loxberry/tmp /tmp
		mount --bind /dev/shm/loxberry/var/tmp /var/tmp
		mount --bind /dev/shm/loxberry/log/plugins $LBHOMEDIR/log/plugins
		mount --bind /dev/shm/loxberry/log/system_tmpfs $LBHOMEDIR/log/system_tmpfs

	else

		log_action_cont_msg "Creating folders in /tmp... (Fallback, because /dev/shm seems not to exist)"
		mkdir -p /tmp/loxberry/var/log
		chown -R daemon:daemon /tmp/loxberry/var/log
		chmod -R 755 /tmp/loxberry/var/log
		mkdir -p /tmp/loxberry/log/plugins
		chown -R loxberry:loxberry /tmp/loxberry/log/plugins
		chmod -R 755 /tmp/loxberry/log/plugins
		mkdir -p /tmp/loxberry/log/system_tmpfs
		chown -R loxberry:loxberry /tmp/loxberry/log/system_tmpfs
		chmod -R 755 /tmp/loxberry/log/system_tmpfs

		log_action_cont_msg "Binding systemfolders to temporary folders in /tmp..."
		cp -ra /var/log/* /tmp/loxberry/var/log
		rm -rf /var/log/* 
		mount --bind /tmp/loxberry/var/log /var/log
		mount --bind /tmp/loxberry/log/plugins $LBHOMEDIR/log/plugins
		mount --bind /tmp/loxberry/log/system_tmpfs $LBHOMEDIR/log/system_tmpfs
	fi
	log_action_end_msg 0

	log_action_begin_msg "Restoring Syslog and LoxBerry system log folders..."
	cp -ra /opt/loxberry/log/skel_syslog/* /var/log
	cp -ra /opt/loxberry/log/skel_system/* /opt/loxberry/log/system_tmpfs
	log_action_end_msg 0

	# Copy logdb from SD card to RAM disk
	if [ -e $LBHOMEDIR/log/system/logs_sqlite.dat.bkp ]
	then
        log_action_begin_msg "Copy back Backup of Logs SQLite Database"
		cp -f $LBHOMEDIR/log/system/logs_sqlite.dat.bkp $LBHOMEDIR/log/system_tmpfs/logs_sqlite.dat
		chown loxberry:loxberry $LBHOMEDIR/log/system_tmpfs/logs_sqlite.dat
		chmod +rw $LBHOMEDIR/log/system_tmpfs/logs_sqlite.dat
		log_action_end_msg 0
	fi
	
	# Copy CloudDNS cache from SD card to RAM disk
	if [ -e $LBHOMEDIR/data/system/clouddns_cache.bkp ]
	then
        log_action_begin_msg "Copy back CloudDNS cache"
		cp -f $LBHOMEDIR/data/system/clouddns_cache.bkp /run/shm/clouddns_cache.json
		chown loxberry:loxberry /run/shm/clouddns_cache.json
		chmod +rw /run/shm/clouddns_cache.json
		log_action_end_msg 0
	fi
		
    exit 0
	;;

  restart|reload|force-reload)
	echo "Error: argument '$1' not supported" >&2
    exit 3
    ;;

  stop)
	# Copy logdb from RAM disk to SD card
	if [ -e $LBHOMEDIR/log/system_tmpfs/logs_sqlite.dat ]
	then
		echo "VACUUM;" | sqlite3 $LBHOMEDIR/log/system_tmpfs/logs_sqlite.dat
		sqlite3 $LBHOMEDIR/log/system_tmpfs/logs_sqlite.dat ".backup '$LBHOMEDIR/log/system/logs_sqlite.dat.bkp'"
		# cp -f $LBHOMEDIR/log/system_tmpfs/logs_sqlite.dat $LBHOMEDIR/log/system/logs_sqlite.dat.bkp
	fi
	
	if [ -e /run/shm/clouddns_cache.json ]
	then
        log_action_begin_msg "Backup CloudDNS cache to SD"
		cp -f /run/shm/clouddns_cache.json $LBHOMEDIR/data/system/clouddns_cache.bkp
		log_action_end_msg 0
	fi
	
	
	exit 0
	;;
  
  status)
        # No-op
        exit 0
        ;;

  *)
        echo "Usage: $0 [start|stop]" >&2
        exit 3
        ;;
esac
