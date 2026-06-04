#!/usr/bin/env php
<?php

require_once "loxberry_loxonetemplatebuilder.php";

$paramarray = [ "Title" => "Test", "Address" => "192.168.0.11", "Port" => "12345" ];

$vi = new VirtualInUdp( $paramarray );

echo "Title of VI: " . $vi->Title . "\n";



// Add a Cmd

$linenr = $vi->VirtualInUdpCmd( [
	"Title" 	=> "'First' element",
	"Analog"	=> true,
	"Check"	=> '\ivalue1:\i\v'
] );

$linenr = $vi->VirtualInUdpCmd( [
	"Title" 	=> '"Second" element',
	"Analog"	=> false,
	"Check"		=> "&straße:\\v"
	
] );

echo $vi->output();
