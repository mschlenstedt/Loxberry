#!/bin/sh
### BEGIN INIT INFO
# Provides:          createtmpfsfolder
# Required-Start:    console-setup
# Required-Stop:     
# Default-Start:     2 3 4 5
# Default-Stop:      
# Short-Description: create log folders on tmpfs after mountall
# Description:       This file creates needed folders in syslog and
#                    loxberry system log folders.
### END INIT INFO

PATH="/sbin:/bin:/usr/sbin:/usr/bin:/opt/loxberry/bin:/opt/loxberry/sbin"

. /lib/lsb/init-functions
ENVIRONMENT=$(cat /etc/environment)
export $ENVIRONMENT

case "$1" in
  start|"")
	cp -ra /opt/loxberry/log/skel_syslog/* /var/log
	cp -ra /opt/loxberry/log/skel_system/* /opt/loxberry/log/system_tmpfs
        exit 0
	;;
  restart|reload|force-reload)
        echo "Error: argument '$1' not supported" >&2
        exit 3
        ;;
  stop|status)
        # No-op
        ;;
  *)
        echo "Usage: $0 [start|stop]" >&2
        exit 3
        ;;
esac

:

