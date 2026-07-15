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
