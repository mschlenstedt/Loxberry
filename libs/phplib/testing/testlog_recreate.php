#!/usr/bin/env php
<?php
require_once "loxberry_log.php";

$mylog = LBLog::newLog(array("addtime" => "1", "name" => "PHPLog", "package" => "Test", "logdir" => $lbslogdir, "stdout" => 1));
LOGSTART("Das ist mein gl PHP Log");
LOGINF("Das erste log");
$dbkey = $mylog->dbkey;
LOGINF("DBKey ist $dbkey");
echo "Status is " . $mylog->STATUS . "\n";
unset($mylog);
#unset($stdLog);

sleep(2);


$newlog = LBLog::newLog(array( "dbkey" => $dbkey ) );
LOGINF("Neues Log!");
LOGINF("DBKey ist " . $newlog->dbkey);
echo "Status is " . $newlog->STATUS . "\n";

?>
