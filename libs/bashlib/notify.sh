#!/bin/bash

notify_ext() {

	WEBSERVERPORT=$(jq -r '.Webserver.Port' $LBSCONFIG/general.json)
	
	# echo "Webserver port is $WEBSERVERPORT";
	
	curl -v -H "Content-Type: application/x-www-form-urlencoded" http://localhost:$WEBSERVERPORT/admin/system/ajax/ajax-notification-handler.cgi -d "action=notifyext&$1&$2&$3&$4&$5&$6&$7&$8&$9"
	
}

notify() {

	WEBSERVERPORT=$(jq -r '.Webserver.Port' $LBSCONFIG/general.json)
	
	errorparam=$4
	
	if [ -n "$errorparam" ]; then severity="3"; else severity="6"; fi
	
	# echo "Webserver port is $WEBSERVERPORT";
	
	curl -v -H "Content-Type: application/x-www-form-urlencoded" http://localhost:$WEBSERVERPORT/admin/system/ajax/ajax-notification-handler.cgi -d "action=notifyext&PACKAGE=$1&NAME=$2&MESSAGE=$3&SEVERITY=$severity"
	
}

