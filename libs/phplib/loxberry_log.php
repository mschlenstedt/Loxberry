<?php

require_once "loxberry_system.php";
// require_once "phphtmltemplate_loxberry/template040.php";

class LBLog
{
	public static $VERSION = "1.0.0.3";
	
	function get_notifications ($package = NULL, $name = NULL)
	{
		// error_log("get_notifications called.\n");
		
		global $lbpplugindir;

		$NOTIFHANDLERURL = "http://localhost:" . lbwebserverport() . "/admin/system/tools/ajax-notification-handler.cgi";	
	
		$fields = array(
			'action' => 'get_notifications',
		);

		if (isset($package)) { $fields['package'] = $package; }
		if (isset($name)) { $fields['name'] = $name; }
		
		$options = array(
			'http' => array(
				'header'  => "Content-type: application/x-www-form-urlencoded\r\n",
				'method'  => 'POST',
				'content' => http_build_query($fields)
				)
		);
		$context  = stream_context_create($options);
		$result = file_get_contents($NOTIFHANDLERURL, false, $context);
		if ($result === FALSE) { 
			error_log("get_notifications_html: Could not get notifications"); 
			return;
		}
		
		$jsonresult = json_decode($result, true);
		# var_dump($jsonresult);
		
		return ($jsonresult);
	
	}
	
		
	
	
	// get_notifications_html
	function get_notifications_html ($package = NULL, $name = NULL, $type = NULL, $buttons = NULL)
	{
		error_log("get_notifications_html called.\n");
		
		global $lbpplugindir;

		$NOTIFHANDLERURL = "http://localhost:" . lbwebserverport() . "/admin/system/tools/ajax-notification-handler.cgi";	
	
		$fields = array(
			'action' => 'get_notifications_html',
			'package' => "$package", 
			'name' => "$name",
			'type' => "$type",
			'buttons' => "$buttons"
		);
		
		$options = array(
			'http' => array(
				'header'  => "Content-type: application/x-www-form-urlencoded\r\n",
				'method'  => 'POST',
				'content' => http_build_query($fields)
				)
		);
		$context  = stream_context_create($options);
		$result = file_get_contents($NOTIFHANDLERURL, false, $context);
		if ($result === FALSE) { 
			error_log("get_notifications_html: Could not get notifications"); 
			return;
		}
		
		return $result;
	
	}
	
}

# End of class LBLog

##################################
# MAIN
# Functions in the main namespace
##################################

##################################
# notify
function notify ($package, $name, $message, $error = false)
{
	global $lbpplugindir;

	$NOTIFHANDLERURL = "http://localhost:" . lbwebserverport() . "/admin/system/tools/ajax-notification-handler.cgi";	
	// error_log "Notifdir: " . LBLog::$notification_dir . "\n";
	if (! $package || ! $name || ! $message) {
		error_log("Notification: Missing parameters\n");
		return;
	}
	
	if ($error == True) {
		$severity = 3;
	} else {
		$severity = 6;
	}
	
	$fields = array(
		'action' => 'notifyext',
		'PACKAGE' => $package, 
		'NAME' => $name,
		'MESSAGE' => $message,
		'SEVERITY' => $severity,
	);
	
	if (isset($lbpplugindir)) {
		$fields['_ISPLUGIN'] = 1;
	} else {
		$fields['_ISSYSTEM'] = 1;
	}
	
	$options = array(
		'http' => array(
			'header'  => "Content-type: application/x-www-form-urlencoded\r\n",
			'method'  => 'POST',
			'content' => http_build_query($fields)
			)
	);
	$context  = stream_context_create($options);
	$result = file_get_contents($NOTIFHANDLERURL, false, $context);
	if ($result === FALSE) { /* Handle error */ }
	
}

function notify_ext ($fields)
{
	global $lbpplugindir;

	$NOTIFHANDLERURL = "http://localhost:" . lbwebserverport() . "/admin/system/tools/ajax-notification-handler.cgi";	
	// error_log "Notifdir: " . LBLog::$notification_dir . "\n";
	if ( ! isset($fields['PACKAGE']) || ! isset($fields['NAME']) || ! isset($fields['MESSAGE']) ) {
		error_log("Notification: Missing parameters\n");
		return;
	}
	
	if ( ! isset($fields['SEVERITY']) ) {
		$severity = 6;
	}
	
	$fields['action'] = "notifyext";
		
	if (isset($lbpplugindir)) {
		$fields['_ISPLUGIN'] = 1;
	} else {
		$fields['_ISSYSTEM'] = 1;
	}
	
	$options = array(
		'http' => array(
			'header'  => "Content-type: application/x-www-form-urlencoded\r\n",
			'method'  => 'POST',
			'content' => http_build_query($fields)
			)
	);
	$context  = stream_context_create($options);
	$result = file_get_contents($NOTIFHANDLERURL, false, $context);
	if ($result === FALSE) { /* Handle error */ }
	
}
