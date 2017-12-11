<?php
require_once("../template.php");

$options = array('filename'          => "sample8.tmpl",
                 'debug'             => 0,
                 'global_vars'       => 1,
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
         array("varname" => "12", "loopname" => &$loop2a),
         array("varname" => "34", "loopname" => &$loop2b));
         
$template->AddParam("the_loop", &$loop1);
$template->AddParam("caption", "Some text");
$template->AddParam("title", "Global vars example");

$template->EchoOutput();
?>