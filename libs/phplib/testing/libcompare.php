<?php
/*
 * libcompare.php - PHP side of the Perl<->PHP library parity test.
 *
 * Emits one line per test case in the form:
 *     @@<testname>@@<single-line-json>
 *
 * The companion Perl emitter (../../perllib/LoxBerry/testing/libcompare.pl)
 * produces the identical set of testnames; libcompare_run.py runs both and
 * compares the JSON per test case (a few volatile keys are ignored).
 *
 * Functions under test are the ports from the Perl master libs:
 *   System : bytes_humanreadable, systemloglevel, diskspaceinfo,
 *            check_securepin, lock, unlock
 *   Web    : iso_languages
 *   Log    : get_notification_count, get_logs
 *   IO     : mshttp_call2
 *   Storage: get_netshares, get_netservers, get_usbstorage, get_storage
 *
 * Runs on the live LoxBerry (PHP 7.4). Read-only where possible;
 * check_securepin uses an invalid PIN with the counter file reset
 * around the call, lock/unlock use a dedicated test lockfile name.
 */

error_reporting(E_ERROR | E_PARSE); // silence notices/warnings, keep stdout clean

$HOME = getenv("LBHOMEDIR") ? getenv("LBHOMEDIR") : "/opt/loxberry";

require_once "$HOME/libs/phplib/loxberry_system.php";
require_once "$HOME/libs/phplib/loxberry_web.php";
require_once "$HOME/libs/phplib/loxberry_log.php";
require_once "$HOME/libs/phplib/loxberry_io.php";
require_once "$HOME/libs/phplib/loxberry_storage.php";

$SECPIN_ERRFILE = "$HOME/log/system_tmpfs/securepin.errors";

function emit($name, $data) {
	echo "@@" . $name . "@@" . json_encode($data) . "\n";
}

/////////////////////////////////////////////
// System::bytes_humanreadable
/////////////////////////////////////////////
$cases = array(
	array(0, ''), array(1, ''), array(1023, ''), array(1024, ''), array(1025, ''),
	array(1048576, ''), array(1500000, ''), array(1073741824, ''),
	array(137, 'K'), array(1536, 'K'), array(123124, 'K'),
	array(2, 'M'), array(2, 'G'), array(1, 'T'), array(0, 'K'),
);
$res = array();
foreach ($cases as $c) {
	$res[] = LBSystem::bytes_humanreadable($c[0], $c[1]);
}
emit('bytes_humanreadable', $res);

/////////////////////////////////////////////
// System::systemloglevel
/////////////////////////////////////////////
emit('systemloglevel', array('value' => LBSystem::systemloglevel()));

/////////////////////////////////////////////
// System::diskspaceinfo (single folder "/")
/////////////////////////////////////////////
emit('diskspaceinfo_root', LBSystem::diskspaceinfo("/"));

/////////////////////////////////////////////
// Web::iso_languages
/////////////////////////////////////////////
emit('iso_languages_values', LBWeb::iso_languages(false, 'values'));
emit('iso_languages_labels', LBWeb::iso_languages(false, 'labels'));
emit('iso_languages_values_avail', LBWeb::iso_languages(true, 'values'));

/////////////////////////////////////////////
// Log::get_notification_count
/////////////////////////////////////////////
$nc = LBLog::get_notification_count();
emit('get_notification_count', array('count' => array(
	isset($nc[0]) ? (int)$nc[0] : null,
	isset($nc[1]) ? (int)$nc[1] : null,
	isset($nc[2]) ? (int)$nc[2] : null,
)));

/////////////////////////////////////////////
// Log::get_logs (unfiltered)
/////////////////////////////////////////////
emit('get_logs', LBLog::get_logs());

/////////////////////////////////////////////
// IO::mshttp_call2 (Miniserver 1, harmless read command)
/////////////////////////////////////////////
// Leading slash so FullURI (which may lack a trailing slash) + command
// yields a well-formed URL on both sides (curl rejects a malformed one).
list($body, $ri) = mshttp_call2(1, "/jdev/cfg/version");
emit('mshttp_call2_ms1', array('responseinfo' => $ri));

/////////////////////////////////////////////
// Storage::get_netservers / get_netshares / get_usbstorage / get_storage
/////////////////////////////////////////////
emit('get_netservers', get_netservers());
emit('get_netshares', get_netshares());
emit('get_usbstorage', get_usbstorage(''));
emit('get_storage', get_storage());

