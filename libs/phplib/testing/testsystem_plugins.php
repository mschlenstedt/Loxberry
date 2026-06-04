#!/usr/bin/env php
<?php
require_once "loxberry_system_v2.php";

$plugins = LBSystem::get_plugins();
foreach($plugins as $plugin) {
    echo "PLUGIN " . $plugin['PLUGINDB_TITLE'] . "\n   ";
	foreach($plugin as $variable => $value) { 
		echo $variable . "|" . $value . "#";
	}
	echo "\n";
	
}


?>
