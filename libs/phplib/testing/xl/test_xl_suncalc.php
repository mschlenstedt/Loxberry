#!/usr/bin/env php
<?php
require_once "loxberry_XL.php";
echo "\nMinOfDay: " . $xl->minofday;


// https://github.com/gregseth/suncalc-php

$sun->gps(time(), 48.315032, 14.230722);

echo "\nSunrise: " . $sun->sunTimes('sunrise');
$sun->timeformat('time');
echo "\nSunrise: " . $sun->sunTimes('sunrise', 'epoch');
echo "\nCurrent sun pos: " . $sun->sunPosition('altitude');

$sunrise = $sun->sunTimes('sunrise', 'epoch');
$sun->gps('21.2.2020 21:00');
echo "\nSun alt at moring: " . $sun->sunPosition('altitude');
echo "\nSun azimuth at moring: " . $sun->sunPosition('azimuth');


echo "\n";


?>

