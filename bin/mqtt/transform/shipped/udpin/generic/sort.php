#!/usr/bin/php
<?php
	if( $argv[1] == 'skills' ) {
		echo "description=Sorts incoming data and responds with sorted values and index\n";
		echo "link=https://www.loxwiki.eu/x/kYRWBQ\n";
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
	
	// $timetopic = $topic.'/'.'time';
	// $datetopic = $topic.'/'.'date';
	
	// We modify the data (we add the time)
	// $data = $data . ' ('.date('H:i:s').')';
	
	$allowedFunctions = array( "sort" => "asort", "rsort" => "arsort");
	
	
	$params = explode( ":", $data );
	if( array_key_exists ( $params[0], $allowedFunctions ) ) {
		$function = $allowedFunctions[$params[0]];
		array_shift($params);
	}
	else {
		$function = "asort";
	}
	error_log("function $function");
	error_log("params ". implode(":", $params));
	
	
	// print_r( $params );
	$function($params);
	// print_r( $params );
	
	$dataarray = array();
	$counter=0;
	foreach ($params as $key => $value) {
		$counter++;
		array_push( $dataarray, array ( "$topic/val$counter" => $value ) );
		array_push( $dataarray, array ( "$topic/index$counter" => $key+1 ) );
	}
	
	// Output data as json
	echo json_encode( $dataarray, JSON_UNESCAPED_UNICODE );
