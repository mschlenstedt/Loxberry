<?php

require_once "loxberry_system.php";
// require_once "phphtmltemplate_loxberry/template040.php";

class LBLog
{
	public static $VERSION = "0.3.3.1";
	private static $notification_dir = LBSDATADIR . "/notifications";
	
	function get_notifications ($package = NULL, $name = NULL, $latest = NULL, $count = NULL, $getcontent = NULL)
	{
		error_log("get_notifications called.\n");
		
		
	}

	
	public function notify ($package, $name, $message, $error = false)
	{
		// echo "Notifdir: " . self::$notification_dir . "\n";
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
		
		// my ($login,$pass,$uid,$gid) = getpwnam('loxberry');
		$filename = self::$notification_dir . "/" . currtime('file') . "_{$package}_{$name}{$error}.system";
		# open(my $fh, '>', $filename) or warn "Could not create a notification at '$filename' $!";
		$fh = fopen($filename, "w") or trigger_error("Could not create a notification at '{$filename}': $!", E_USER_WARNING);
		# flock($fh,2);
		#print $fh $message;
		fwrite($fh, $message);
		#flock($fh,8);
		#close $fh;
		fclose($fh);
		chown ($filename, 'loxberry');
	}

	
	
	
	
	
}


?>
