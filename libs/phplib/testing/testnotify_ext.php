#!/usr/bin/env php
<?php
require_once "loxberry_log.php";
  
$notification = array (
            "PACKAGE" => "test",                  // Mandatory
            "NAME" => "daemon",                          // Mandatory           
            "MESSAGE" => "error connecting to the Miniserver", // Mandatory
            "SEVERITY" => 3,
            "fullerror" => "Access is denied: " . $error,
            "msnumber" => 1,
            "logfile" => LBPLOGDIR . "/mylogfile.log"
    );
 
notify_ext( $notification );

?>
