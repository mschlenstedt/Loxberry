<?php
require_once("../template.php");

$options = array('filename'          => "sample9.tmpl",
                 'debug'             => 0,
                 'global_vars'       => 1,
                 'case_sensitive'    => 0,
                 'loop_context_vars' => 1);

$template =& new Template($options);

$loop2a = array(
          array("varname2" => "qw"),
          array("varname2" => "er"),
          array("varname2" => "ty"));
         
$loop2b = array(
          array("varname2" => "as"),
          array("varname2" => "df"));

$loop1 = array(
         array("varname" => "12", "insideloop" => &$loop2a),
         array("varname" => "34", "insideloop" => &$loop2b));
         
$loop3 = array(
               array("one"=>"1", "two"=>"2"),
               array("two"=>"22"),
               array("one"=>"111")
              );
         
$template->AddParam("the_loop", &$loop1);
$template->AddParam("another_loop", &$loop3);
$template->AddParam("caption", "Some text");
$template->AddParam("title", "Global vars and defaults example");

$template->EchoOutput();
?>