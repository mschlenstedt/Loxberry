<?php

require_once "loxberry_system.php";
require_once "loxberry_web.php";

$L = LBWeb::readlanguage("language.ini");

$template_title = "Hello PHP! Settings";
$helplink = "https://wiki.loxberry.de/";
$helptemplate = "pluginhelp.html";

$navbar[1]['Name'] = $L['NAVBAR.FIRST'];
$navbar[1]['URL'] = 'index.php';

$navbar[2]['Name'] = $L['NAVBAR.SECOND'];
$navbar[2]['URL'] = 'settings.php';

$navbar[3]['Name'] = $L['NAVBAR.THIRD'];
$navbar[3]['URL'] = 'http://www.loxberry.de';
$navbar[3]['target'] = '_blank';

// Activate the first element
$navbar[2]['active'] = True;

LBWeb::lbheader($template_title, $helplink, $helptemplate);
?>

<p><?=$L['SETTINGS.ULIKEIT']?></p>

<?php
LBWeb::lbfooter();
?>
