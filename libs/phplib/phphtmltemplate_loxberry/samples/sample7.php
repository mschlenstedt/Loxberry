<?php
require_once("../template.php");
$template =& new template(array("filename"=>"sample7.tmpl", "loop_context_vars"=>1, "debug"=>0));

for ($i=32; $i<256; $i++) {
    $chars[] = array("char"=>chr($i), "ascii"=>$i);
}

$template->AddParam("chars", &$chars);
$template->AddParam("title", "ISO 8859-1 (should be)");
$template->EchoOutput();
?>