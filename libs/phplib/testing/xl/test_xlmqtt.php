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

	$mqtt->set( "testing/LoxBerry_XL", rand(1, 100) );
	echo "Nuki sentAtTimeISO: " . $mqtt->get ( "nuki/441612989/sentAtTimeISO" ) . "\n";
	echo "keepaliveepoch: " . $mqtt->get ( "loxberry-dev.brunnenweg.lan/mqttgateway/keepaliveepoch" ) . "\n";
	echo "Fertig\n";
	
?>

