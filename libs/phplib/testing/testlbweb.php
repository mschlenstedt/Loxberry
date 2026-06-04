#!/usr/bin/env php
<?php
require_once "loxberry_web.php";

// Test HTML output
$mshtml = LBWeb::mslist_select_html( ['FORMID' => 'msno', 'SELECTED' => 2,  ]);
echo $mshtml;

?>
