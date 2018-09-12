#!/usr/bin/env php
<?php
require_once "loxberry_io.php";

//udp_single();
//udp_singlearray();
//udp_multi();

test_mshttp_call();



function test_mshttp_call()
{
	// Send raw text
	$call = '/dev/sps/io/' . 'Zone Wohnküche' . '/all';
	list($value, $code, $xml) = mshttp_call(2, $call);
	echo "Code: $code Value: $value\n";
	
}

?>