<?php
require_once("../template.php");

$options = array('filename'          => "sample6.tmpl",
                 'debug'             => 0,
                 'global_vars'       => 0,
                 'loop_context_vars' => 1);
                  
$template =& new Template($options);

$template->AddParam("error_msg", "<b>Warning:</b> no domains found");

$domains = array(
           array("domain"  => "example.com",
                 "date"    => "2001-12-02",
                 "credits" => 300,
                 "status"  => "1"),
           array("domain"  => "example.net",
                 "date"    => "2001-12-13",
                 "credits" => 450,
                 "status"  => "0"),
           array("domain"  => "example.org",
                 "date"    => "2001-12-15",
                 "credits" => 150,
                 "status"  => "0")
           );
$template->AddParam("domains", $domains);
$template->EchoOutput();
?>