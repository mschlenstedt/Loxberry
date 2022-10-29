<?php

require_once "loxberry_web.php";
require_once "loxberry_log.php";

$helplink = "https://wiki.loxberry.de/";
$template_title = "Show all notifications";

LBWeb::lbheader($template_title, $helplink, $helptemplate);

echo LBLog::get_notifications_html();

LBWeb::lbfooter();

?>
