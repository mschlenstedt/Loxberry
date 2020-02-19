#!/usr/bin/env php
<?php
require_once "loxberry_XL.php";

/* 
	LOXBERRY XL
	EXtended Logic

	This is intended to be used by USERS, not only by developers
 
/*  
	Init LOXBERRY XL by require_once "loxberry_XL.php";
	You then automatically can access all your configured Miniservers with $ms1, $ms2,...
*/

// Get a value from a Miniserver 1
echo "Temperatur: " . $ms1->Außentemperatursensor . "\n";

// If a number contains a unit (e.g. °C), use the 'clean' function
echo "Temperatur: " . clean( $ms1->Außentemperatursensor ) . "\n";

// If your Loxone block has a name with blanks, use the generic 'get' function
echo "Puffer Zone 1 (Sensor): " . $ms1->get("Puffer Zone 1 (Sensor)");

// You can set values of course! We send this to Miniserver 3
$ms3->Lichtschalter("pulse"); // Pulse a digital input
$ms3->SOLL_Temperatur(22.5); // Set an analoque value
// Even that!
$ms3->SOLL_Temperatur = 23.5; 
// Again, if the name of the block uses special chars (whitespaces or dash -), use the set function
$ms3->set("Wohnzimmer Soll-Temperatur", 21.3);


/*
	Create a good-day text with LOXBERRY XL
	
*/
	$text = "";
	$current_hour = date('H');
	if( $current_hour < 12 ) {
		$text .= "Schönen guten Morgen!";
	} elseif ( $current_hour > 12 and $current_hour < 17 ) {
		$text .= "Einen angenehmen Nachmittag!";
	} else {
		$text .= "Guten Abend!";
	}
	
	$text .= "Die Außentemperatur beträgt " . clean( $ms1->Außentemperatursensor ) . " Grad. ";
	
	$fenster = array();
	if( $ms1->Fensterstatus_Bad > 1 ) { array_push( $fenster, "Badfenster" ); }
	if( $ms1->Fensterstatus_Partyraum > 1 ) { array_push( $fenster, "Partyraum-Fenster" ); }
	if( $ms1->Fensterstatus_Büro > 1 ) { array_push( $fenster, "Bürofenster" ); }
	if( $ms1->Fensterstatus_Stiegenhaus > 1 ) { array_push( $fenster, "Stiegenhaus-Fenster" ); }
	if( $ms1->Fensterstatus_Schlafzimmer > 1 ) { array_push( $fenster, "Schlafzimmer" ); }
	
	if( count( $fenster ) > 0 ) {
		$text .= "Offene Fenster: " . join(", ", $fenster);
	} else {
		$text .= "Alle Fenster zu.";
	}
	
	// Text an VO senden
	$ms3->Küche_Gruß( $text );
	


?>

