<?php

require_once "loxberry_json.php";
$cfg = new LBJSON("/opt/loxberry/config/system/general.json");
echo "Sendstatistic: " . $cfg->Base->Sendstatistic . "\n";

$cfg->Base->Sendstatistic = "off";
echo "Sendstatistic:     " . $cfg->Base->Sendstatistic . "\n";




echo $cfg->filename() . "\n";

$cfg->write();