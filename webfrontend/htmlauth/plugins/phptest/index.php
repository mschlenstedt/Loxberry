<?php

require_once "loxberry_system.php";
require_once "loxberry_web.php";

$L = Web::readlanguage("language.ini");

$template_title = "Hello PHP! Plugin";
$helplink = "http://www.loxwiki.eu:80/x/_wFmAQ";
$helptemplate = "pluginhelp.html";

Web::lbheader($template_title, $helplink, $helptemplate);
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
echo "LoxBerry System Lib Version is " . $LBSYSTEMVERSION . "<br>";
echo "LoxBerry Web Lib Version is " . Web::$LBWEBVERSION . "<br>";

echo "Language: " . Web::lblanguage();
?>

<hr>
<p class="hint"><?=$L['CODE.INTRO']?></p>
<div class="monospace">
	<p><?=str_replace("\n", "<br>", htmlspecialchars(file_get_contents("$LBHTMLAUTHDIR/index.php")))?></p>
</div>

<?php
Web::lbfooter();
?>