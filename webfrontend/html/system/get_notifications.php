<?php
# Get notifications in html format 
# Quick and dirty
require_once "loxberry_web.php";
$cmd = "/usr/bin/perl  -I ".$lbshtmlauthdir." ".$lbshtmlauthdir."/get_notifications.cgi ".$_GET["package"]." ".$_GET["name"]."  2>&1";
passthru($cmd);
exit;
