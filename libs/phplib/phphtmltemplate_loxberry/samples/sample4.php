<?
require_once("../template.php");

$options = array("filename"=>"sample4.tmpl", "debug"=>0);
$template =& new Template($options);

$template->AddParam('title', 'PHP Templates made easy');
$template->AddParam('loop',
                 array(
                 array('name'=>'Joe', 'age'=>'42',
                       'ex-wives'=>array(
                                   array('name'=>'Linda', 'age'=>'38'),
                                   array('name'=>'Tina', 'age'=>'42'),
                                   array('name'=>'Flora', 'age'=>'62')
                                   )
                      ),
                 array('name'=>'Max', 'age'=>'51',
                       'ex-wives'=>array(
                                   array('name'=>'Jocelyn', 'age'=>'49'),
                                   array('name'=>'Mandy', 'age'=>'22')
                                   )
                      )
                      )
                );

$template->EchoOutput();
?>