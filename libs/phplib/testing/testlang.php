#!/usr/bin/env php
<?php
require_once "loxberry_system.php";

$L = LBSystem::readlanguage(Null, "language.ini", True);

echo "Cancel-Button in current language: " . $L['COMMON.BUTTON_CANCEL'] . "\n";

?>