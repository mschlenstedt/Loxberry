#!/usr/bin/env php
<?php
require_once "loxberry_io.php";
require_once "phpMQTT/phpMQTT.php";

$creds = mqtt_connectiondetails();

var_dump($creds);

?>