#!/usr/bin/env php
<?php
require_once "loxberry_log.php";

$mylog = LBLog::newLog(array("name" => "PHPLog", "package" => "lbbackup", "filename" => "testgllog", "addtime" => 1, "stderr" => 1));

LOGSTART("Das ist mein gl PHP Log");
while (1) {
	LOGINF("Current loglevel is " . $mylog->loglevel());
	// LOGINF("Hallo");
	sleep(5);
}


?>
