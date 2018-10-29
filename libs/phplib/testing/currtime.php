<?php

require 'loxberry_system.php';


/*

 list($usec, $sec) = explode(' ', microtime());
 $usec = substr($usec, 2, 3); 
 echo date('H:i:s', $sec) . ".$usec  \n";

*/

echo "hr           : " . currtime() . "\n";
echo "hrtime       : " . currtime('hrtime') . "\n";
echo "hrtimehires  : " . currtime('hrtimehires') . "\n";
echo "file         : " . currtime('file') . "\n";
echo "filehires    : " . currtime('filehires') . "\n";
echo "iso          : " . currtime('iso') . "\n";



