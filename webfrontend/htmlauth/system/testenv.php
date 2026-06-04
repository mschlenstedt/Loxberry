<?php

require_once "loxberry_web.php";
require_once "Config/Lite.php";

##########################################################################
## Variables
###########################################################################
#
$helplink = "https://wiki.loxberry.de/konfiguration/widget_help/widget_loxberry_services/start";
$helptemplate = "help_services.html";
$template_title;
$error;

LBWeb::lbheader($template_title, $helplink, $helptemplate);

$tmp = exec(LBHOMEDIR."/sbin/testbashenv.sh");

if ($tmp === "") { $tmp = "nicht gesetzt"; }

echo "<p>Das System Configverzeichnis ist $tmp</p>";

LBWeb::lbfooter();
?>
