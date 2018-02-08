<?
require_once("../template.php");

$options = array("filename"=>"sample5.tmpl", "debug"=>0);
$template =& new Template($options);

for ($i=0; $i<15; $i++) {
    $template->AddParam('cond'.($i+1), rand(0,1));
}
$template->AddParam('title', 'PHP Templates made easy');
$template->EchoOutput();

$template->ResetParams();
$template->ResetOutput();
for ($i=0; $i<15; $i++) {
    $template->AddParam('cond'.($i+1), rand(0,1));
}
$template->EchoOutput();
?>