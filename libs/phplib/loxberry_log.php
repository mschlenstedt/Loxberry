<?php

require_once "loxberry_system.php";
// require_once "phphtmltemplate_loxberry/template040.php";

class LBLog
{
	public static $VERSION = "0.3.3.1";
	public static $notification_dir = LBSDATADIR . "/notifications";

	function get_notifications ($package = NULL, $name = NULL, $latest = NULL, $count = NULL, $getcontent = NULL)
	{
		error_log("get_notifications called.\n");
		
		
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
	// error_log "Notifdir: " . LBLog::$notification_dir . "\n";
	if (! $package || ! $name || ! $message) {
		error_log("Notification: Missing parameters\n");
		return;
	}
	$package = str_replace('_', '', trim(strtolower($package)));
	$name = str_replace('_', '', trim(strtolower($name)));
	
	if ($error) {
		$error = '_err';
	} else { 
		$error = "";
	}
	
	$filename = LBLog::$notification_dir . "/" . currtime('file') . "_{$package}_{$name}{$error}.system";
	$fh = fopen($filename, "w") or trigger_error("Could not create a notification at '{$filename}': $!", E_USER_WARNING);
	fwrite($fh, $message);
	fclose($fh);
	chown ($filename, 'loxberry');
}



?>
