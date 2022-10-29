<?php
require_once "loxberry_system.php";
$cfgfile = "$lbsconfigdir/general.json";
$jsoncontent = file_get_contents($cfgfile); 

$json = json_decode($jsoncontent, True); 
// var_dump($json);

$udpinport = $json['Mqtt']['Udpinport'];

@$topic = $_GET['topic'];
@$value = $_GET['value'];
@$retain = $_GET['retain'];
@$transform = $_GET['transform'];

echo "topic: $topic\n";
echo "value: $value\n";
echo "retain: $retain\n";
echo "transform: $transform\n";

if(empty($topic)) 
	syntaxhelp();

$address = "udp://127.0.0.1:$udpinport";
$socket = fsockopen($address);
if (is_enabled($retain)) {
	$written = fwrite($socket, json_encode( array ( "topic" => $topic, "value" => $value, "retain" => true, "transform" => $transform ) ) );
} else {
	$written = fwrite($socket, json_encode( array ( "topic" => $topic, "value" => $value, "transform" => $transform ) ) );
}

print "<p>$topic $transform $value</p>";
if($written == 0) {
	print "<p style='color:red'>Could not write to udp address $address</p>\n";
}
else {
	print "<p style='color:green'>$written bytes written to udp address $address</p>\n";
}

exit(0);

function syntaxhelp()
{
	global $topic, $value;
	print "<p style='color:red;'>ERROR with parameters</p>";
	print "<p>Usage:</p>\n";
	print htmlentities("Publish: http://" . "<user>:<pass>@ " . lbhostname() . ":" . lbwebserverport() . "/admin/system/tools/mqtt.php?topic=homematic/temperature/livingroom&value=21.3");
	print "<br>\n";
	print htmlentities("With retain: http://" . "<user>:<pass>@ " . lbhostname() . ":" . lbwebserverport() . "/admin/system/tools/mqtt.php?retain=1&topic=homematic/temperature/livingroom&value=21.3");
	print "<br>\n";
	print htmlentities("Delete value: http://" . "<user>:<pass>@ " . lbhostname() . ":" . lbwebserverport() . "/admin/system/tools/mqtt.php?retain=1&topic=homematic/temperature/livingroom");
	print "<br>\n";
	print htmlentities("With transformer: http://" . "<user>:<pass>@ " . lbhostname() . ":" . lbwebserverport() . "/admin/system/tools/mqtt.php?retain=1&topic=homematic/temperature/livingroom&value=21.3&transform=mytransformer");
	print "<br>\n";
	print "<br>\n";
	print htmlentities("For legacy, LoxBerry from 3.x also supports the old plugin endpoint http://" . "<user>:<pass>@" . lbhostname() . ":" . lbwebserverport() . "/admin/plugins/mqttgateway/mqtt.php");
	print "<br>\n";
		
	exit(1);
}
