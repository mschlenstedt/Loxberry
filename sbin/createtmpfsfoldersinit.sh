#!/bin/sh
### BEGIN INIT INFO
# Provides:          createtmpfsfolder
# Required-Start:    
# Required-Stop:     
# Default-Start:     2 3 4 5
# Default-Stop:      
# X-Start-Before:    nmbd smbd samba-ad-dc bootlogs apache2 lighttpd
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
		#mkdir -p /tmp/loxberry/tmp
		#chown -R root:root /tmp/loxberry/tmp
		#chmod -R 777 /tmp/loxberry/tmp
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
		mount --bind /tmp/loxberry/tmp /tmp
		mount --bind /tmp/loxberry/log/plugins $LBHOMEDIR/log/plugins
		mount --bind /tmp/loxberry/log/system_tmpfs $LBHOMEDIR/log/system_tmpfs
	fi
	log_action_end_msg 0

	log_action_begin_msg "Restoring Syslog and LoxBerr system log folders..."
	cp -ra /opt/loxberry/log/skel_syslog/* /var/log
	cp -ra /opt/loxberry/log/skel_system/* /opt/loxberry/log/system_tmpfs
	log_action_end_msg 0

        exit 0
	;;

  restart|reload|force-reload)
        echo "Error: argument '$1' not supported" >&2
        exit 3
        ;;

  stop|status)
        # No-op
        exit 0
        ;;

  *)
        echo "Usage: $0 [start|stop]" >&2
        exit 3
        ;;
esac
