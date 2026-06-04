#!/usr/bin/php
<?php
	if( $argv[1] == 'skills' ) {
		echo "description=Developer example of incoming text and outgoing text\n";
		echo "link=https://wiki.loxberry.de/konfiguration/widget_help/widget_mqtt/mqtt_gateway_udp_transformers/\n";
		echo "input=text\n";
		echo "output=text\n";
		exit();
	}
	
	// ---- THIS CAN BE USED ALWAYS ----
	// Remove the script name from parameters
	array_shift($argv);
	// Join together all command line arguments
	$commandline = implode( ' ', $argv );	
	// Split topic and data by separator
	list( $topic, $data ) = explode( '#', $commandline, 2);
	// ----------------------------------
	
	// Modify the data
	
	// We don't need to change the topic, but we can.
	// And we can create multiple topics and data out of one incoming dataset
	$timetopic = $topic.'/'.'time';
	$datetopic = $topic.'/'.'date';
	
	// We modify the data (we add the time)
	$data = $data . ' ('.date('H:i:s').')';
	
	// Now print multiple data to stdout
	echo $topic."#".$data."\n";
	echo $timetopic."#".date('H:i:s')."\n";
	echo $datetopic."#".date('m.d.y')."\n";
