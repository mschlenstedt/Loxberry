#!/usr/bin/php
<?php

require 'loxberry_system.php';

echo "TZ: " . date_default_timezone_get() . "\n";
echo "Epoch time:  " . time() . "\n";
echo "Loxone time: " . epoch2lox() . "\n";

echo "RESULT FROM PERL:\n";
echo `$lbhomedir/libs/perllib/LoxBerry/testing/epoch2lox.pl`;
