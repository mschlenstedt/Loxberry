<?php

require_once "loxberry_system.php";
require_once "loxberry_web.php";

$L = LBWeb::readlanguage("language.ini");

$template_title = "Hello PHP! Plugin";
$helplink = "http://www.loxwiki.eu:80/x/_wFmAQ";
$helptemplate = "pluginhelp.html";

LBWeb::lbheader($template_title, $helplink, $helptemplate);
?>

<h1><?=$L['MAIN.TITLE']?></h1>
<p><?=$L['MAIN.INTRO']?></p>
<p><?=$L['MAIN.USAGE1']?></p>
<p><?=$L['MAIN.USAGE2']?></p>
<p><?=$L['MAIN.HELP']?></p>
<p></p>
<p><b><?=$L['MAIN.FINALMESSAGE']?></b></p>
<h2><?=$L['SIGNATURE.SIGN']?></h2>
<p class="wide"><?=$L['SIGNATURE.SLOGAN']?></p>
<p></p>

<?php 
echo "LoxBerry System Lib Version is " . LBSystem::$LBSYSTEMVERSION . "<br>";
echo "LoxBerry Web Lib Version is " . LBWeb::$LBWEBVERSION . "<br>";

echo "Language: " . LBWeb::lblanguage();
?>

<hr>
<p class="hint"><?=$L['CODE.INTRO']?></p>
<div class="monospace">
	<p><?=str_replace("\n", "<br>", htmlspecialchars(file_get_contents("$LBHTMLAUTHDIR/index.php")))?></p>
</div>

<?php
LBWeb::lbfooter();
?>