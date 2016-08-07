#!/bin/sh
### BEGIN INIT INFO
# Provides:          loxberry
# Required-Start:    $remote_fs $syslog $network 
# Required-Stop:     $remote_fs $syslog $network
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

PATH="/sbin:/bin:/usr/sbin:/usr/bin:/opt/loxberry/bin:/opt/loxberry/sbin"

. /lib/lsb/init-functions

case "$1" in
  start|"")

        # Resize rootfs to maximum if not yet done
        if [ ! -f /boot/rootfsresized ]
        then
		log_action_begin_msg "Resizing Rootfs to maximum on next reboot"
                /opt/loxberry/sbin/resize_rootfs > /dev/null 2>&1
                touch /boot/rootfsresized
        fi

        # Copy manual network configuration if any exists
        if [ -f /boot/network.txt ]
        then
		log_action_begin_msg "Found manual network configuration in /boot. Activating..."
                mv /opt/loxberry/system/network/interfaces  /opt/loxberry/system/network/interfaces.bkp > /dev/null 2>&1
                cp /boot/network.txt  /opt/loxberry/system/network/interfaces > /dev/null 2>&1
                dos2unix /etc/network/interfaces > /dev/null 2>&1
                mv /boot/network.txt /boot/network.bkp > /dev/null 2>&1
		/etc/init.d/networking restart > /dev/null 2>&1
        fi

        # Do a system upgrade
        if [ -f /opt/loxberry/data/system/upgrade/upgrade.sh ]
        then
		log_action_begin_msg "Found system upgrade. Installing..."
		/opt/loxberry/data/system/upgrade/upgrade.sh > /opt/loxberry/data/system/upgrade/upgrade.log 2>&1
        fi

        # Cleaning Temporary folders
	log_action_begin_msg "Cleaning temporary files and folders..."
        rm -rf /opt/loxberry/webfrontend/html/tmp/* > /dev/null 2>&1

        # Set Date and Time
        if [ -f /opt/loxberry/sbin/setdatetime.pl ]
	  log_action_begin_msg "Syncing Date/Time with Miniserver or NTP-Server"
          /opt/loxberry/sbin/setdatetime.pl > /dev/null 2>&1
        fi

        # Run Daemons from Plugins and from System
	log_action_begin_msg "Running System Daemons"
        run-parts /opt/loxberry/system/daemons/system > /dev/null 2>&1

	log_action_begin_msg "Running Plugin Daemons"
        run-parts /opt/loxberry/system/daemons/plugins > /dev/null 2>&1

        ;;

  restart|reload|force-reload|status)
        echo "Error: argument '$1' not supported" >&2
        exit 3

        ;;

  stop)

        # No-op

        ;;

  *)

        echo "Usage: loxberry [start|stop]" >&2
        exit 3

        ;;

esac
