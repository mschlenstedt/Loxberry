#!/bin/bash

# Check tmpfs if there's enough space for caching
TMPFSSTATE=`$LBSSBIN/healthcheck.pl check=check_tmpfssize output=json | jq -r '.[].status'`
if [ $TMPFSSTATE != "5" ]; then
	echo "Problem with tmpfs. Disable Template cache."
	touch /tmp/no_template_cache
	if [ ! -e "/tmp/no_template_cache" ]; then 
		touch $LBSLOG/no_template_cache
	fi
else
	rm -f /tmp/no_template_cache
	rm -f $LBSLOG/no_template_cache
fi

# Check if Apache is running
EMERGENCY=0
APACHESYSSTATE=`sudo systemctl status apache2 > /dev/null 2>&1`
if [ "$?" != "0" ]; then
	EMERGENCY=1
fi

APACHESTATE=`pgrep apache2 > /dev/null 2>&1`
if [ "$?" != "0" ]; then
	EMERGENCY=1
fi

CURLSTATE=`curl -i http://localhost/admin/system/index.cgi > /dev/null 2>&1`
if [ "$?" != "0" ]; then
	EMERGENCY=1
fi

if [ $EMERGENCY = 1 ]; then
	echo "Problem with Apache. Disable Apache and start Emergency Webserver (sleeping for 60s to free webserver port)."
	sudo systemctl stop apache2 > /dev/null 2>&1
	sudo systemctl kill apache2 > /dev/null 2>&1
	sleep 60
	PORT=`jq -r '.Webserver.Port' $LBSCONFIG/general.json`
	$LBSSBIN/emergencywebserver.pl $PORT > /dev/null 2>&1 &
fi
