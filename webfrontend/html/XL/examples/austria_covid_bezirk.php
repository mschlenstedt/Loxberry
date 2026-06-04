#!/usr/bin/env php
<?php
require_once "loxberry_XL.php";
/* 
	LOXBERRY XL
	EXtended Logic

	Covid-Fälle täglich, nach Bezirk
	Quelle: Open Data Österreich https://data.gv.at
	Datenkatalog: https://www.data.gv.at/katalog/dataset/4b71eb3d-7d55-4967-b80d-91a3f220b60c
	Ressource: https://covid19-dashboard.ages.at/data/CovidFaelle_Timeline_GKZ.csv
	 
*/

// Bezirks-ID GKZ - siehe Datenquelle
// z.B. Urfahr-Umgebung (GKZ) = 416
// Die GKZ kann auch in der URL mitgegeben werden 
$GKZ = 416;
$topic = "covid/";

if(!empty($_GET["GKZ"])) {;
	$GKZ = $_GET["GKZ"];
}

$ch = curl_init();
curl_setopt($ch, CURLOPT_URL, "https://covid19-dashboard.ages.at/data/CovidFaelle_Timeline_GKZ.csv");
curl_setopt($ch, CURLOPT_RETURNTRANSFER, 1);
curl_setopt($ch, CURLOPT_SSL_CIPHER_LIST, 'DEFAULT@SECLEVEL=1');
$output = curl_exec($ch);
curl_close($ch);     



$data = str_getcsv($output, "\n"); //parse the rows
foreach($data as &$row) $row = str_getcsv($row, ";"); //parse the items in rows

error_log("Datensätze: " . count($data));

for( $i = count($data)-1; $i > 0; $i-- ) {
	if ($data[$i][2] == $GKZ) {
		$current = $data[$i];
		break;
	}
}

if(isset($current)) {
	
	$header = $data[0];
	$nameddata = new stdClass();
	foreach( $current as $key => $value ) {
		$nameddata->{$header[$key]} = $value;
	}
	
	$GKZ_topic = $topic.$GKZ;
	$mqtt->retain( $GKZ_topic, json_encode($nameddata) );
	echo print_r($nameddata, true);


} else {
	echo "Nothing found with GKZ $GKZ\n";
}
