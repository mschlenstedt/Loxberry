<?
require_once("../template.php");

$options = array("filename"=>"sample3.tmpl", "debug"=>0);
$template =& new Template($options);

$template->AddParam('title', 'PHP Templates made easy');
$template->AddParam('loop', array(
                            array('name'=>'Joe', 'age'=>'42'),
                            array('name'=>'Max', 'age'=>'51')
                            )
                   );

$template->EchoOutput();
?>