#!/usr/bin/env php
<?php
require_once "loxberry_system.php";

$ms = LBSystem::get_miniservers();
if (!is_array($ms))
{
    echo "No Miniservers configured.\n";
}
  
foreach ($ms as $miniserver)
{
    echo "This Miniserver is named {$miniserver['Name']} and uses ip {$miniserver['IPAddress']}.\n";
}

?>

