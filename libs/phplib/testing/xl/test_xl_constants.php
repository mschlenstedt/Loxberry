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

	
/*
	echo "Available constants:\n";
	echo "hour: " . $xl->hour . "\n";
	echo "minute: " . $xl->minute . "\n";
	echo "Week of year: " . $xl->week . "\n";
	echo "Date: ". $xl->date . "\n";
	echo "Datetext: ". $xl->datetext . "\n";
	
	echo "Weekday Text: " . $xl->weekdaytext . "\n";
	echo "Time: ". $xl->time . "\n";
*/

	// echo "Day Numerus -4: " . $xl->_getnumerus("days_numerus", -4) . "\n";
	// echo "Day Numerus 0: " . $xl->_getnumerus("days_numerus", 0) . "\n";
	// echo "Day Numerus 1: " . $xl->_getnumerus("days_numerus", 1) . "\n";
	// echo "Day Numerus 2: " . $xl->_getnumerus("days_numerus", 2) . "\n";
	// echo "Day Numerus 3: " . $xl->_getnumerus("days_numerus", 3) . "\n";
	echo "Days to X-Mas: " . $xl->daystoxmas . "\n";
?>

