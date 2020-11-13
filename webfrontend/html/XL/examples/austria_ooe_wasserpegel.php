#!/usr/bin/env php
<?php
require_once "loxberry_XL.php";

/* 
	LOXBERRY XL
	EXtended Logic
	
	Wasserstand OÖ (V1)
	Stationsnummer suchen auf https://hydro.ooe.gv.at/#Pegel

*/

$station_names= array(
	"Steyr (Zollamt)",
	"Iglmühle"
);
$topic="ooe/pegel";

$url = "https://hydro.ooe.gv.at/internet/layers/1/index.json";


// error_log("Wasserstand: Station $stationno Topic $topic aufgerufen");

$filename = "/tmp/pegel_ooe.tmp";

// Get data
if (!file_exists( $filename ) or filemtime( $filename ) < time()-60*10 ) {
	error_log("Downloading file from $url");
	$data = file_get_contents( $url, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES );
	file_put_contents( $filename, $data );
} else {
	error_log("Using cache file $filename");
	$data = file_get_contents( $filename, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES );
}

if(empty($data)) {
	error_log("Keine Daten von URL $url. Exit.");
	exit(1);
}

$showlist = isset($argv[1]) and $argv[1] == "list" ? true : false;
if ( $showlist) {
	echo "Stationsname                 | Pegel | Stationsnr | Fluss\n";
}

$data = json_decode( $data );

foreach ( $data as $item ) {

	if( $showlist ) {
		echo 
			str_pad( $item->station_name, 30, ' ') . "| " . 
			str_pad( $item->ts_value, 5, ' ', STR_PAD_RIGHT ) . " | " . 
			str_pad( $item->station_no, 5, ' ', STR_PAD_RIGHT) . " | " . 
			$item->river_name . "\n"
		;
		continue;
	}
	
	if( ! in_array( $item->station_name, $station_names ) ) {
		continue;
	}

	// Generate data
	$station_topic = $topic.'/'.$item->station_name;
	
	// Delete unneeded properties from response
	unset(
		$item->gn_atr_stanr_hzb,
		$item->req_timestamp,
		$item->station_carteasting,
		$item->station_cartnorthing,
		$item->station_id,
		$item->ts_id,
		$item->ts_name,
		$item->ts_shortname,
		$item->tsinfo_precision,
		$item->web_gebiet,
		$item->web_information,
		$item->web_vorhersageurl,
	);
	
	// Add human readable time
	$timestamp = strtotime( $item->timestamp );
	$item->updatedHR = $xl->date( $timestamp ) . " " . $xl->time( $timestamp );
	$item->updatedEpoch = $timestamp;

	$json_data = json_encode($item, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_LINE_TERMINATORS | JSON_PRETTY_PRINT );
	$mqtt->retain( $station_topic, $json_data );
	echo $json_data;
}

// END
