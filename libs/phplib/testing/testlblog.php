#!/usr/bin/env php
<?php
require_once "loxberry_log.php";

echo LBLog::get_notifications_html("Test");

$mylog = LBLog::newLog(array("name" => "PHPLog", "package" => "core", "filename" => "testgllog"));
$mylog2 = LBLog::newLog(array("name" => "PHPLog", "package" => "core", "filename" => "testlog"));
$mylog2->LOGSTART("Das ist mein PHP Log");
$mylog2->DEB("Das ist eine Debug Message");
$mylog2->INF("Das ist eine Info Message");
$mylog2->OK("Das ist eine OK Message");
$mylog2->WARN("Das ist eine Warning Message");
$mylog2->ERR("Das ist eine Error Message");
$mylog2->CRIT("Das ist eine Critical Message");
$mylog2->ALERT("Das ist eine Alert Message");
$mylog2->EMERG("Das ist eine Emergency Message");
$mylog2->LOGEND("Das ist das Log Ende");
LOGSTART("Das ist mein gl PHP Log");
LOGDEB("Das ist eine gl Debug Message");
LOGINF("Das ist eine gl Info Message");
LOGOK("Das ist eine gl OK Message");
LOGWARN("Das ist eine gl Warning Message");
LOGERR("Das ist eine gl Error Message");
LOGCRIT("Das ist eine gl Critical Message");
LOGALERT("Das ist eine gl Alert Message");
LOGEMERG("Das ist eine gl Emergency Message");
LOGEND("Das ist das gl Log Ende");
if (file_exists($mylog->filename)) 
{
	$logfile = file_get_contents($mylog->filename);
	print_r($logfile);
}


?>
