#!/usr/bin/env php
<?php

require_once "loxberry_loxonetemplatebuilder.php";

$paramarray = [ "Title" => "Test" ];


$vi = new VirtualInHttp( $paramarray );

echo "Title of VI: " . $vi->Title . "\n";

// Add a Cmd

$linenr = $vi->VirtualInHttpCmd( [
	"Title" 	=> "'First' element",
	"Comment"	=> "Comment of first",
	"Signed"	=> 0
] );

$linenr = $vi->VirtualInHttpCmd( [
	"Title" 	=> '"Second" element',
	"Comment"	=> "Comment of second",
	"Analog"	=> false,
	"Check"		=> "&straße:\\v"
	
] );


$something = $vi->VirtualInHttpCmd( 2 );
$other = $vi->VirtualInHttpCmd(1);
echo "Title of element 1: " . $other->Title . "\n";
echo "Title of element 2: " . $something->Title . "\n";

echo "Deleting element 1\n";
$vi->delete(1);

echo "Is 1 deleted? " . $something->_deleted . "\n";
echo "Is 2 deleted? " . $other->_deleted . "\n";

echo $vi->output();
