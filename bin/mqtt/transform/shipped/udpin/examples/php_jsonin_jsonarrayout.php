#!/usr/bin/php
<?php
	if( $argv[1] == 'skills' ) {
		echo "description=Developer example of incoming json and outgoing json array data\n";
		echo "link=https://wiki.loxberry.de/konfiguration/widget_help/widget_mqtt/mqtt_gateway_udp_transformers/\n";
		echo "input=json\n";
		echo "output=json\n";
		exit();
	}
	
	// ---- THIS CAN BE USED ALWAYS ----
	// Remove the script name from parameters
	array_shift($argv);
	// Join together all command line arguments
	$commandline = implode( ' ', $argv );	
	// Parse json into an array
	$dataset = json_decode( $commandline, 1 );
	// Get the first element of the array
	$topic = array_key_first($dataset);
	$data = $dataset[$topic];
	// ----------------------------------

	// Modify the data
	
	// We don't need to change the topic, but we can!
	// And we can multiple data out of one dataset
	$timetopic = $topic.'/'.'time';
	$datetopic = $topic.'/'.'date';
	
	// We modify the data (we add the time)
	$data = $data . ' ('.date('H:i:s').')';
	
	// Now we fill our array with data arrays
	$dataarray = array();
	array_push( $dataarray, array ( $topic => $data ) );
	array_push( $dataarray, array ( $timetopic => date('H:i:s') ) );
	array_push( $dataarray, array ( $datetopic => date('m.d.y') ) );
	
	// Output data as json
	echo json_encode( $dataarray, JSON_UNESCAPED_UNICODE );
