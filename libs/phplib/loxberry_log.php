<?php

require_once "loxberry_system.php";
// require_once "phphtmltemplate_loxberry/template040.php";

class intLog
{
	private $params;
	private $db_attribute_exclude_list = array ( "package", "name", "LOGSTART", "LOGEND", "LASTMODIFIED", "filename", "dbh", "dbkey", "_plugindb_timestamp");
	private $dbh;
	
	public function __construct($args)
	{
		global $lbpplugindir;
		global $lbplogdir;
		global $lbhomedir;

		# echo "CONSTRUCTOR\n";
				
		$this->params = $args;
		
		# If a dbkey was given, recreate logging session
		if(isset($args["dbkey"])) {
			$recreatestate = $this->log_db_recreate_session_by_id();
			if (empty($recreatestate)) 
				{ return null;
			}
			# Always append to a recovered logfile
			$this->params["append"] = 1;
		
		}
			
		if (!isset($this->params["package"])) {$this->params["package"] = $lbpplugindir;}
		if (!isset($this->params["package"]) && !isset($this->params["nofile"])) {
			echo "Could not determine your plugin name. If you are not inside a plugin, package must be defined.\n";
			exit(1);
		}
		if (!isset($this->params["name"]) && !isset($this->params["nofile"])) {
			echo "The name parameter must be defined.\n";
			exit(1);
		}

		if(!isset($this->params["loglevel"]) && isset($this->params["package"])) {
			$this->params["loglevel"] = LBSystem::pluginloglevel($this->params["package"]);
		} else {
			$this->params["loglevel_is_static"] = 1;
		}
		
		if(!isset($this->params["loglevel"])) {
			# echo "No loglevel defined - defaulting to 7 DEBUG.\n";
			$this->params["loglevel"] = 7;
			$this->params["loglevel_is_static"] = 1;
		}

		# Generating filename
		if (!isset($this->params["logdir"]) && !isset($this->params["filename"]) && is_dir($lbplogdir)) {
			$this->params["logdir"] = $lbplogdir;
		}
		
		if (!isset($this->params["nofile"])) {
			if (isset($this->params["logdir"]) && !isset($this->params["filename"])) {
				$this->params["filename"] = $this->params["logdir"] . "/" . currtime('filehires') . "_" . $this->params["name"] . ".log";
			} elseif (!isset($this->params["filename"])) {
				if(is_dir($lbplogdir)) {
					$this->params["filename"] = "$lbplogdir/" . currtime('filehires') . "_" . $this->params["name"] . ".log";
				} else {
					echo "Cannot determine plugin log directory. Terminating.\n";
					exit(1);
				}
			}
			if (!isset($this->params["filename"])) {
				echo "Could not smartly detect where your logfile should be placed. Check your parameters. Terminating.";
				exit(1);
			}
			
			if (empty($this->params["append"]) && empty($this->params["nofile"])) {
				if(file_exists($this->params["filename"])) unlink($this->params["filename"]);
				$dir = dirname($this->params["filename"]);
				if (!is_dir($dir)) {
					mkdir($dir, 0777, true);
				}
			}
			# SQLite init
			if(!empty($this->params["append"]) && empty($this->params["nofile"])) {
				if(empty($this->dbh)) {
					$this->dbh = intLog::log_db_init_database();
				}
				$this->params["dbkey"] = intLog::log_db_query_id($this->dbh, $this);
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
		$this->params["LOGSTARTBYTE"] = file_exists($this->params["filename"]) ? filesize($this->params["filename"]) : "0";
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
		
		if (isset($this->params["addtime"])) {$currtime=currtime('hrtimehires');} else {$currtime="";}
		
		$this->writelog("$currtime<INFO> LoxBerry Version " . LBSystem::lbversion() . " " . $is_file_str);
		if (isset($plugin)) {
			$this->writelog("$currtime<INFO> " . $plugin['PLUGINDB_TITLE'] . " Version " . $plugin['PLUGINDB_VERSION']);
		}
		$this->writelog("$currtime<INFO> Loglevel: " . $this->params["loglevel"]);
		if(!isset($this->params["nofile"])) {
			if(!isset($this->dbh)) {
				$this->dbh = intLog::log_db_init_database();
			}
			$this->params["dbkey"] = intLog::log_db_logstart($this->dbh, $this);
			
		}
	}
	
	public function LOGEND($msg = "")
	{
		global $lbhomedir;
		
		if (!isset($this->params["package"]) && !isset($this->params["name"])) {
			echo "Object is not initialized.";
		}
		
		if (!empty($msg)) {
			$this->params["LOGENDMESSAGE"] = $msg;
			$this->writelog("<LOGEND> " . $msg);
		}
		$this->writelog("<LOGEND> " . currtime() . " TASK FINISHED");
		
		$this->params["logend_called"] = 1;
		
		// echo "LOGEND\n";
		if(!isset($this->params["nofile"])) {
			// echo "Nofile not set\n";
			if(!isset($this->dbh)) {
				// echo "Init db\n";
				$this->dbh = intLog::log_db_init_database();
			}
			if(!isset($this->params["dbkey"])) {
				// echo "DBKey not set - return\n";
				$this->params["dbkey"] = intLog::log_db_query_id($this->dbh, $this);
			}
			intLog::log_db_logend($this->dbh, $this);
		}
	}
	
	public function DEB($msg)
	{
		
		$this->checkloglevel();
		
		if(!isset($this->params{"STATUS"})) {
			$this->params{"STATUS"} = 7;
		}
		
		if ($this->loglevel > 6)
		{
	  	if (isset($this->params["addtime"])) {$currtime=currtime('hrtimehires') . ' ';} else {$currtime="";}
			$this->writelog("$currtime$msg");
		}
	}

	public function INF($msg)
	{
		$this->checkloglevel();
			
		if(!isset($this->params{"STATUS"}) || $this->params{"STATUS"} > 6) {
			$this->params{"STATUS"} = 6;
		}
		if ($this->loglevel > 5)
		{
	  	if (isset($this->params["addtime"])) {$currtime=currtime('hrtimehires');} else {$currtime="";}
		$this->writelog("$currtime<INFO> $msg");
		}
	}

	public function OK($msg)
	{
		$this->checkloglevel();
		
		if(!isset($this->params{"STATUS"}) || $this->params{"STATUS"} > 5) {
			$this->params{"STATUS"} = 5;
		}
		if ($this->loglevel > 4)
		{
			if (isset($this->params["addtime"])) {$currtime=currtime('hrtimehires');} else {$currtime="";}
			$this->writelog("$currtime<OK> $msg");
		}
	}

	public function WARN($msg)
	{
		
		$this->checkloglevel();
		
		// Collect all messages from severity warning and above
		if (isset($this->params{'ATTENTIONMESSAGES'})) {
		$this->params{'ATTENTIONMESSAGES'} .= "\n";
		} else {
			$this->params{'ATTENTIONMESSAGES'} = "";
		}
		$this->params{'ATTENTIONMESSAGES'} .= "<WARNING> $msg";
		
		
		if(!isset($this->params{"STATUS"}) || $this->params{"STATUS"} > 4) {
			$this->params{"STATUS"} = 4;
		}
		if ($this->loglevel > 3)
		{
			if (isset($this->params["addtime"])) {$currtime=currtime('hrtimehires');} else {$currtime="";}
			$this->writelog("$currtime<WARNING> $msg");
		}
	}

	public function ERR($msg)
	{
		$this->checkloglevel();
		
		// Collect all messages from severity warning and above
		if (isset($this->params{'ATTENTIONMESSAGES'})) {
		$this->params{'ATTENTIONMESSAGES'} .= "\n";
		} else {
			$this->params{'ATTENTIONMESSAGES'} = "";
		}
		$this->params{'ATTENTIONMESSAGES'} .= "<ERROR> $msg";
		
		if(!isset($this->params{"STATUS"}) || $this->params{"STATUS"} > 3) {
			$this->params{"STATUS"} = 3;
		}
		if ($this->loglevel > 2)
		{
	  	if (isset($this->params["addtime"])) {$currtime=currtime('hrtimehires');} else {$currtime="";}
			$this->writelog("$currtime<ERROR> $msg");
		}
	}

	public function CRIT($msg)
	{
		$this->checkloglevel();
		
		// Collect all messages from severity warning and above
		if (isset($this->params{'ATTENTIONMESSAGES'})) {
		$this->params{'ATTENTIONMESSAGES'} .= "\n";
		} else {
			$this->params{'ATTENTIONMESSAGES'} = "";
		}
		$this->params{'ATTENTIONMESSAGES'} .= "<CRITICAL> $msg";
		
		if(!isset($this->params{"STATUS"}) || $this->params{"STATUS"} > 2) {
			$this->params{"STATUS"} = 2;
		}

		if ($this->loglevel > 1)
		{
	  	if (isset($this->params["addtime"])) {$currtime=currtime('hrtimehires');} else {$currtime="";}
			$this->writelog("$currtime<CRITICAL> $msg");
			if ($this->params["loglevel"] < 6) {$this->params["loglevel"] = 6;}
		}
	}

	public function ALERT($msg)
	{
		$this->checkloglevel();
		
		// Collect all messages from severity warning and above
		if (isset($this->params{'ATTENTIONMESSAGES'})) {
		$this->params{'ATTENTIONMESSAGES'} .= "\n";
		} else {
			$this->params{'ATTENTIONMESSAGES'} = "";
		}
		$this->params{'ATTENTIONMESSAGES'} .= "<ALERT> $msg";
		
		if(!isset($this->params{"STATUS"}) || $this->params{"STATUS"} > 1) {
			$this->params{"STATUS"} = 1;
		}

		if ($this->loglevel > 0)
		{
	  	if (isset($this->params["addtime"])) {$currtime=currtime('hrtimehires');} else {$currtime="";}
			$this->writelog("$currtime<ALERT> $msg");
			if ($this->params["loglevel"] < 6) {$this->params["loglevel"] = 6;}
		}
	}

	public function EMERG($msg)
	{
		$this->checkloglevel();
		
		// Collect all messages from severity warning and above
		if (isset($this->params{'ATTENTIONMESSAGES'})) {
		$this->params{'ATTENTIONMESSAGES'} .= "\n";
		} else {
			$this->params{'ATTENTIONMESSAGES'} = "";
		}
		$this->params{'ATTENTIONMESSAGES'} .= "<EMERG> $msg";
		
		if(!isset($this->params{"STATUS"}) || $this->params{"STATUS"} > 0) {
			$this->params{"STATUS"} = "0";
		}

		if ($this->loglevel >= 0)
		{
	  	if (isset($this->params["addtime"])) {$currtime=currtime('hrtimehires');} else {$currtime="";}
			$this->writelog("$currtime<EMERG> $msg");
			if ($this->params["loglevel"] < 6) {$this->params["loglevel"] = 6;}
		}
	}
	
	public function STATUS($severity = null)
	{
		if($severity >= 0 and $severity <=7 and ( empty($this->params{"STATUS"}) or $severity < $this->params{"STATUS"})) {
			$this->params{"STATUS"} = $severity;
		}
		return $this->params{"STATUS"};
		
	}

	public function ATTENTIONMESSAGES($messages = null)
	{
		if(!empty($messages)) {
			$this->params{"ATTENTIONMESSAGES"} = $messages;
		}
		return $this->params{"ATTENTIONMESSAGES"};

	}

	
	public function logtitle($title) 
	{
		if(isset($title)) {
			$this->params["LOGSTARTMESSAGE"] = $title;
			if(!isset($this->params["nofile"]) && isset($this->params["dbkey"]) && isset($this->dbh) ) { 
				$dbh = $this->dbh;
				$dbh->exec("UPDATE logs_attr SET value = '" . $this->params["LOGSTARTMESSAGE"] . "' WHERE keyref = " . $this->params["dbkey"] . " AND attrib = 'LOGSTARTMESSAGE';");
			}
		}
		return $this->params["LOGSTARTMESSAGE"];
		
	}

	public function checkloglevel()
	{
		// DEBUG 
		// echo "Is static: " . $this->params["loglevel_is_static"] . "\n";
		// echo "plugindb_changed_time " . LBSystem::plugindb_changed_time() . "\n";
		// echo "saved timestamp " . $this->params["_plugindb_timestamp"] . "\n";
		// $ct = LBSystem::plugindb_changed_time();
		// echo "changed_time: $ct (" . date ("F d Y H:i:s", $ct) . ") _pdb_timestamp: " . $this->params["_plugindb_timestamp"] . "(" . date ("H:i:s", $this->params["_plugindb_timestamp"]) . ")\n";
		
		if ( empty($this->params["loglevel_is_static"]) && ( empty($this->params["_plugindb_timestamp"] ) or LBSystem::plugindb_changed_time() != $this->params["_plugindb_timestamp"] ) ) {
			// error_log("Next poll cycle");
			$this->params["_plugindb_timestamp"] = LBSystem::plugindb_changed_time();
			$newloglevel = LBSystem::pluginloglevel($this->params["package"]);
			if( isset($newloglevel) && $newloglevel >= 0 && $newloglevel <= 7 && $newloglevel != $this->params["loglevel"] ) {
				$oldloglevel = $this->params["loglevel"];
				$this->params["loglevel"] = $newloglevel;
				// error_log("<INFO> User changed loglevel from $oldloglevel to $newloglevel");
				if (isset($this->params["addtime"])) {$currtime=currtime('hrtimehires');} else {$currtime="";}
				$this->writelog("$currtime<INFO> User changed loglevel from $oldloglevel to $newloglevel");
			}
		}
	}
	
	
	public function writelog($msg) {
		
		// Check if the database entry is still present
		if (!isset($this->params["_next_db_check"]) or time() > $this->params["_next_db_check"]) {
			// error_log("writelog: DB session check called");
			if(!isset($this->dbh)) {
				$this->dbh = intLog::log_db_init_database();
			}
			intLog::log_db_recreate_session($this->dbh, $this);
			$this->params["_next_db_check"] = time()+60;
		}
		
		if (isset($this->params["stdout"])) {fwrite(STDOUT,$msg . PHP_EOL);}
		if (isset($this->params["stderr"])) {fwrite(STDERR,$msg . PHP_EOL);}
		if ($this->params["loglevel"] != 0 && !isset($this->params["nofile"]) && $this->params["filename"] != "") {file_put_contents($this->params["filename"], $msg . PHP_EOL, FILE_APPEND);}
	}

	public function dbkey() 
	{
		if (isset($this->params["dbkey"]))
		{
			return $this->params["dbkey"];
		} else {
			return NULL;
		}
	}
	
	public function loglevel($newloglevel = null)
	{
		if (is_null($newloglevel)) {
			return($this->params["loglevel"]);
		}	
		if ($newloglevel >= 0 && $newloglevel <= 7) {
			$this->params["loglevel"] = $newloglevel;
			$this->params["loglevel_is_static"] = 1;
		}
		return($this->params["loglevel"]);
	}
	
	private function log_db_init_database() 
	{
		
		$dbfile = LBHOMEDIR . "/log/system_tmpfs/logs_sqlite.dat";
		
		for($i=1; $i <= 2; $i++) {
			$dbok = 1;
			try {			
				$this->dbh = new SQLite3($dbfile);
				$this->dbh->busyTimeout(5000);
				$this->dbh->exec('PRAGMA journal_mode = wal;');
				$db = $this->dbh;
				
				$db->exec("BEGIN TRANSACTION;");
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
					$dberr = $db->lastErrorCode();
					$dberrstr = $db->lastErrorMsg();
					error_log("log_db_init_database: Create table 'logs': Error $dberr $dberrstr");
					$dbok = 0;
					$db->exec('ROLLBACK;');
				}
				$res = $db->exec("CREATE TABLE IF NOT EXISTS logs_attr (
						keyref INTEGER NOT NULL,
						attrib VARCHAR(255) NOT NULL,
						value VARCHAR(255),
						PRIMARY KEY ( keyref, attrib )
						)");
				if($res != True) {
					$dberr = $db->lastErrorCode();
					$dberrstr = $db->lastErrorMsg();
					error_log("log_db_init_database: Create table 'logs_attr': Error $dberr $dberrstr");
					$dbok = 0;
					$db->exec('ROLLBACK;');
				}
				$db->exec("COMMIT;");
			} catch (Exception $e) {
				error_log("log_db_init_database: Opening database failed - " . $e->getMessage());
				$dbok = 0;
			}
	
			if ($dbok==1) {
				break;
			} else {
				error_log("Database error $dberr ($dberrstr)");	
				$this->log_db_repair($dbfile, $db, $dberr);
			}
		}			
		
		if($dbok != 1) {
			error_log("log_db_init_database: FAILED TO RECOVER DATABASE (Database error $dbierr - $dbierrstr)");
			notify( "logmanager", "Log Database", "The logfile database sends an error and cannot automatically be recovered. Please inform the LoxBerry-Core team about this error:\nError $dberr ($dberrstr)", 'error');
			return null;
		}	
					
		# chown
		if (posix_getpwuid(fileowner($dbfile)) != "loxberry") {
				chown($dbfile, "loxberry");
		}
		
		return $db;

	}
	
	private function log_db_repair($dbfile, $dbh, $dbierror)
	{
		error_log("log_db_repair: Repairing DB (Error $dbierror)");
		# https://www.sqlite.org/c3ref/c_abort.html
		# 11 - The database disk image is malformed
		if ($dbierror == "11") {
			error_log("logdb seems to be corrupted - deleting and recreating...");
			$dbh->close();
			unlink($dbfile);
		} else {
			unset($dbh);
			unset($this->dbh); 
			return null;
		}
	}
	
	
	private function log_db_logstart($dbh, $p)
	{
		
		// echo "Package: " . $p->params["package"] . "\n";
		if(!isset($p->params["package"])) { throw new Exception("Create DB log entry: No PACKAGE defined");}
		if(!isset($p->params["name"])) { throw new Exception("Create DB log entry: No NAME defined");}
		if(!isset($p->params["filename"])) { throw new Exception("Create DB log entry: No FILENAME defined");}

		if(empty($dbh)) {
			error_log("log_db_logstart: dbh not defined");
			return;
		}
		
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
			$dbh->exec("ROLLBACK;");
			return;
		}
		$id = $dbh->lastInsertRowid();
		
		# Process further attributes
		
		$sth2 = $dbh->prepare('INSERT OR REPLACE INTO logs_attr (keyref, attrib, value) VALUES (:keyref, :attrib, :value);');
		
		foreach ($p->params as $key => $value) {
			
			if(in_array($key, $this->db_attribute_exclude_list) || $p->params[$key] == "" ) {
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
		
		if(empty($dbh)) {
			error_log("log_db_logend: dbh not defined");
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
			$dbh->exec("ROLLBACK;");
			return;
		}
		$id = $p->params["dbkey"];
		
		# Process further attributes
		
		$sth2 = $dbh->prepare('INSERT OR REPLACE INTO logs_attr (keyref, attrib, value) VALUES (:keyref, :attrib, :value);');
		
		foreach ($p->params as $key => $value) {
			if(in_array($key, $this->db_attribute_exclude_list) || $p->params[$key] == "" ) {
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
		if(!isset($dbh)) { error_log("log_db_query_id: dbh not defined\n"); return; }
		
		# Search filename
		$qu = "SELECT LOGKEY FROM logs WHERE FILENAME LIKE '{$p->params["filename"]}' ORDER BY LOGSTART DESC LIMIT 1;"; 
		// error_log("log_db_queryid: Query $qu\n");
		$res = $dbh->QUERY($qu);
		$row = $res->fetchArray(SQLITE3_ASSOC);
		if (!empty($row["LOGKEY"])) {
			return $row["LOGKEY"];
		} else {
			error_log ("log_db_queryid: Could not find database entry for {$p->params["filename"]}\n");
		}
		return;
	}

	private function log_db_recreate_session_by_id()
	{
		$key = $this->params["dbkey"];
		if( !isset($this->dbh) ) {
			$this->dbh = intLog::log_db_init_database();
			$dbh = $this->dbh;
		}
		if(!$dbh) {
			error_log("log_db_recreate_session_by_id: dbh not defined");
			return;
		}
		
		if(!$key) {
			error_log("log_db_recreate_session_by_id: No logdb key defined.");
			return;
		}

		# Get log object
		$qu = "SELECT PACKAGE, NAME, FILENAME, LOGSTART, LOGEND FROM logs WHERE LOGKEY = $key LIMIT 1;";
		// echo "Query: $qu\n";
		$logshr = $dbh->query($qu);
		
		if (!isset($logshr)) {
			error_log("log_db_recreate_session_by_id: LOGKEY does not exist.");
			return;
		}
		$result = $logshr->fetchArray(SQLITE3_ASSOC);
		# It is not possible to recover a finished session
		
		// echo var_dump( $result );
		
		if (isset($result["LOGEND"])) {
			error_log("log_db_recreate_session_by_id: LOGKEY $key found, but log session has a LOGEND (session is finished)");
			return;
		}
				
		# Get log attributes
		$qu2 = "SELECT attrib, value FROM logs_attr WHERE keyref = $key;";
		$logattrshr = $dbh->query($qu2);
		
		## Recreate log object with data
		
		# Data from log table
		if(isset($result["PACKAGE"])) {
			// echo "Package: " . $result["PACKAGE"] . "\n";
			$this->params["package"] = $result["PACKAGE"];
		}
		if(isset($result["NAME"])) {
			// echo "Name: " . $result["NAME"] . "\n";
			$this->params["name"] = $result["NAME"];
		}
		if(isset($result["FILENAME"])) {
			// echo "FILENAME: " . $result["FILENAME"] . "\n";
			$this->params["filename"] = $result["FILENAME"];
		}
		
		# Data from attribute table - loop through attributes
		while ($row = $logattrshr->fetchArray(SQLITE3_ASSOC)) {
			// echo "Attribute: " . $row["attrib"] . " / Value: " . $row["value"] . "\n";
			$this->params[$row["attrib"]] = $row["value"];
		}
		
		return $key;

	}
	
	private function log_db_recreate_session($dbh, $p) 
	{
		if(!isset($dbh)) {
			// error_log("log_db_recreate_session: dbh not defined - Abort.");
			return;
		}
		if(!isset($p->params["dbkey"])) {
			// error_log("log_db_recreate_session: dbkey not defined. Abort.");
			return;
		}
		
		# Search filename
		$qu = "SELECT LOGKEY FROM logs WHERE FILENAME LIKE '{$p->params["filename"]}' LIMIT 1;"; 
		$res = $dbh->QUERY($qu);
		$row = $res->fetchArray(SQLITE3_ASSOC);
		if (!empty($row["LOGKEY"])) {
			// error_log("log_db_recreate_session: logkey exists, nothing to do");
			return;
		} 
		// logkey not existing - recreate
		error_log("log_db_recreate_session: Session does not exist in DB - creating a new session");
		$p->params["dbkey"] = intLog::log_db_logstart($p->dbh, $p);
	}
	
	public function __destruct() 
	{
		// echo "__descruct called\n";
		if( !isset($this->params["logend_called"]) && !isset($this->params["nofile"]) ) {
			if( isset($this->params["dbkey"]) && isset($this->params["STATUS"]) ) {
				if( !isset($this->dbh) ) {
					$dbh = intLog::log_db_init_database();
				} else {
					$dbh = $this->dbh;
				}
				if(empty($dbh)) { error_log("__destruct: dbh not defined"); return;}
				
				$dbh->exec("INSERT OR REPLACE INTO logs_attr (keyref, attrib, value) VALUES (" . $this->params["dbkey"] . ", 'STATUS', '" . $this->params["STATUS"] . "');");
				$dbh->close();
			}
		}
		
		// unset($stdLog);
	}

}

class LBLog
{
	public static $VERSION = "2.0.0.1";
	
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

function LOGSTART ($msg="")
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

function LOGEND ($msg = "")
{
	global $stdLog;
	if (!isset($stdLog)) { create_temp_logobject(); }
	$stdLog->LOGEND($msg);
}

function LOGTITLE ($title)
{
	global $stdLog;
	if (!isset($stdLog)) { return $title; }
	$stdLog->logtitle($title);
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
