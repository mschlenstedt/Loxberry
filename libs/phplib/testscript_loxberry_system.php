<?php
require_once "loxberry_system.php";

# print "LBPLUGINDIR using Constant: " . LBPLUGINDIR . "\n";
# print "LBPLUGINDIR using variable: $LBPLUGINDIR\n";
fwrite(STDERR, "Miniserver 1 Name before call: " . $miniservers[1]['Name'] . "\n");

$ms = LoxBerry\System\get_miniservers();
fwrite(STDERR, "Miniserver 1 Name after call: " . $miniservers[1]['Name'] . "\n");

$ms = LoxBerry\System\get_miniservers();
fwrite(STDERR, "Miniserver 1 Name second call: " . $miniservers[1]['Name'] . "\n");

$msnr = LoxBerry\System\get_miniserver_by_ip("192.168.0.77");
print "MSNr by IP: $msnr\n";

$msnr = LoxBerry\System\get_miniserver_by_name("MSOG");
print "MSNr by Name: $msnr\n";

$bin = LoxBerry\System\get_binaries();
print "GREP: " . $bin['GREP'] . "\n";

$version = LoxBerry\System\pluginversion();
print "Pluginversion: " . $version . "\n";

$ftpport = LoxBerry\System\get_ftpport();
print "FTP Port: " . $ftpport . "\n";

$localip = LoxBerry\System\get_localip();
print "IP: " . $localip . "\n";


?>

