<?php

require_once "loxberry_system.php";
require_once "loxberry_web.php";


$template_title = "Hello PHP! Plugin";
$helplink = "http://www.loxwiki.eu:80/x/_wFmAQ";
$helptemplate = "pluginhelp.html";

Web::head();
Web::pagestart($template_title, $helplink, $helptemplate);

echo "LoxBerry Web Lib Version is " . Web::$LBWEBVERSION . "<br>";
echo "Language: " . Web::lblanguage();
echo LoxBerry\System\is_systemcall();
// Web::readlanguage();
Web::pageend();
Web::foot();




?>