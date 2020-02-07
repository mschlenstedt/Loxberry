<?php

require_once "loxberry_system.php";
 
$ms = LBSystem::get_miniservers();
if (!is_array($ms))
{
    echo "No Miniservers configured.\n";
}
  
foreach ($ms as $key => $miniserver)
{
    echo "Miniserver $key\n";
    $ftp = LBSystem::get_ftpport($key);
    echo "This Miniserver is named {$miniserver['Name']} and uses ip {$miniserver['IPAddress']}.\n";
    echo "CloudDNS: {$miniserver['UseCloudDNS']} PreferSSL: {$miniserver['PreferHttps']} PortHttps: {$miniserver['PortHttps']} FTP: $ftp\n";
    echo "FullURI: {$miniserver['FullURI']}\n";
}
