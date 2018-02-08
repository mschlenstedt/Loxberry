<?php
require_once "loxberry_system.php";

$bins = LBSystem::get_binaries();
$pid = exec("ps ax | grep ".$bins['REBOOT']." | grep -v grep | awk '{print $1}'");

if ($pid != "" ) {
	echo '{"reboot_in_progress": "1"}';
} else {
	echo '{"reboot_in_progress": "0"}';
}
?>
