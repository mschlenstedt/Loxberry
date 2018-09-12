#!/usr/bin/env php
<?php
require_once "loxberry_io.php";

//udp_single();
//udp_singlearray();
//udp_multi();

udp_singlearray_mem();



function udp_single()
{
	// Send raw text
	$udpmsg = "This is a line sent by msudp_send.";
	$udperr = msudp_send(1, 10101, "Test", $udpmsg);
	echo "UDP-Error: $udperr\n";
}

function udp_singlearray()
{
	// Send only one value in an array
	$values["First"] = "single";
	$udperr = msudp_send(1, 10101, "Test", $values);
	echo "UDP-Error: $udperr\n";
}

function udp_multi()
{
	// Send multipla values
	$values["First"] = "string";
	$values["Second"] = 25.4;
	$values["Third"] = rand();
	$values["Fourth"] = rand();
	$values["Fifth"] = rand();
	$values["Sixth"] = rand();
	$values["Seventh"] = rand();
	$values["Eights"] = rand();
	$values["Ninth"] = rand();
	$values["Tenth"] = rand();
	$values["Eleventh"] = rand();
	$values["Twelfth"] = rand();
	$values["Thirteenth"] = rand();
	$values["Fourteenth"] = rand();
	$values["Fifteenth"] = rand();
	$values["Sixteenth"] = rand();
	$values["Last"] = "Last";
	$udperr = msudp_send(1, 10101, "Test", $values);
	echo "UDP-Error: $udperr\n";
}

function udp_singlearray_mem()
{
	global $mem_sendall;
	// $mem_sendall = 1;
	
	// Send only one value in an array
	$values["First"] = "single";
	$udperr = msudp_send_mem(1, 10101, "Test", $values);
	echo "UDP-Error: $udperr\n";
}



?>