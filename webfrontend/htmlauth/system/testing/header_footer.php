<?php

require_once "loxberry_web.php";

// This will read your language files to the array $L
//$template_title = "Top Plugin";
$helplink = "http://www.loxwiki.eu:80/x/2wzL";
$helptemplate = "help.html";
  
LBWeb::lbheader("Juhu", $helplink, $helptemplate);
 
// This is the main area for your plugin
?>
<p>Hello</p>
<?php 
// Finally print the footer 
LBWeb::lbfooter();
?>
