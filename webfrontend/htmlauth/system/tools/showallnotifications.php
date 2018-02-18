<?php

require_once "loxberry_web.php";
require_once "loxberry_log.php";

$helplink = "http://www.loxwiki.eu/display/LOXBERRY/LoxBerry";
$template_title = "Show all notifications";

LBWeb::lbheader($template_title, $helplink, $helptemplate);

echo LBLog::get_notifications_html();

LBWeb::lbfooter();

?>