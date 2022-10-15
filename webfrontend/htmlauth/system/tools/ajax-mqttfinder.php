<?php

$datafile = "/dev/shm/mqttfinder.json";

header('Content-Type: application/json; charset=utf-8');

$fp = fopen($datafile, "r");
if( flock($fp, LOCK_SH) ) {
	echo fread($fp, 5*1024*1024);
	fclose($fp);
}
else {
	header("HTTP/1.0 404 Not Found");
}

?>
