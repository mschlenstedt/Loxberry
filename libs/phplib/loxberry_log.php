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
		if (!isset($this->params["package"]) && !isset($this->params["nofile"])) {
			echo "Could not determine your plugin name. If you are not inside a plugin, package must be defined.\n";
			exit(1);
		}
		if (!isset($this->params["name"]) && !isset($this->params["nofile"])) {
			echo "The name parameter must be defined.\n";
			exit(1);
		}

		if(!isset($this->params["loglevel"]) && isset($lbpplugindir)) {
			$this->params["loglevel"] = LBSystem::pluginloglevel();
		}
		if(!isset($this->params["loglevel"])) {
			# echo "No loglevel defined - defaulting to 7 DEBUG.\n";
			$this->params["loglevel"] = 7;
		}

		# Generating filename
		if (!isset($this->params["logdir"]) && !isset($this->params["filename"]) && is_dir($lbplogdir)) {
			$this->params["logdir"] = $lbplogdir;
		}
		
		if (!isset($this->params["nofile"])) {
			if (isset($this->params["logdir"]) && !isset($this->params["filename"])) {
				$this->params["filename"] = $this->params["logdir"] . "/" . currtime('file') . "_" . $this->params["name"] . ".log";
			} elseif (!isset($this->params["filename"])) {
				if(is_dir($lbplogdir)) {
					$this->params["filename"] = "$lbplogdir/" . currtime('file') . "_" . $this->params["name"] . ".log";
				} else {
					echo "Cannot determine plugin log directory. Terminating.\n";
					exit(1);
				}
			}
			if (!isset($this->params["filename"])) {
				echo "Could not smartly detect where your logfile should be placed. Check your parameters. Terminating.";
				exit(1);
			}
		}
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
		
		$this->writelog( "================================================================================");
		$this->writelog( "<LOGSTART>" . currtime() . " TASK STARTED");
		if(isset($msg)) {
			$this->writelog( "<LOGSTART>" . $msg);
			$this->params["LOGSTARTMESSAGE"] = $msg;
		}
		$is_file_str = "";
		foreach (glob( LBSCONFIGDIR . '/is_*.cfg') as $filename) {
			$is_file_str .= substr($filename, strrpos($filename, "/")+1) . " ";
		}
		if (isset($is_file_str)) {
			$is_file_str = "( " . $is_file_str . ")";
		}
		
		$plugin = LBSystem::plugindata($this->params["package"]);
		
		if (isset($this->params["addtime"])) {$currtime=date("H:i:s ");} else {$currtime="";}
		
		$this->writelog("$currtime<INFO> LoxBerry Version " . LBSystem::lbversion() . " " . $is_file_str);
		if (isset($plugin)) {
			$this->writelog("$currtime<INFO> " . $plugin['PLUGINDB_TITLE'] . " Version " . $plugin['PLUGINDB_VERSION']);
		}
		$this->writelog("$currtime<INFO> Loglevel: " . $this->params["loglevel"]);
	
		
		if(!isset($this->params["nofile"])) {
			
			if(!isset($this->params["dbh"])) {
				$this->params["dbh"] = intLog::log_db_init_database();
			}
			$this->params["dbkey"] = intLog::log_db_logstart($this->params["dbh"], $this);
			
		}
	}
	
	public function LOGEND($msg)
	{
		global $lbhomedir;
		
		if (!isset($this->params["package"]) && !isset($this->params["name"])) {
			echo "Object is not initialized.";
		}
		
		if (isset($msg)) {
			$this->params["LOGENDMESSAGE"] = $msg;
			$this->writelog("<LOGEND> " . $msg);
		}
		$this->writelog("<LOGEND> " . currtime() . " TASK FINISHED");
		
		$this->params["logend_called"] = 1;
		
		// echo "LOGEND\n";
		if(!isset($this->params["nofile"])) {
			// echo "Nofile not set\n";
			if(!isset($this->params["dbh"])) {
				// echo "Init db\n";
				$this->params["dbh"] = intLog::log_db_init_database();
			}
			if(!isset($this->params["dbkey"])) {
				// echo "DBKey not set - return\n";
				$p->params["dbkey"] = intLog::log_db_query_id($this->params["dbh"], $this);
			}
			intLog::log_db_logend($this->params["dbh"], $this);
			
		}
	}
	
	public function DEB($msg)
	{
		if(!isset($this->params{"STATUS"})) {
			$this->params{"STATUS"} = 7;
		}
		
		if ($this->loglevel > 6)
		{
	  	if (isset($this->params["addtime"])) {$currtime=date("H:i:s ");} else {$currtime="";}
			$this->writelog("$currtime$msg");
		}
	}

	public function INF($msg)
	{
		if(!isset($this->params{"STATUS"}) || $this->params{"STATUS"} > 6) {
			$this->params{"STATUS"} = 6;
		}
		if ($this->loglevel > 5)
		{
	  	if (isset($this->params["addtime"])) {$currtime=date("H:i:s ");} else {$currtime="";}
		$this->writelog("$currtime<INFO> $msg");
		}
	}

	public function OK($msg)
	{
		if(!isset($this->params{"STATUS"}) || $this->params{"STATUS"} > 5) {
			$this->params{"STATUS"} = 5;
		}
		if ($this->loglevel > 4)
		{
			if (isset($this->params["addtime"])) {$currtime=date("H:i:s ");} else {$currtime="";}
			$this->writelog("$currtime<OK> $msg");
		}
	}

	public function WARN($msg)
	{
		if(!isset($this->params{"STATUS"}) || $this->params{"STATUS"} > 4) {
			$this->params{"STATUS"} = 4;
		}
		if ($this->loglevel > 3)
		{
			if (isset($this->params["addtime"])) {$currtime=date("H:i:s ");} else {$currtime="";}
			$this->writelog("$currtime<WARNING> $msg");
		}
	}

	public function ERR($msg)
	{
		if(!isset($this->params{"STATUS"}) || $this->params{"STATUS"} > 3) {
			$this->params{"STATUS"} = 3;
		}
		if ($this->loglevel > 2)
		{
	  	if (isset($this->params["addtime"])) {$currtime=date("H:i:s ");} else {$currtime="";}
			$this->writelog("$currtime<ERROR> $msg");
		}
	}

	public function CRIT($msg)
	{
		if(!isset($this->params{"STATUS"}) || $this->params{"STATUS"} > 2) {
			$this->params{"STATUS"} = 2;
		}

		if ($this->loglevel > 1)
		{
	  	if (isset($this->params["addtime"])) {$currtime=date("H:i:s ");} else {$currtime="";}
			$this->writelog("$currtime<CRITICAL> $msg");
			if ($this->params["loglevel"] < 6) {$this->params["loglevel"] = 6;}
		}
	}

	public function ALERT($msg)
	{
		if(!isset($this->params{"STATUS"}) || $this->params{"STATUS"} > 1) {
			$this->params{"STATUS"} = 1;
		}

		if ($this->loglevel > 0)
		{
	  	if (isset($this->params["addtime"])) {$currtime=date("H:i:s ");} else {$currtime="";}
			$this->writelog("$currtime<ALERT> $msg");
			if ($this->params["loglevel"] < 6) {$this->params["loglevel"] = 6;}
		}
	}

	public function EMERG($msg)
	{
		if(!isset($this->params{"STATUS"}) || $this->params{"STATUS"} > 0) {
			$this->params{"STATUS"} = "0";
		}

		if ($this->loglevel >= 0)
		{
	  	if (isset($this->params["addtime"])) {$currtime=date("H:i:s ");} else {$currtime="";}
			$this->writelog("$currtime<EMERG> $msg");
			if ($this->params["loglevel"] < 6) {$this->params["loglevel"] = 6;}
		}
	}
	
	

	public function writelog($msg) {
		
		if (isset($this->params["stdout"])) {fwrite(STDOUT,$msg . PHP_EOL);}
		if (isset($this->params["stderr"])) {fwrite(STDERR,$msg . PHP_EOL);}
		if ($this->params["loglevel"] != 0 && !isset($this->params["nofile"]) && $this->params["filename"] != "") {file_put_contents($this->params["filename"], $msg . PHP_EOL, FILE_APPEND);}
	}

	private function log_db_init_database() 
	{
		
		$dbfile = LBHOMEDIR . "/log/system_tmpfs/logs_sqlite.dat";
		$db = new SQLite3($dbfile);
		$res = $db->exec("CREATE TABLE IF NOT EXISTS logs (
				PACKAGE VARCHAR(255) NOT NULL,
				NAME VARCHAR(255) NOT NULL,
				FILENAME VARCHAR (2048) NOT NULL,
				LOGSTART DATETIME,
				LOGEND DATETIME,
				LASTMODIFIED DATETIME NOT NULL,
				LOGKEY INTEGER PRIMARY KEY 
			)");
		if($res != True) {
			error_log("log_init_database create table 'logs' notifications: " . $db->lastErrorMsg());
			return;
		}
		$res = $db->exec("CREATE TABLE IF NOT EXISTS logs_attr (
				keyref INTEGER NOT NULL,
				attrib VARCHAR(255) NOT NULL,
				value VARCHAR(255),
				PRIMARY KEY ( keyref, attrib )
				)");
		if($res != True) {
			error_log("log_init_database create table 'logs_attr' notifications: " . $db->lastErrorMsg());
			return;
		}
		if (posix_getpwuid(fileowner($dbfile)) != "loxberry") {
				chown($dbfile, "loxberry");
		}
		
		return $db;
		
	}
	
	private function log_db_logstart($dbh, $p)
	{
		// echo "Package: " . $p->params["package"] . "\n";
		if(!isset($p->params["package"])) { throw new Exception("Create DB log entry: No PACKAGE defined");}
		if(!isset($p->params["name"])) { throw new Exception("Create DB log entry: No NAME defined");}
		if(!isset($p->params["filename"])) { throw new Exception("Create DB log entry: No FILENAME defined");}

		if(!isset($p->params["LOGSTART"])) {
			$p->params["LOGSTART"] = date("Y-m-d H:i:s");
		}
		$plugin = LBSystem::plugindata($p->params["package"]);
		if(isset($plugin) && isset($plugin['PLUGINDB_TITLE'])) {
			$p->params["_ISPLUGIN"] = 1;
			$p->params["PLUGINTITLE"] = $plugin['PLUGINDB_TITLE'];
		}
		
		# Start transaction;
		$dbh->exec("BEGIN TRANSACTION;");
		
		# Insert main log entry
		$sth = $dbh->prepare('INSERT INTO logs (PACKAGE, NAME, FILENAME, LOGSTART, LASTMODIFIED) VALUES (:package, :name, :filename, :logstart, :logmodified) ;');
		$sth->bindValue(':package', $p->params["package"]);
		$sth->bindValue(':name', $p->params["name"]);
		$sth->bindValue(':filename', $p->params["filename"]);
		$sth->bindValue(':logstart', $p->params["LOGSTART"]);
		$sth->bindValue(':logmodified', $p->params["LOGSTART"]);
		$res = $sth->execute();
		if ($res == False) {
			error_log("Error inserting log to DB: " . $dbh->lastErrorMsg());
			return;
		}
		$id = $dbh->lastInsertRowid();
		
		# Process further attributes
		
		$sth2 = $dbh->prepare('INSERT OR REPLACE INTO logs_attr (keyref, attrib, value) VALUES (:keyref, :attrib, :value);');
		
		foreach ($p->params as $key => $value) {
			if($key == "PACKAGE" || $key == "NAME" || $key == "LOGSTART" || $key == "LOGEND" || $key == "LASTMODIFIED" || $key == "FILENAME" || $key == "dbh" || $p->params[$key] == "" ) {
				continue;
			}
			// echo "Key: $key    Value: $value\n";
			$sth2->bindValue(':keyref', $id);
			$sth2->bindValue(':attrib', $key);
			$sth2->bindValue(':value', $value);
			$sth2->execute();
		}
		
		$res = $dbh->exec("COMMIT;");
		if ($res == False) {
			error_log("log_db_logstart: commit failed: " . $dbh->lastErrorMsg());
			return;
		}
	
	return $id;
	
	}
	
	private function log_db_logend($dbh, $p)
	{
		if(!isset($p->params["dbkey"])) { 
			# Seems that LOGEND was started without LOGSTART
			#throw new Exception("log_db_endlog: No dbkey defined");
			return;
		}
		
		$p->params["LOGEND"] = date("Y-m-d H:i:s");
		
		# Start transaction;
		$dbh->exec("BEGIN TRANSACTION;");
		
		# Insert main log entry
		$sth = $dbh->prepare('UPDATE logs set LOGEND = :logend, LASTMODIFIED = :lastmodified WHERE LOGKEY = :logkey ;');
		$sth->bindValue(':logend', $p->params["LOGEND"]);
		$sth->bindValue(':lastmodified', $p->params["LOGEND"]);
		$sth->bindValue(':logkey', $p->params["dbkey"]);
		$res = $sth->execute();
		if ($res == False) {
			error_log("Error updating logend in DB: " . $dbh->lastErrorMsg());
			return;
		}
		$id = $p->params["dbkey"];
		
		# Process further attributes
		
		$sth2 = $dbh->prepare('INSERT OR REPLACE INTO logs_attr (keyref, attrib, value) VALUES (:keyref, :attrib, :value);');
		
		foreach ($p->params as $key => $value) {
			if($key == "PACKAGE" || $key == "NAME" || $key == "LOGSTART" || $key == "LOGEND" || $key == "LASTMODIFIED" || $key == "FILENAME" || $key == "dbh" || $p->params[$key] == "" ) {
				continue;
			}
			// echo "Key: $key    Value: $value\n";
			$sth2->bindValue(':keyref', $id);
			$sth2->bindValue(':attrib', $key);
			$sth2->bindValue(':value', $value);
			$sth2->execute();
		}
		
		$res = $dbh->exec("COMMIT;");
		if ($res == False) {
			error_log("log_db_logend: commit failed: " . $dbh->lastErrorMsg());
			return;
		}
	
	return "Success";
	
	}
	
	private function log_db_query_id($dbh, $p)
	{

		# Check mandatory fields
		if(!isset($p->params["filename"])) { throw new Exception("log_db_queryid: No FILENAME defined");}
			
		# Search filename
		$qu = "SELECT LOGKEY FROM logs WHERE FILENAME LIKE '{$p->params["filename"]}' ORDER BY LOGSTART DESC LIMIT 1;"; 
		$res = $dbh->QUERY($qu);
		$row = $res->fetch();
		if (isset($row["logid"])) {
			return $logid;
		} else {
			error_log ("log_db_queryid: Could not find filename {$p->params["filename"]}\n");
		}
		return;
	}

	public function __destruct() 
	{
		if(!isset($this->params["logend_called"]) && !isset($this->params["nofile"])) {
			if(isset($this->params["dbkey"])) {
				if(!isset($this->params["dbh"])) {
					$this->params["dbh"] = intLog::log_db_init_database();
				}
				$dbh = $this->params["dbh"];
				$dbh->exec("INSERT OR REPLACE INTO logs_attr (keyref, attrib, value) VALUES (" . $this->params["dbkey"] . ", 'STATUS', '" . $this->params["STATUS"] . "');");
			}
		}
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
	if (!isset($stdLog)) { create_temp_logobject(); }
	$stdLog->LOGSTART($msg);
}

