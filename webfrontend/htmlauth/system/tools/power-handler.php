<?php
require_once "loxberry_system.php";

header('Content-Type: application/json');
header('Cache-Control: no-cache, must-revalidate');
header('Expires: Sat, 26 Jul 1997 05:00:00 GMT');

$bins = LBSystem::get_binaries();
$pid = exec("ps ax | grep ".$bins['REBOOT']." | grep -v grep | awk '{print $1}'");

if ($pid != "" ) {
	echo '{"reboot_in_progress": "1"}';
} else {
	echo '{"reboot_in_progress": "0"}';
}
?>
