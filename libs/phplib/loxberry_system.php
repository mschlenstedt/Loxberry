<?php

# define Constants for LoxBerry directories

if(getenv("LBHOMEDIR")) {
	define("LBHOMEDIR", getenv("LBHOMEDIR"));
} 
elseif (posix_getpwuid(posix_getpwnam('loxberry')['uid'])['dir']) {
		define("LBHOMEDIR", posix_getpwuid(posix_getpwnam('loxberry')['uid'])['dir']);
}
else {
	fwrite(STDERR, "LoxBerry System WARNING: Falling back to /opt/loxberry\n");
	define("LBHOMEDIR", '/opt/loxberry');
}

$pluginname = explode("/", substr(getcwd(), strlen(LBHOMEDIR)))[4];
define ("LBPLUGINDIR", $pluginname);
unset($pluginname);

fwrite(STDERR, "LoxBerry System Info: LBHOMEDIR: " . LBHOMEDIR . "\n");
fwrite(STDERR, "LoxBerry System Info: LBPLUGINDIR: " . LBPLUGINDIR . "\n");

# Defining globals
define ("LBCGIDIR", LBHOMEDIR . "/webfrontend/cgi/plugins/" . LBPLUGINDIR);
define ("LBHTMLDIR", LBHOMEDIR . "/webfrontend/html/plugins/" . LBPLUGINDIR);
define ("LBTEMPLATEDIR", LBHOMEDIR . "/templates/plugins/" . LBPLUGINDIR);
define ("LBDATADIR", LBHOMEDIR . "/data/plugins/" . LBPLUGINDIR);
define ("LBLOGDIR", LBHOMEDIR . "/log/plugins/" . LBPLUGINDIR);
define ("LBCONFIGDIR", LBHOMEDIR . "/config/plugins/" . LBPLUGINDIR);

# As globals in PHP cannot be concentrated in strings, we additionally define variables
$LBHOMEDIR = LBHOMEDIR;
$LBPLUGINDIR = LBPLUGINDIR;
$LBCGIDIR = LBCGIDIR;
$LBHTMLDIR = LBHTMLDIR;
$LBTEMPLATEDIR = LBTEMPLATEDIR;
$LBDATADIR = LBDATADIR;
$LBLOGDIR = LBLOGDIR;
$LBCONFIGDIR = LBCONFIGDIR;



?>
