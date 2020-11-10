#!/usr/bin/env php
<?php
require_once "loxberry_XL.php";
require_once "loxberry_json.php";

/* 
	LOXBERRY XL
	EXtended Logic
	 
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
	// Send data
	$mqtt->retain( $topic, json_encode($cache) );
}

// Cleanup if we have a new year!
if( !empty($cache->dailyavgtimestamp->year) && $cache->dailyavgtimestamp->year != $xl->year ) {
	unset(
		$cache->gts
	);
}

// Make Daily Avg. calculation
daily_average();

print_r($cache);



file_put_contents($cachefile, json_encode($cache, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE));

// Calculate the daily temperature average
function daily_average() {
	global $cache;
	global $outtemp;
	global $xl;

	error_log("daily_average called");

	// Init variables
	$cache->dailyavg = empty($cache->dailyavg) ? 0 : $cache->dailyavg;
	$cache->dailyavg_count = empty($cache->dailyavg_count) ? 0 : $cache->dailyavg_count;
	$cache->dailyavg_positive = empty($cache->dailyavg_positive) ? 0 : $cache->dailyavg_positive;
	$cache->dailyavg_positive_count = empty($cache->dailyavg_positive_count) ? 0 : $cache->dailyavg_positive_count;

	if( empty($outtemp) ) {
		error_log("Außentemperatur nicht lesbar!");
		exit(2);
	}
		
	$cache->dailyavg = ( $cache->dailyavg * $cache->dailyavg_count + $outtemp ) / ($cache->dailyavg_count+1);
	$cache->dailyavg_count++;
	
	if( $outtemp > 0 ) {
		
		$cache->dailyavg_positive = ( $cache->dailyavg_positive * $cache->dailyavg_positive_count + $outtemp ) / ($cache->dailyavg_positive_count+1);
		$cache->dailyavg_positive_count++;
	}
	
	if( !property_exists($cache, "dailyavgtimestamp") ) {
		$cache->dailyavgtimestamp = new StdClass();
	}
	$cache->dailyavgtimestamp->dayofyear = $xl->dayofyear;
	$cache->dailyavgtimestamp->month = $xl->month;
	$cache->dailyavgtimestamp->year = $xl->year;
	$cache->dailyavgtimestamp->date_hr = $xl->date;
	$cache->dailyavgtimestamp->time_hr = $xl->time;
	$cache->dailyavgtimestamp->epoch = time();
	
}

// On a new day, calculate GTS 
function calculate_gts() {
	global $cache;
	global $historyfile;
	global $xl;
	
	error_log("calculate_gts called");
	
	// Multiply factor
	if( $cache->dailyavgtimestamp->month == 1 ) {
		$month_factor = 0.5;
	} elseif ( $cache->dailyavgtimestamp->month == 2 ) {
		$month_factor = 0.75;
	} else {
		$month_factor = 1;
	}
	$cache->gts->gts = empty($cache->gts->gts) ? 0 : $cache->gts->gts;
	$cache->gts->gts = $cache->gts->gts +  $cache->dailyavg_positive;
	$cache->gts->date_hr = $xl->date;
	$cache->gts->time_hr = $xl->time;
	
	// Write history file
	$history = json_decode(file_get_contents($historyfile));
	$year = $cache->dailyavgtimestamp->year;
	$date = $cache->dailyavgtimestamp->date_hr;
	$history->$year->$date->gts = $cache->gts->gts;
	$history->$year->$date->dailyavg = $cache->dailyavg;
	$history->$year->$date->dailyavg_count = $cache->dailyavg_count;
	$history->$year->$date->dailyavg_positive = $cache->dailyavg_positive;
	$history->$year->$date->dailyavg_positive_count = $cache->dailyavg_positive_count;
	$history->$year->$date->date_hr = $xl->date;
	$history->$year->$date->time_hr = $xl->time;
	file_put_contents( $historyfile, json_encode($history, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE) );

	// Empty data after each day
	unset(
		$cache->dailyavg,
		$cache->dailyavg_count,
		$cache->dailyavg_positive,	
		$cache->dailyavg_positive_count,
	);
	
}