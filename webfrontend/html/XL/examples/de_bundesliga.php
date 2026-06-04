#!/usr/bin/env php
<?php
require_once "loxberry_XL.php";
/* 
	LOXBERRY XL
	EXtended Logic

	Deutsche Fußball-Bundesliga
	Datenfeed von https://www.openligadb.de/
	API https://github.com/OpenLigaDB/OpenLigaDB-Samples

*/

$ch = curl_init();
curl_setopt($ch, CURLOPT_RETURNTRANSFER, 1);

for( $season = $xl->year()+1; $season >= $xl->year(); $season-- ) {
	echo "Testing season $season\n";
	curl_setopt( $ch, CURLOPT_URL, "https://www.openligadb.de/api/getbltable/bl1/$season" );
	$resp = curl_exec($ch);
	$tbldata = json_decode( $resp );
	if( !empty( $tbldata ) ) {
		echo "Found data in season $season\n";
		echo "RAW DATA:\n\n";
		echo $resp . "\n\n";
		break;
	}
}

curl_close($ch);
if( empty( $tbldata ) ) {
	exit(1);
}

// We have a huge dataset - we loop all data
$placement = 0;
foreach ( $tbldata as $team ) {
	$placement++;

	// Here, we remove everything we do NOT need
	
	unset( $team->TeamInfoId );
	unset( $team->ShortName );
	unset( $team->TeamIconUrl );
	// unset( $team->OpponentGoals );
	// unset( $team->Goals );
	unset( $team->Matches );
	// unset( $team->Won );
	// unset( $team->Lost );
	unset( $team->Draw );
	// unset( $team->GoalDiff );

	// We only want the TOP 10
	if ($placement > 9) {
		unset($tbldata[$placement]);
	}

}

// Now send the data via MQTT
$placement = 0;
foreach ( $tbldata as $team ) {
	$placement++;
	echo $placement . ". " . $team->TeamName . " --> " . $team->Points . " Points\n";
	
	$mqtt->retain( "bundesliga/tabelle/$placement", json_encode( $team ) );

}

echo "\nSubscribe bundesliga/# in MQTT Gateway!\n";
