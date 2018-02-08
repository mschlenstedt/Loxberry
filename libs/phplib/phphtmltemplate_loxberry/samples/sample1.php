<?
require_once("../template.php");

$template =& new Template("sample1.tmpl");

$template->AddParam('title', 'PHP Templates made easy');
$template->AddParam('body', 'Hello world!');

$template->EchoOutput();
?>