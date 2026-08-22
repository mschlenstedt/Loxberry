<?php
// testauth.php - loxberry_auth.php against a real Miniserver.
// Runs on a live LoxBerry.
//
//   php testauth.php [msnr|serial] [--store <path>] [--keep]
//
// Without --store the token is kept in /tmp so the productive
// data/system/tokens.json is not touched. Without --keep the token is revoked
// at the end - the Miniserver must not collect orphans in its token list.

require_once "loxberry_system.php";
set_include_path(get_include_path() . PATH_SEPARATOR . dirname(__DIR__));
require_once dirname(__DIR__) . "/loxberry_auth.php";

$args  = array_slice($argv, 1);
$ms    = (isset($args[0]) && substr($args[0], 0, 2) !== '--') ? array_shift($args) : 1;
$keep  = false;
$store = "/tmp/testauth_tokens_php.json";
while ($a = array_shift($args)) {
	if ($a === '--keep')  { $keep = true; }
	if ($a === '--store') { $store = array_shift($args); }
}
LBAuth::$store_file = $store;

echo "Miniserver : $ms\n";
echo "Token store: $store\n";
echo "auth_method: " . LBAuth::auth_method($ms) . "\n";

$failed = 0;
function step($name, $res) {
	global $failed;
	if (is_array($res) && !empty($res['ok'])) { echo "OK   $name\n"; return true; }
	$failed++;
	echo "FAIL $name: " . (isset($res['error']) ? $res['error'] : '?')
	   . " - " . (isset($res['message']) ? $res['message'] : '') . "\n";
	return false;
}

echo "\n=== get_token ===\n";
$t = LBAuth::get_token($ms, array('info' => 'LoxBerry Auth selftest PHP', 'force' => 1));
if (step('get_token', $t)) {
	printf("     serial     : %s\n", $t['serial']);
	printf("     firmware   : %s\n", $t['firmware']);
	printf("     perm       : %d (0x%x)\n", $t['perm'], $t['perm']);
	printf("     rights     : %d\n", $t['rights']);
	printf("     validUntil : %d (lox) = %s\n", $t['validUntil'],
	       date('Y-m-d H:i:s', lox2epoch($t['validUntil'])));
	$days = ($t['validUntil'] - epoch2lox()) / 86400;
	printf("     lifetime   : %.1f days%s\n", $days,
	       $days > 80 ? ' (matches the ~3 months measured for 0x104)' : ' (SHORTER THAN EXPECTED)');
	printf("     Sys-WS bit : %s\n",
	       LBAuth::_rights_granted($t['rights'], LBAuth::PERM_SYSWS)
	       ? 'granted - reboot would be allowed' : 'MISSING');
}

echo "\n=== token_info ===\n";
$ti = LBAuth::token_info($ms);
step('token_info', $ti);
if (!empty($ti['ok'])) { printf("     expires_in : %d s\n", $ti['expires_in']); }

echo "\n=== request /jdev/cfg/version ===\n";
list($content, $info) = LBAuth::request($ms, '/jdev/cfg/version');
if ($info['error'] == 0) {
	echo "OK   request (code " . $info['code'] . ")\n     $content\n";
} else {
	$failed++;
	echo "FAIL request: " . $info['errcode'] . " - " . $info['message'] . "\n";
}

echo "\n=== second request: the one-time key must be fetched again ===\n";
list($c2, $i2) = LBAuth::request($ms, '/jdev/cfg/version');
if ($i2['error'] == 0) { echo "OK   second request (code " . $i2['code'] . ")\n"; }
else { $failed++; echo "FAIL second request: " . $i2['errcode'] . " - " . $i2['message'] . "\n"; }

echo "\n=== refresh_token (password free) ===\n";
$rt = LBAuth::refresh_token($ms);
if (step('refresh_token', $rt)) {
	printf("     token      : %s...\n", substr($rt['token'], 0, 12));
	printf("     format     : %s\n", substr($rt['token'], 0, 3) === 'eyJ' ? 'JWT' : 'hex');
}

echo "\n=== request with the refreshed token ===\n";
list($c3, $i3) = LBAuth::request($ms, '/jdev/cfg/version');
if ($i3['error'] == 0) { echo "OK   request after refresh (code " . $i3['code'] . ")\n"; }
else { $failed++; echo "FAIL request after refresh: " . $i3['errcode'] . " - " . $i3['message'] . "\n"; }

echo "\n=== cleanup: kill_token ===\n";
if ($keep) {
	echo "SKIP --keep given - the token stays on the Miniserver\n";
} else {
	step('kill_token', LBAuth::kill_token($ms));
	$after = LBAuth::token_info($ms);
	if (empty($after['ok']) && $after['error'] === 'notoken') { echo "OK   store entry removed\n"; }
	else { $failed++; echo "FAIL store entry still present\n"; }
	// a request re-fetches a token automatically - that one has to go as well
	LBAuth::request($ms, '/jdev/cfg/version');
	LBAuth::kill_token($ms);
}

echo "\n" . ($failed ? "$failed STEP(S) FAILED\n" : "ALL STEPS OK\n");
exit($failed ? 1 : 0);
