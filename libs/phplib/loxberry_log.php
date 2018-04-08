<?php

require_once "loxberry_system.php";
// require_once "phphtmltemplate_loxberry/template040.php";

class intLog
{
	private $params;
	
	public function __construct($args)
	{
		global $lbpplugindir;
		$this->params = $args;
		if (!isset($this->params["package"])) {$this->params["package"] = $lbpplugindir;}
	}
	
	public function __get($name)
	{
		if (isset($this->params[$name]))
		{
			return $this->params[$name];
		} else {
			return NULL;
		}
	}
	public function __set($name, $value)
  {
    // ignore, Variables are read-only
  }
	
	public function startlog($msg)
	{
		//initializing the log an printout the start message
		global $lbhomedir;
		$cmdparams="";
		if (isset($this->params["package"]) && isset($this->params["name"]) && (isset($this->params["filename"]) || isset($this->params["logdir"]) || isset($this->params["nofile"])))
		{
			if (isset($this->params["stderr"])) {$cmdparams=" --stderr";}
			if (isset($this->params["append"])) {$cmdparams=" --append";}
			if (isset($this->params["nofile"]))
			{
				$cmdparams .= " --nofile";
			} else {
				if (isset($this->params["filename"])) {$cmdparams .= " --filename=" . $this->params["filename"];}
				if (isset($this->params["logdir"])) {$cmdparams .= " --logdir=" . $this->params["logdir"];}
			}
			$log=exec($lbhomedir . '/libs/bashlib/initlog.pl --name='.$this->params["name"].' --package='.$this->params["package"].$cmdparams.' "--message='.$msg.'"');
			if ($log == "")
			{
				echo "initlog returns a empty string.";
				return false;
			}
			$log=str_getcsv($log," ");
			$this->params["filename"] = $log[0];
			if ( ! isset($this->params["loglevel"])) {$this->params["loglevel"] = $log[1];}
		} else {
			echo "not enough parameters given.\n";
		}
	}
	
	public function logdeb($msg)
	{
		if ($this->loglevel > 6)
		{
	  	if (isset($this->params["addtime"])) {$currtime=date("H:i:s ");} else {$currtime="";}
			$this->writelog("<DEBUG> $currtime$msg");
		}
	}

	public function loginf($msg)
	{
		if ($this->loglevel > 5)
		{
	  	if (isset($this->params["addtime"])) {$currtime=date("H:i:s ");} else {$currtime="";}
			$this->writelog("<INFO> $currtime$msg");
		}
	}

	public function logok($msg)
	{
		if ($this->loglevel > 4)
		{
	  	if (isset($this->params["addtime"])) {$currtime=date("H:i:s ");} else {$currtime="";}
			$this->writelog("<OK> $currtime$msg");
		}
	}

	public function logwarn($msg)
	{
		if ($this->loglevel > 3)
		{
	  	if (isset($this->params["addtime"])) {$currtime=date("H:i:s ");} else {$currtime="";}
			$this->writelog("<WARNING> $currtime$msg");
		}
	}

	public function logerr($msg)
	{
		if ($this->loglevel > 2)
		{
	  	if (isset($this->params["addtime"])) {$currtime=date("H:i:s ");} else {$currtime="";}
			$this->writelog("<ERROR> $currtime$msg");
		}
	}

	public function logcrit($msg)
	{
		if ($this->loglevel > 1)
		{
	  	if (isset($this->params["addtime"])) {$currtime=date("H:i:s ");} else {$currtime="";}
			$this->writelog("<CRITICAL> $currtime$msg");
			if ($this->params["loglevel"] < 6) {$this->params["loglevel"] = 6;}
		}
	}

	public function logalert($msg)
	{
		if ($this->loglevel > 0)
		{
	  	if (isset($this->params["addtime"])) {$currtime=date("H:i:s ");} else {$currtime="";}
			$this->writelog("<ALERT> $currtime$msg");
			if ($this->params["loglevel"] < 6) {$this->params["loglevel"] = 6;}
		}
	}

	public function logemerg($msg)
	{
		if ($this->loglevel >= 0)
		{
	  	if (isset($this->params["addtime"])) {$currtime=date("H:i:s ");} else {$currtime="";}
			$this->writelog("<EMERG> $currtime$msg");
			if ($this->params["loglevel"] < 6) {$this->params["loglevel"] = 6;}
		}
	}
	
	public function logend($msg)
	{
		if ($this->params["loglevel"] >= -1)
		{
			if (!isset($this->params["nofile"]) && $this->params["filename"] != "")
			{
				file_put_contents($this->params["filename"], "<LOGEND>$msg" . PHP_EOL, FILE_APPEND);
				file_put_contents($this->params["filename"], "<LOGEND>".date("d.m.Y H:i:s")." TASK FINISHED" . PHP_EOL, FILE_APPEND);
			}
			if (isset($this->params["stderr"]))
			{
				fwrite(STDERR, "<LOGEND>$msg" . PHP_EOL);
				fwrite(STDERR, "<LOGEND>".date("d.m.Y H:i:s")." TASK FINISHED" . PHP_EOL);
			}
		}
	}

	public function writelog($msg) {
		if (isset($this->params["nofile"])) {fwrite(STDOUT,$msg . PHP_EOL);}
		if (isset($this->params["stderr"]) || (!isset($this->params["nofile"]) && $this->params["filename"] == "")) {fwrite(STDERR,$msg . PHP_EOL);}
		if (!isset($this->params["nofile"]) && $this->params["filename"] != "") {file_put_contents($this->params["filename"], $msg . PHP_EOL, FILE_APPEND);}
	}
}

class LBLog
{
	public static $VERSION = "1.0.0.5";
	private $stdLog;
	
	public static function newLog($args)
	{
		global $stdLog;
		$newlog = new intLog($args);
		if ( ! $stdLog ) { $stdLog = $newlog; }
		return $newlog;
	}
	
	public static function get_notifications ($package = NULL, $name = NULL)
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
	public static function get_notifications_html ($package = NULL, $name = NULL, $type = NULL, $buttons = NULL)
	{
		error_log("get_notifications_html called.\n");
		
		global $lbpplugindir;

		$NOTIFHANDLERURL = "http://localhost:" . lbwebserverport() . "/admin/system/tools/ajax-notification-handler.cgi";	
	
		$fields = array(
			'action' => 'get_notifications_html',
		);
		
		if (isset($package)) { $fields['package'] = $package; }
		if (isset($name)) { $fields['name'] = $name; }
		if (isset($type)) { $fields['type'] = $type; }
		if (isset($buttons)) { $fields['buttons'] = $buttons; }
		
		
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
