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

	
	echo "Available date/time functions:\n";
	echo "hour: " . $xl->hour . "\n";
	echo "minute: " . $xl->minute . "\n";
	echo "minofday: " . $xl->minofday . "\n";
	echo "day: " . $xl->day . "\n";
	echo "month: " . $xl->month . "\n";
	echo "year: " . $xl->year . "\n";
	echo "dayofyear: " . $xl->dayofyear . "\n";
	echo "weekday: " . $xl->weekday . "\n";
	echo "week: " . $xl->week . "\n";
	echo "date: ". $xl->date . "\n";
	echo "datetext: ". $xl->datetext . "\n";
	echo "time: ". $xl->time . "\n";
	echo "weekdaytext: " . $xl->weekdaytext . "\n";
	echo "monthtext: " . $xl->monthtext . "\n";
	echo "toxmasdays: " . $xl->toxmasdays . "\n";
	echo "toxmastext: " . $xl->toxmastext . "\n";
	

exit;

	
	
	// echo "Day Numerus -4: " . $xl->_getnumerus("days_numerus", -4) . "\n";
	// echo "Day Numerus 0: " . $xl->_getnumerus("days_numerus", 0) . "\n";
	// echo "Day Numerus 1: " . $xl->_getnumerus("days_numerus", 1) . "\n";
	// echo "Day Numerus 2: " . $xl->_getnumerus("days_numerus", 2) . "\n";
	// echo "Day Numerus 3: " . $xl->_getnumerus("days_numerus", 3) . "\n";
	// echo "Days to X-Mas: " . $xl->daystoxmas . "\n";
	
	echo $dtdiff = $xl->dtdiff(time(), '24.03.'.$xl->year.'0:00');
	echo "Text to XMas: " . $xl->toxmastext() . "\n";
	echo "Birthday: ";
	echo "Mein Geburtstag ist in $dtdiff->m Monaten und $dtdiff->d Tagen.\n";
?>

