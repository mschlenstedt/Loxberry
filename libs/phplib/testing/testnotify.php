#!/usr/bin/env php
<?php
require_once "loxberry_log.php";
notify("Test", "Testing", "Was geht ab?");
notify("Test", "Testing", "Das ist ein Fehler?", True);

$notifications = LBLog::get_notifications("Test", "Testing");
foreach($notifications as $notification) {
		if (isset($notification['_ISPLUGIN'])) {
			print "This is a plugin notification from " . $notification['PACKAGE'] . ":\n"; 
		} elseif (isset($notification['_ISSYSTEM'])) {
			print "This is a system notification from " . $notification['PACKAGE'] . ":\n"; 
		}
		echo "Name: {$notification['NAME']} Message: {$notification['CONTENTRAW']} Severity {$notification['SEVERITY']}\n";
}


?>
