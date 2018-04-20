<?php

require_once "loxberry_system.php";
// require_once "phphtmltemplate_loxberry/template040.php";

class intLog
{
	private $params;
	
	public function __construct($args)
	{
		global $lbpplugindir;
		global $lbplogdir;
		global $lbhomedir;

		# echo "CONSTRUCTOR\n";
		
		$this->params = $args;
		if (!isset($this->params["package"])) {$this->params["package"] = $lbpplugindir;}
		if (!isset($this->params["package"])) {
			echo "Could not determine your plugin name. If you are not inside a plugin, package must be defined.\n";
			exit(1);
		}
		if (!isset($this->params["name"])) {
			echo "The name parameter must be defined.\n";
			exit(1);
		}

		
		$cmdparams = " --action=new";
		
		foreach ($this->params as $key => $value) {
			# echo "key: $key // value $value\n";
			$cmdparams .= " --$key=\"$value\"";
		}
		# echo "CMD-Params: $cmdparams\n";
		$log=exec($lbhomedir . "/libs/bashlib/initlog.pl $cmdparams");
		if ($log == "")
		{
			echo "Log initialisation failed";
			exit(1);
		}
		
		$log=str_getcsv($log," ");
		$this->params["filename"] = $log[0];
		$this->params["loglevel"] = $log[1];
		# echo "Constructor: Filename " . $this->params["filename"] . "\n";
		
		
		
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
	
	public function LOGSTART($msg = "")
	{
		global $lbhomedir;
		
		if (!isset($this->params["package"]) && !isset($this->params["name"])) {
			echo "Object is not initialized.";
			exit(1);
		}
				
		//initializing the log an printout the start message
		$cmdparams = " --action=logstart --filename=\"" . $this->params["filename"] . "\" ";
		
		foreach ($this->params as $key => $value) {
			# echo "key: $key // value $value\n";
			$cmdparams .= " --$key=\"$value\"";
		}
		
		if(isset($msg)) {
			$cmdparams .= " --message=\"$msg\"";
		}
		
		# echo "CMD-Params: $cmdparams\n";
		$log=exec($lbhomedir . "/libs/bashlib/initlog.pl $cmdparams");
		if ($log == "")
		{
			echo "initlog returns a empty string.";
			return false;
		}
		
	}
	
	public function DEB($msg)
	{
		if ($this->loglevel > 6)
		{
	  	if (isset($this->params["addtime"])) {$currtime=date("H:i:s ");} else {$currtime="";}
			$this->writelog("<DEBUG> $currtime$msg");
		}
	}

	public function INF($msg)
	{
		if ($this->loglevel > 5)
		{
	  	if (isset($this->params["addtime"])) {$currtime=date("H:i:s ");} else {$currtime="";}
			$this->writelog("<INFO> $currtime$msg");
		}
	}

	public function OK($msg)
	{
		if ($this->loglevel > 4)
		{
	  	if (isset($this->params["addtime"])) {$currtime=date("H:i:s ");} else {$currtime="";}
			$this->writelog("<OK> $currtime$msg");
		}
	}

	public function WARN($msg)
	{
		if ($this->loglevel > 3)
		{
	  	if (isset($this->params["addtime"])) {$currtime=date("H:i:s ");} else {$currtime="";}
			$this->writelog("<WARNING> $currtime$msg");
		}
	}

	public function ERR($msg)
	{
		if ($this->loglevel > 2)
		{
	  	if (isset($this->params["addtime"])) {$currtime=date("H:i:s ");} else {$currtime="";}
			$this->writelog("<ERROR> $currtime$msg");
		}
	}

	public function CRIT($msg)
	{
		if ($this->loglevel > 1)
		{
	  	if (isset($this->params["addtime"])) {$currtime=date("H:i:s ");} else {$currtime="";}
			$this->writelog("<CRITICAL> $currtime$msg");
			if ($this->params["loglevel"] < 6) {$this->params["loglevel"] = 6;}
		}
	}

	public function ALERT($msg)
	{
		if ($this->loglevel > 0)
		{
	  	if (isset($this->params["addtime"])) {$currtime=date("H:i:s ");} else {$currtime="";}
			$this->writelog("<ALERT> $currtime$msg");
			if ($this->params["loglevel"] < 6) {$this->params["loglevel"] = 6;}
		}
	}

	public function EMERG($msg)
	{
		if ($this->loglevel >= 0)
		{
	  	if (isset($this->params["addtime"])) {$currtime=date("H:i:s ");} else {$currtime="";}
			$this->writelog("<EMERG> $currtime$msg");
			if ($this->params["loglevel"] < 6) {$this->params["loglevel"] = 6;}
		}
	}
	
	public function LOGEND($msg)
	{
		global $lbhomedir;
		
		if (!isset($this->params["package"]) && !isset($this->params["name"])) {
			echo "Object is not initialized.";
		}
				
		//initializing the log an printout the start message
		$cmdparams = " --action=logend --filename=\"" . $this->params["filename"] . "\" ";
		
		foreach ($this->params as $key => $value) {
			# echo "key: $key // value $value\n";
			$cmdparams .= " --$key=\"$value\"";
		}
		
		if(isset($msg)) {
			$cmdparams .= " --message=\"$msg\"";
		}
		
		# echo "CMD-Params: $cmdparams\n";
		$log=exec($lbhomedir . "/libs/bashlib/initlog.pl $cmdparams");
		if ($log == "")
		{
			echo "initlog returns a empty string.";
			return false;
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
	public static $VERSION = "1.0.0.6";
	
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

$stdLog = NULL;

function LOGSTART ($msg)
{
	global $stdLog;
	$stdLog->LOGSTART($msg);
}

function LOGDEB ($msg)
{
	global $stdLog;
	$stdLog->DEB($msg);
}

function LOGINF ($msg)
{
	global $stdLog;
	$stdLog->INF($msg);
}

function LOGOK ($msg)
{
	global $stdLog;
	$stdLog->OK($msg);
}

function LOGWARN ($msg)
{
	global $stdLog;
	$stdLog->WARN($msg);
}

function LOGERR ($msg)
{
	global $stdLog;
	$stdLog->ERR($msg);
}

function LOGCRIT ($msg)
{
	global $stdLog;
	$stdLog->CRIT($msg);
}

function LOGALERT ($msg)
{
	global $stdLog;
	$stdLog->ALERT($msg);
}

function LOGEMERG ($msg)
{
	global $stdLog;
	$stdLog->EMERG($msg);
}

function LOGEND ($msg)
{
	global $stdLog;
	$stdLog->LOGEND($msg);
}