#!/usr/bin/env php
<?php
require_once "loxberry_XL.php";
/* 
	LOXBERRY XL
	EXtended Logic

	Driving time calculated by WAZE
	
	This uses an inofficial Waze API! 
	 
*/

$routing = new waze;
$routing->from(48.32419, 14.25799);
$routing->to(48.29870, 14.30585);
$routedata = $routing->calc();

echo "All available properties:\n";
echo "-------------------------\n";
foreach( $routedata as $key => $value ) {
	echo $key . ":" . $value . "\n";
}

echo "\n";
echo "Accessing single values:\n";
echo "Current duration in minutes : " . $routedata['durationRealtimeMinutes'] . "\n";
echo "Usual duration in minutes   : " . $routedata['durationNoTrafficMinutes'] . "\n";
