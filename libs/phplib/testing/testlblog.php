#!/usr/bin/env php
<?php
require_once "loxberry_log.php";

echo LBLog::get_notifications_html("Test");

$mylog = LBLog::newLog(array("name" => "PHPLog", "package" => "core", "filename" => "testlog", "stderr" => "1"));
$mylog->startlog("Das ist mein PHP Log");
$mylog->logdeb("Das ist eine Debug Message");
$mylog->loginf("Das ist eine Info Message");
$mylog->logok("Das ist eine OK Message");
$mylog->logwarn("Das ist eine Warning Message");
$mylog->logerr("Das ist eine Error Message");
$mylog->logcrit("Das ist eine Critical Message");
$mylog->logalert("Das ist eine Alert Message");
$mylog->logemerg("Das ist eine Emergency Message");
$mylog->logend("Das ist das Log Ende");
if (file_exists($mylog->filename)) 
{
	$logfile = file_get_contents($mylog->filename);
	print_r($logfile);
}


?>
