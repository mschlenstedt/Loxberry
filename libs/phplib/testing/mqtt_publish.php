#!/usr/bin/env php
<?php
require_once "loxberry_io.php";

# Therefore, the publish is a Bluerhinos/phpMQTT function
mqtt_set( "hallo/du", "mqtt_set mein content", true );
mqtt_publish ("hallo/ich", "mqtt_publish" );
mqtt_retain ("hallo/wir", "mqtt_retain" . rand(1,100) );
echo "Get: " . mqtt_get("hallo/wir") . "\n";

?>