/////////////////////////////////////////////
// System::check_securepin (invalid PIN, counter reset around the call)
/////////////////////////////////////////////
if (file_exists($SECPIN_ERRFILE)) { @unlink($SECPIN_ERRFILE); }
$r = LBSystem::check_securepin("zzz_invalid_pin_zzz");
emit('check_securepin_invalid', array('result' => $r === null ? null : (int)$r));
if (file_exists($SECPIN_ERRFILE)) { @unlink($SECPIN_ERRFILE); }

/////////////////////////////////////////////
// System::lock / unlock (dedicated test lockfile)
/////////////////////////////////////////////
LBSystem::unlock(array('lockfile' => 'libcompare_test'));
$rlock   = LBSystem::lock(array('lockfile' => 'libcompare_test', 'wait' => 0));
$runlock = LBSystem::unlock(array('lockfile' => 'libcompare_test'));
emit('lock_unlock', array('lock' => $rlock, 'unlock' => $runlock));

/////////////////////////////////////////////
// Auth (pure functions)
/////////////////////////////////////////////
set_include_path(get_include_path() . PATH_SEPARATOR . dirname(__DIR__));
require_once dirname(__DIR__) . "/loxberry_auth.php";

$auth_key  = '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
$auth_apiv = "{'snr': 'AB:CD:EF:01:02:03', 'version':'17.1.7.3', 'hasEventSlots':true, "
           . "'isInTrust':false, 'local':true,'certTLD':'com'}";

$auth_algs = array();
foreach (array('SHA256', 'sha-256', 'SHA1', '', 'MD5') as $a) { $auth_algs[] = LBAuth::_norm_alg($a); }
emit('auth_norm_alg', $auth_algs);

$auth_pw256 = LBAuth::_pw_hash('Test1234', '41B0A8F1', 'SHA256');
$auth_pw1   = LBAuth::_pw_hash('Test1234', '41B0A8F1', 'SHA1');
emit('auth_hashes', array(
	'pw_sha256'    => $auth_pw256,
	'pw_sha1'      => $auth_pw1,
	'auth_sha256'  => LBAuth::_auth_hash('loxberry', $auth_pw256, $auth_key, 'SHA256'),
	'auth_sha1'    => LBAuth::_auth_hash('loxberry', $auth_pw1, $auth_key, 'SHA1'),
	'token_sha256' => LBAuth::_token_hash('a1b2c3d4e5f60718293a4b5c6d7e8f90', $auth_key, 'SHA256'),
	'token_sha1'   => LBAuth::_token_hash('a1b2c3d4e5f60718293a4b5c6d7e8f90', $auth_key, 'SHA1'),
));

emit('auth_parse_api_value', LBAuth::_parse_api_value($auth_apiv));

$auth_fw = array();
foreach (array('17.1.7.3', '11.2.10.22', '11.2.10.21', '11.2.9.99', '12.0', '') as $f) {
	$auth_fw[] = LBAuth::_fw_supported($f);
}
emit('auth_fw_supported', $auth_fw);

emit('auth_rights_granted', array(
	LBAuth::_rights_granted(1924, 0x100),
	LBAuth::_rights_granted(1924, 0x04),
	LBAuth::_rights_granted(4,    0x100),
	LBAuth::_rights_granted(1924, 0x104),
));

emit('auth_ll_codes', array(
	LBAuth::_ll_code('{"LL":{"value":{},"code":"401"}}'),
	LBAuth::_ll_code('{"LL":{"value":"x","Code":"200"}}'),
	LBAuth::_ll_code('<html>401</html>'),
	LBAuth::_effective_code(200, '{"LL":{"value":{},"code":"401"}}'),
	LBAuth::_effective_code(200, '{"LL":{"value":"x","Code":"200"}}'),
	LBAuth::_effective_code(401, '<html>401</html>'),
));

emit('auth_constants', array(
	'default_perm'      => LBAuth::$DEFAULT_PERM,
	'refresh_threshold' => LBAuth::$REFRESH_THRESHOLD,
	'min_firmware'      => LBAuth::$MIN_FIRMWARE,
	'perm_app'          => LBAuth::PERM_APP,
	'perm_sysws'        => LBAuth::PERM_SYSWS,
));

$auth_ms = LBSystem::get_miniservers();
emit('auth_ms_baseurl', isset($auth_ms[1]) ? LBAuth::_ms_baseurl($auth_ms[1]) : null);
emit('auth_auth_method_ms1', LBAuth::auth_method(1));
