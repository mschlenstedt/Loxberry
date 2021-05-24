#!/usr/bin/env php
<?php
require_once "loxberry_io.php";

// $mqtt is the mqtt connection with Bluerhinos/phpMQTT
$mqtt = mqtt_connect();

# Therefore, the publish is a Bluerhinos/phpMQTT function
$mqtt->publish( "hallo/du", "direkte Verbindung ".rand(1,100), 0, true );

?>