#!/usr/bin/env php
<?php
require_once "loxberry_XL.php";
require_once "loxberry_json.php";

/* 
	LOXBERRY XL
	EXtended Logic
	
	Grünlandtemperatursumme V2
*/

$outtemp = $ms1->Außentemperatursensor;
$topic = "gts";
$cachefile = "/opt/loxberry/webfrontend/html/XL/user/gruenland.cache";
$historyfile = "/opt/loxberry/webfrontend/html/XL/user/gruenland.history";

// Open json file
if (!file_exists($cachefile)) {
	file_put_contents( $cachefile, '{ }' );
}
if (!file_exists($historyfile)) {
	file_put_contents( $historyfile, '{ }' );
}

if (!file_exists($cachefile)) {
	error_log("Cachfile nicht gefunden!");
	exit(1);
}

$cache = json_decode(file_get_contents($cachefile));
$outtemp = clean($outtemp);

// Check if we have a new day, and make calculations
if( !empty($cache->dailyavgtimestamp->dayofyear) && $cache->dailyavgtimestamp->dayofyear != $xl->dayofyear ) {
	calculate_gts();
}

// Cleanup if we have a new year!
if( !empty($cache->dailyavgtimestamp->year) && $cache->dailyavgtimestamp->year != $xl->year ) {
	unset(
		$cache->gts
	);
}

// Make Daily Avg. calculation
daily_average();

$json_data = json_encode($cache, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_LINE_TERMINATORS | JSON_PRETTY_PRINT );

// Send data
$mqtt->retain( $topic, $json_data );

// print_r($cache);

file_put_contents( $cachefile, $json_data );

echo $json_data . "\n";

// End


// Calculate the daily temperature average
function daily_average() {
	global $cache;
	global $outtemp;
	global $xl;

	error_log("daily_average called");

	// Init variables
	$cache->dailyavg = empty($cache->dailyavg) ? 0 : $cache->dailyavg;
	$cache->dailyavgCount = empty($cache->dailyavgCount) ? 0 : $cache->dailyavgCount;
	
	if( empty($outtemp) ) {
		error_log("Außentemperatur nicht lesbar!");
		exit(2);
	}
		
	$cache->dailyavg = ( $cache->dailyavg * $cache->dailyavgCount + $outtemp ) / ($cache->dailyavgCount+1);
	$cache->dailyavgCount++;
	
	// Estimated (rolling) gts
	$monthfactor = monthfactor();
	$cache->gts->gtsest = empty( $cache->gts->gts ) ? 0 : $cache->gts->gts;
	if( !empty( $cache->dailyavg ) && $cache->dailyavg > 0 ) {
		$cache->gts->gtsest += $cache->dailyavg * $monthfactor;
	}
	
	if( !property_exists($cache, "dailyavgtimestamp") ) {
		$cache->dailyavgtimestamp = new StdClass();
	}
	$cache->dailyavgtimestamp->dayofyear = $xl->dayofyear;
	$cache->dailyavgtimestamp->month = $xl->month;
	$cache->dailyavgtimestamp->year = $xl->year;
	$cache->dailyavgtimestamp->dateHR = $xl->date;
	$cache->dailyavgtimestamp->timeHR = $xl->time;
	$cache->dailyavgtimestamp->epoch = time();
	
}

// On a new day, calculate GTS 
function calculate_gts() {
	global $cache;
	global $historyfile;
	global $xl;
	
	error_log("calculate_gts called");
	
	$monthfactor = monthfactor();
	
	$cache->gts->gts = empty($cache->gts->gts) ? 0 : $cache->gts->gts;
	
	if( !empty( $cache->dailyavg ) && $cache->dailyavg > 0 ) {
		$cache->gts->gts = $cache->gts->gts + $cache->dailyavg * $monthfactor;
	}
	$cache->gts->dateHR = $xl->date;
	$cache->gts->timeHR = $xl->time;
	
	// Write history file
	$history = json_decode(file_get_contents($historyfile));
	$year = $cache->dailyavgtimestamp->year;
	$date = $cache->dailyavgtimestamp->dateHR;
	$history->$year->$date->gts = $cache->gts->gts;
	$history->$year->$date->dailyavg = $cache->dailyavg;
	$history->$year->$date->dailyavgCount = $cache->dailyavgCount;
	$history->$year->$date->dateHR = $xl->date;
	$history->$year->$date->timeHR = $xl->time;
	file_put_contents( $historyfile, json_encode($history, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE) );

	// Empty data after each day
	unset(
		$cache->dailyavg,
		$cache->dailyavgCount,
		$cache->dailyavg_positive,	
		$cache->dailyavg_positive_count,
	);
	
}

function monthfactor() {
	global $cache;
	// Multiply factor
	if( $cache->dailyavgtimestamp->month == 1 ) {
		$month_factor = 0.5;
	} elseif ( $cache->dailyavgtimestamp->month == 2 ) {
		$month_factor = 0.75;
	} else {
		$month_factor = 1;
	}
	return $month_factor;
}
	
	
	