function LOGDEB ($msg)
{
	global $stdLog;
	if (!isset($stdLog)) { create_temp_logobject(); }
	$stdLog->DEB($msg);
}

function LOGINF ($msg)
{
	global $stdLog;
	if (!isset($stdLog)) { create_temp_logobject(); }
	$stdLog->INF($msg);
}

function LOGOK ($msg)
{
	global $stdLog;
	if (!isset($stdLog)) { create_temp_logobject(); }
	$stdLog->OK($msg);
}

function LOGWARN ($msg)
{
	global $stdLog;
	if (!isset($stdLog)) { create_temp_logobject(); }
	$stdLog->WARN($msg);
}

function LOGERR ($msg)
{
	global $stdLog;
	if (!isset($stdLog)) { create_temp_logobject(); }
	$stdLog->ERR($msg);
}

function LOGCRIT ($msg)
{
	global $stdLog;
	if (!isset($stdLog)) { create_temp_logobject(); }
	$stdLog->CRIT($msg);
}

function LOGALERT ($msg)
{
	global $stdLog;
	if (!isset($stdLog)) { create_temp_logobject(); }
	$stdLog->ALERT($msg);
}

function LOGEMERG ($msg)
{
	global $stdLog;
	if (!isset($stdLog)) { create_temp_logobject(); }
	$stdLog->EMERG($msg);
}

function LOGEND ($msg)
{
	global $stdLog;
	if (!isset($stdLog)) { create_temp_logobject(); }
	$stdLog->LOGEND($msg);
}

function create_temp_logobject()
{
		global $stdLog;
		global $lbpplugindir;
		if (! defined($lbpplugindir)) {
			$package = basename(__FILE__, '.php'); 
		} else {
			$package = $lbpplugindir;
		}
		$stdLog = LBLog::newLog( [ 
			"package" => $package, 
			"name" => "PHPLog",
			"stderr" => 1,
			"nofile" => 1,
			"addtime" => 1,
		] );
}