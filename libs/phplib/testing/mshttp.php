#!/usr/bin/env php
<?php
require_once "loxberry_io.php";

//udp_single();
//udp_singlearray();
//udp_multi();

// test_mshttp_call();
// test_mshttp_get();
test_mshttp_send();


function test_mshttp_call()
{
	// Send raw text
	$call = '/dev/sps/io/' . rawurlencode('Verbrauch Luftentfeuchter') . '/all';
	list($value, $code, $resp) = mshttp_call(2, $call);
	echo "Code: $code Value: $value\n";
	// echo var_dump($resp);
	
	foreach($resp->output as $output) {
		echo $output->attributes()->name . ": " . $output->attributes()->value . "\n";
	}
}

function test_mshttp_get()
{
	// Single value
	$value = mshttp_get(2, 'Lüftung UG');
	echo var_dump($value);
	echo "Value: $value\n";
	
	// Multiple values
	$value = mshttp_get(2, [ 'Luefter_TV', 'Luefter_Kue', 'Luefter_WZ' ] );
	echo "Value TV: {$value['Luefter_TV']}\n";
}

function test_mshttp_send()
{
	// Single value
	$value = mshttp_send(2, 'Zone Partyraum Titel', 'Spielt nix');
	echo var_dump($value);
	echo "Value: $value\n";
	
	// Multiple values
	$value = mshttp_send(2, [ 'Zone Partyraum Titel' => 'nix', 'Zone Wohnküche Titel' => 'garnix' ] );
	echo "Value Wohnküche: {$value['Zone Wohnküche Titel']}\n";
}


?>