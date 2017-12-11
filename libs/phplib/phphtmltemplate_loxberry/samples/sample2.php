<?
require_once("../template.php");

$options = array("filename"=>"sample2.tmpl", "debug"=>0);
$template =& new Template($options);

$template->AddParam('title', 'PHP Templates made easy');
$template->AddParam('msg1', 'Condition is true :)');
$template->AddParam('msg2', 'Condition is false :(');
$template->AddParam('condition', '1');

$template->EchoOutput();
?>