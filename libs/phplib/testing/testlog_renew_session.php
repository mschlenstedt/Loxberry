#!/usr/bin/env php
<?php
require_once "loxberry_log.php";

$mylog = LBLog::newLog(array("addtime" => "1", "name" => "PHPLog", "package" => "Test", "logdir" => $lbslogdir, "stdout" => 1, "loglevel" => 7));
LOGSTART("Das ist mein gl PHP Log");
LOGINF("Das erste log");
LOGINF("Dateiname: " . $mylog->filename);
while(1) {
	$dbkey = $mylog->dbkey;
	LOGINF("DBKey ist $dbkey");
	echo "DBKey ist $dbkey\n";
	sleep(10);
}



?>
