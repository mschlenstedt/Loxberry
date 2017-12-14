#!/usr/bin/env php
<?php
require_once "loxberry_system.php";

print "LBHOMEDIR using Constant: " . LBHOMEDIR . "\n";
print "LBHOMEDIR using variable: $LBHOMEDIR\n";

print "Loxberry System Module version is " . LBSystem::$LBSYSTEMVERSION . "\n";

print "Miniserver 1 Name before call: " . $miniservers[1]['Name'] . "\n";

$ms = LBSystem::get_miniservers();
print "Miniserver 1 Name after call: " . $miniservers[1]['Name'] . "\n";

$ms = LBSystem::get_miniservers();
print "Miniserver 1 Name second call: " . $miniservers[1]['Name'] . "\n";

$msnr = LBSystem::get_miniserver_by_ip("192.168.0.77");
print "MSNr by IP: $msnr\n";

$msnr = LBSystem::get_miniserver_by_name("MSOG");
print "MSNr by Name: $msnr\n";

$bin = LBSystem::get_binaries();
print "GREP: " . $bin['GREP'] . "\n";

$version = LBSystem::pluginversion();
print "Pluginversion: " . $version . "\n";

$ftpport = LBSystem::get_ftpport();
print "FTP Port: " . $ftpport . "\n";

$localip = LBSystem::get_localip();
print "IP: " . $localip . "\n";

$lbversion = LBSystem::lbversion();
print "LoxBerry Version: " . $lbversion . "\n";

$lbhostname = lbhostname();
print "LoxBerry Hostname: " . $lbhostname . "\n";

$lbfriendlyname = lbfriendlyname();
print "LoxBerry Friendly Name: " . $lbfriendlyname . "\n";

print "Is enabled? " . is_enabled("true") . " (this should be 1)\n";
print "Is disabled? " . is_disabled("off") . " (this should be 1)\n";

print "Plugin list:\n";
$myplugins = LBSystem::get_plugins();
foreach($plugins as $plugin) {
	print "Nr. {$plugin['PLUGINDB_NO']}: {$plugin['PLUGINDB_TITLE']} version {$plugin['PLUGINDB_VERSION']} Icon-URI: {$plugin['PLUGINDB_ICONURI']}\n";
}

?>

