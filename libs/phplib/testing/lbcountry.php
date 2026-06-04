#!/usr/bin/env php
<?php
require_once "loxberry_system.php";

$country = LBSystem::lbcountry();

if (!empty($country)) {
	echo "Country code is: $country\n";
} else {
	echo "Country is NULL.\n";
}

?>
