<?php
// test_auth_unit.php - offline unit tests for loxberry_auth.php.
// No Miniserver needed; the transport hook is replaced by a fake.
// Run with an own LBHOMEDIR so the productive installation is untouched:
//   LBHOMEDIR=/tmp/authhome php test_auth_unit.php

$failed = 0;
$count  = 0;
function t_is($got, $exp, $name) {
	global $failed, $count;
	$count++;
	if ($got == $exp) { echo "ok $count - $name\n"; return; }
	$failed++;
	echo "not ok $count - $name (got " . var_export($got, true)
	   . ", expected " . var_export($exp, true) . ")\n";
}
function t_ok($cond, $name) { t_is($cond ? 1 : 0, 1, $name); }

$home = getenv("LBHOMEDIR");
if (!$home || strpos($home, "/tmp/") !== 0) {
	fwrite(STDERR, "Refusing to run without a throwaway LBHOMEDIR below /tmp\n");
	exit(2);
}
@mkdir("$home/config/system", 0755, true);
@mkdir("$home/data/system", 0755, true);
file_put_contents("$home/config/system/general.json", <<<'GENERALJSON'
{
  "Base": { "Lang": "de", "Version": "4.0.0.15" },
  "Miniserver": {
    "1": {
      "Name": "Miniserver", "Ipaddress": "192.0.2.10",
      "Admin": "loxberry", "Pass": "TestPass%2123",
      "Port": 80, "Porthttps": 443, "Preferhttps": 0
    },
    "2": {
      "Name": "MS Secure", "Ipaddress": "192.0.2.11",
      "Admin": "admin", "Pass": "secret",
      "Port": 80, "Porthttps": 4443, "Preferhttps": 1,
      "Authmethod": "token"
    },
    "3": {
      "Name": "MS IPv6", "Ipaddress": "fe80::1",
      "Admin": "admin", "Pass": "secret",
      "Port": 80, "Porthttps": 443, "Preferhttps": 0,
      "Authmethod": "basicauth"
    }
  }
}
GENERALJSON
);

// The include_path is derived from LBHOMEDIR, which we just replaced by a
// throwaway directory - so point PHP at the lib copy we are testing.
set_include_path(get_include_path() . PATH_SEPARATOR . dirname(__DIR__));
require_once dirname(__DIR__) . "/loxberry_auth.php";

LBAuth::$store_file = "$home/data/system/tokens.json";
@unlink(LBAuth::$store_file);

// --- _norm_alg -------------------------------------------------------------
t_is( LBAuth::_norm_alg('SHA256'),  'SHA256', 'norm_alg SHA256' );
t_is( LBAuth::_norm_alg('sha-256'), 'SHA256', 'norm_alg sha-256 normalisiert' );
t_is( LBAuth::_norm_alg('SHA1'),    'SHA1',   'norm_alg SHA1' );
t_is( LBAuth::_norm_alg(null),      'SHA1',   'norm_alg leer faellt auf SHA1 zurueck' );
t_is( LBAuth::_norm_alg('MD5'),     null,     'norm_alg unbekannt ist null' );

// --- Hash-Kette, dieselben Referenzwerte wie im Perl-Test ------------------
$KEY = '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
$pw256 = LBAuth::_pw_hash('Test1234', '41B0A8F1', 'SHA256');
t_is( $pw256, '3E4A5D209675FD7633320D7F1AA5B399174D2B397ABE4FE53118FCECE38A847D', 'pw_hash SHA256' );
t_is( LBAuth::_auth_hash('loxberry', $pw256, $KEY, 'SHA256'),
      '31db6348ae60d52f53381bc3ebf2b7b1691a55e51110ef31ac50b19b1b2f9f47', 'auth_hash SHA256' );
t_is( LBAuth::_token_hash('a1b2c3d4e5f60718293a4b5c6d7e8f90', $KEY, 'SHA256'),
      '7c75d4ea7111e124200e9939ded8f9d2ece6835089a4d5ff1fb6d96e57b6dd65', 'token_hash SHA256' );
$pw1 = LBAuth::_pw_hash('Test1234', '41B0A8F1', 'SHA1');
t_is( $pw1, '3A09820F277977B59FE88D032BBC7ECF5C2C7BCD', 'pw_hash SHA1' );
t_is( LBAuth::_auth_hash('loxberry', $pw1, $KEY, 'SHA1'),
      'dde0f27175043736346411f693364a2bee2c0308', 'auth_hash SHA1' );
t_is( LBAuth::_token_hash('a1b2c3d4e5f60718293a4b5c6d7e8f90', $KEY, 'SHA1'),
      '9135606ae0eac2862b8536f0adc059cf57fd7e62', 'token_hash SHA1' );

// --- _parse_api_value ------------------------------------------------------
$apival = "{'snr': 'AB:CD:EF:01:02:03', 'version':'17.1.7.3', 'hasEventSlots':true, "
        . "'isInTrust':false, 'local':true,'certTLD':'com'}";
$api = LBAuth::_parse_api_value($apival);
t_is( $api['snr'],     'AB:CD:EF:01:02:03', 'parse_api_value snr' );
t_is( $api['version'], '17.1.7.3',          'parse_api_value version' );
t_is( $api['certTLD'], 'com',               'parse_api_value certTLD' );
t_is( $api['local'],   'true',              'parse_api_value unquotierter Wert' );
t_is( LBAuth::_parse_api_value(''),   null, 'parse_api_value leer' );
t_is( LBAuth::_parse_api_value(null), null, 'parse_api_value null' );

// --- _fw_supported ---------------------------------------------------------
t_is( LBAuth::_fw_supported('17.1.7.3'),   1, 'fw 17.1.7.3 unterstuetzt' );
t_is( LBAuth::_fw_supported('11.2.10.22'), 1, 'fw exakt am Floor unterstuetzt' );
t_is( LBAuth::_fw_supported('11.2.10.21'), 0, 'fw knapp unter Floor abgelehnt' );
t_is( LBAuth::_fw_supported('11.2.9.99'),  0, 'fw aeltere Patchlinie abgelehnt' );
t_is( LBAuth::_fw_supported('12.0'),       1, 'fw mit weniger Stellen unterstuetzt' );
t_is( LBAuth::_fw_supported(''),           0, 'fw leer abgelehnt' );

// --- _rights_granted -------------------------------------------------------
t_is( LBAuth::_rights_granted(1924, LBAuth::PERM_SYSWS), 1, 'Sys-WS in 1924 enthalten' );
t_is( LBAuth::_rights_granted(1924, LBAuth::PERM_APP),   1, 'App in 1924 enthalten' );
t_is( LBAuth::_rights_granted(4,    LBAuth::PERM_SYSWS), 0, 'Sys-WS fehlt im reinen App-Token' );
t_is( LBAuth::_rights_granted(1924, 0x104),              1, 'kombiniertes Bitmuster' );

// --- Konstanten ------------------------------------------------------------
t_is( LBAuth::$DEFAULT_PERM,      0x104,        'Standard-Permission App+Sys-WS' );
t_is( LBAuth::$REFRESH_THRESHOLD, 7*86400,      'Erneuerungsschwelle 7 Tage' );
t_is( LBAuth::$MIN_FIRMWARE,      '11.2.10.22', 'Firmware-Floor' );

// --- Store -----------------------------------------------------------------
t_is( LBAuth::_store_file(), "$home/data/system/tokens.json", 'store_file folgt dem Testhaken' );
t_is( LBAuth::_store_read(), array(), 'fehlende Datei liefert leeres Array' );
t_ok( !file_exists(LBAuth::$store_file), 'Lesen legt die Datei nicht an' );
t_is( LBAuth::_store_get_token('AB:CD:EF:01:02:03', 'loxberry'), null, 'get_token auf leerem Bestand' );

$msmeta = array( 'msnr' => 1, 'name' => 'Miniserver', 'is_lbsystem' => true,
                 'lbsystem_user' => 'loxberry', 'firmware' => '17.1.7.3', 'checked' => 556606212 );
$tok = array( 'token' => 'abc123', 'validUntil' => 564559554, 'rights' => 1924,
              'perm' => 260, 'acquired' => 556606212, 'info' => 'LoxBerry testhost' );
t_is( LBAuth::_store_put_token('AB:CD:EF:01:02:03', 'loxberry', $msmeta, $tok), 1, 'erstes put schreibt' );
t_ok( file_exists(LBAuth::$store_file), 'Datei wurde angelegt' );
clearstatcache();
t_is( substr(sprintf('%o', fileperms(LBAuth::$store_file)), -4), '0600', 'Datei hat Rechte 0600' );

$got = LBAuth::_store_get_token('AB:CD:EF:01:02:03', 'loxberry');
t_is( $got['token'],      'abc123',  'Token gelesen' );
t_is( $got['validUntil'], 564559554, 'validUntil gelesen' );

$raw = json_decode(file_get_contents(LBAuth::$store_file), true);
t_is( $raw['AB:CD:EF:01:02:03']['name'],     'Miniserver', 'Miniserver-Metadaten auf oberster Ebene' );
t_is( $raw['AB:CD:EF:01:02:03']['firmware'], '17.1.7.3',   'firmware gespeichert' );
t_ok( isset($raw['AB:CD:EF:01:02:03']['users']['loxberry']), 'Benutzer unter users' );
t_ok( !isset($raw['AB:CD:EF:01:02:03']['users']['loxberry']['password']), 'kein Passwort im Bestand' );
t_ok( !isset($raw['AB:CD:EF:01:02:03']['users']['loxberry']['key']),      'kein Einmalschluessel im Bestand' );

clearstatcache();
$mtime_before = filemtime(LBAuth::$store_file);
sleep(1);
t_is( LBAuth::_store_put_token('AB:CD:EF:01:02:03', 'loxberry', $msmeta, $tok), 0, 'unveraendertes put schreibt nicht' );
clearstatcache();
t_is( filemtime(LBAuth::$store_file), $mtime_before, 'mtime unveraendert' );

$tok2 = $tok; $tok2['token'] = 'def456';
t_is( LBAuth::_store_put_token('AB:CD:EF:01:02:03', 'loxberry', $msmeta, $tok2), 1, 'geaendertes put schreibt' );
$g2 = LBAuth::_store_get_token('AB:CD:EF:01:02:03', 'loxberry');
t_is( $g2['token'], 'def456', 'neuer Token gelesen' );

LBAuth::_store_put_token('AB:CD:EF:01:02:03', 'sortmgr', $msmeta, $tok);
$gs = LBAuth::_store_get_token('AB:CD:EF:01:02:03', 'sortmgr');
$gl = LBAuth::_store_get_token('AB:CD:EF:01:02:03', 'loxberry');
t_is( $gs['token'], 'abc123', 'zweiter Benutzer' );
t_is( $gl['token'], 'def456', 'erster Benutzer unberuehrt' );
t_is( LBAuth::_store_del_token('AB:CD:EF:01:02:03', 'sortmgr'), 1, 'del schreibt' );
t_is( LBAuth::_store_get_token('AB:CD:EF:01:02:03', 'sortmgr'), null, 'Eintrag ist weg' );
t_is( LBAuth::_store_del_token('AB:CD:EF:01:02:03', 'sortmgr'), 0, 'zweites del schreibt nicht' );

file_put_contents(LBAuth::$store_file, "{ das ist kein json");
t_is( LBAuth::_store_read(), array(), 'unlesbare Datei liefert leeres Array' );
@unlink(LBAuth::$store_file);

// --- _err ------------------------------------------------------------------
$e = LBAuth::_err('unreachable', 'timed out');
t_is( $e['ok'],      0,             'err ok ist 0' );
t_is( $e['error'],   'unreachable', 'err code' );
t_is( $e['message'], 'timed out',   'err message' );

// --- _resolve_ms -----------------------------------------------------------
$r = LBAuth::_resolve_ms(1);
t_is( $r['ok'],            1,                         'resolve MS 1 ok' );
t_is( $r['msnr'],          1,                         'msnr' );
t_is( $r['name'],          'Miniserver',              'name' );
t_is( $r['baseurl'],       'http://192.0.2.10:80', 'baseurl http' );
t_is( $r['user'],          'loxberry',                'Benutzer aus general.json' );
t_is( $r['password'],      'TestPass!23',              'Passwort aus Pass_RAW, nicht aus Pass' );
t_is( $r['lbsystem_user'], 'loxberry',                'lbsystem_user' );
$r2 = LBAuth::_resolve_ms(2);
$r3 = LBAuth::_resolve_ms(3);
t_is( $r2['baseurl'], 'https://192.0.2.11:4443', 'baseurl https mit eigenem Port' );
t_is( $r3['baseurl'], 'http://[fe80::1]:80',        'IPv6 in eckigen Klammern' );

$ru = LBAuth::_resolve_ms(1, array('user' => 'sortmgr', 'password' => 'geheim'));
t_is( $ru['user'],     'sortmgr', 'uebergebener Benutzer' );
t_is( $ru['password'], 'geheim',  'uebergebenes Passwort' );
$rnp = LBAuth::_resolve_ms(1, array('user' => 'sortmgr'));
t_is( $rnp['password'], null, 'kein Rueckfall auf das Passwort aus general.json' );

$e9 = LBAuth::_resolve_ms(9);
$en = LBAuth::_resolve_ms(null);
$ee = LBAuth::_resolve_ms('');
$es = LBAuth::_resolve_ms('AB:CD:EF:01:02:03');
t_is( $e9['error'], 'msnotfound', 'MS 9 nicht konfiguriert' );
t_is( $en['error'], 'msnotfound', 'null ist msnotfound' );
t_is( $ee['error'], 'msnotfound', 'leer ist msnotfound' );
t_is( $es['error'], 'msnotfound', 'unbekannte Seriennummer' );

LBAuth::_store_put_token('AB:CD:EF:01:02:03', 'loxberry',
	array('msnr' => 1, 'name' => 'Miniserver', 'firmware' => '17.1.7.3'),
	array('token' => 'abc', 'validUntil' => 1, 'rights' => 1924));
$rs = LBAuth::_resolve_ms('AB:CD:EF:01:02:03');
$rl = LBAuth::_resolve_ms('ab:cd:ef:01:02:03');
t_is( $rs['ok'],     1,                   'bekannte Seriennummer loest auf' );
t_is( $rs['msnr'],   1,                   'Seriennummer -> msnr 1' );
t_is( $rs['serial'], 'AB:CD:EF:01:02:03', 'serial durchgereicht' );
t_is( $rl['msnr'],   1,                   'Seriennummer gross geschrieben verglichen' );

// --- auth_method -----------------------------------------------------------
t_is( LBAuth::auth_method(1), 'basicauth', 'fehlender Authmethod-Schluessel ist basicauth' );
t_is( LBAuth::auth_method(2), 'token',     'Authmethod token' );
t_is( LBAuth::auth_method(3), 'basicauth', 'Authmethod basicauth' );
t_is( LBAuth::auth_method(9), 'basicauth', 'unbekannter Miniserver ist basicauth' );
t_is( LBAuth::auth_method('AB:CD:EF:01:02:03'), 'basicauth', 'auth_method ueber die Seriennummer' );


// ==========================================================================
// Ablaeufe mit Fake-Transport
// ==========================================================================
@unlink(LBAuth::$store_file);
// the process cache outlives the file - clear it, otherwise a token from the
// store section above answers here
LBAuth::_cache_clear();

$KEY2 = '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
$TOKHASH = '3b50109633af4140485302f72bd8a2734950286ca29a4633ef6c54376540bd69';
$calls = array();
$optlog = array();
$behaviour = array(
	'api_fw' => '17.1.7.3', 'api_serial' => 'AB:CD:EF:01:02:03',
	'gettoken' => 'ok', 'rights' => 1924, 'validUntil' => 999999999,
	'unreachable_all' => 0, 'refresh' => 'ok', 'kill' => 'ok', 'cmd_401_once' => 0,
);

LBAuth::$transport = function ($url, $opts) use (&$calls, &$optlog, &$behaviour, $KEY2) {
	$calls[]  = $url;
	$optlog[] = array('url' => $url, 'opts' => $opts);
	if ($behaviour['unreachable_all']) { return array(null, null, 'Connection refused'); }

	if (preg_match('#/jdev/cfg/api$#', $url)) {
		$v = "{'snr': '" . $behaviour['api_serial'] . "', 'version':'" . $behaviour['api_fw']
		   . "', 'hasEventSlots':true, 'isInTrust':false, 'local':true,'certTLD':'com'}";
		return array(200, '{"LL": { "control": "dev/cfg/api", "value": "' . $v . '", "Code": "200"}}', '200 OK');
	}
	if (strpos($url, '/jdev/sys/getkey2/') !== false) {
		return array(200, '{"LL":{"control":"dev/sys/getkey2","code":"200","value":{"key":"'
		           . $KEY2 . '","salt":"41B0A8F1","hashAlg":"SHA256"}}}', '200 OK');
	}
	if (strpos($url, '/jdev/sys/gettoken/') !== false) {
		if ($behaviour['gettoken'] == 'unreachable') { return array(null, null, 'Connection refused'); }
		if ($behaviour['gettoken'] == '401') { return array(401, '<html><body>401</body></html>', '401 Unauthorized'); }
		return array(200, '{"LL":{"control":"dev/sys/gettoken","code":"200","value":{"token":"tokTESTVALUE123","key":"'
		           . $KEY2 . '","validUntil":' . $behaviour['validUntil'] . ',"tokenRights":'
		           . $behaviour['rights'] . ',"unsecurePass":false}}}', '200 OK');
	}
	if (strpos($url, '/jdev/sys/refreshjwt/') !== false) {
		if ($behaviour['refresh'] == '401') { return array(401, '<html>401</html>', '401 Unauthorized'); }
		// Am echten Miniserver gemessen: HTTP 200, aber LL.code 401
		if ($behaviour['refresh'] == 'll401') {
			return array(200, '{"LL":{"control":"dev/sys/refreshjwt","value":{},"code":"401"}}', '200 OK');
		}
		return array(200, '{"LL":{"control":"dev/sys/refreshjwt","code":"200","value":{"token":"eyJ0eXAiTESTJWT","validUntil":'
		           . $behaviour['validUntil'] . ',"tokenRights":1924,"unsecurePass":false}}}', '200 OK');
	}
	if (strpos($url, '/jdev/sys/killtoken/') !== false) {
		if ($behaviour['kill'] == '401') { return array(401, '<html>401</html>', '401 Unauthorized'); }
		return array(200, '{"LL":{"control":"dev/sys/killtoken","code":"200","value":"1"}}', '200 OK');
	}
	if (strpos($url, 'autht=') !== false) {
		if ($behaviour['cmd_401_once'] > 0) {
			$behaviour['cmd_401_once']--;
			return array(401, '<html>401</html>', '401 Unauthorized');
		}
		return array(200, '{"LL":{"control":"dev/sps/io/Test","code":"200","value":"42"}}', '200 OK');
	}
	return array(404, 'not found', '404 Not Found');
};

// --- _ll_value / _ll_code / _effective_code -------------------------------
$llv = LBAuth::_ll_value('{"LL":{"value":{"a":1},"Code":"200"}}');
t_is( $llv['a'], 1, 'll_value Array' );
t_is( LBAuth::_ll_value('{"LL":{"value":"text","Code":"200"}}'), 'text', 'll_value String' );
t_is( LBAuth::_ll_value('<html>kaputt</html>'), null, 'll_value auf HTML ist null' );
t_is( LBAuth::_ll_value(''), null, 'll_value auf leer ist null' );
t_is( LBAuth::_ll_code('{"LL":{"value":{},"code":"401"}}'), 401, 'll_code liest kleines code' );
t_is( LBAuth::_ll_code('{"LL":{"value":"x","Code":"200"}}'), 200, 'll_code liest grosses Code' );
t_is( LBAuth::_ll_code('<html>401</html>'), null, 'll_code auf HTML ist null' );
t_is( LBAuth::_effective_code(200, '{"LL":{"value":{},"code":"401"}}'), 401,
      'HTTP 200 mit LL-Code 401 zaehlt als 401' );
t_is( LBAuth::_effective_code(200, '{"LL":{"value":"x","Code":"200"}}'), 200, 'sauberer 200 bleibt 200' );
t_is( LBAuth::_effective_code(401, '<html>401</html>'), 401, 'echter HTTP-Fehler bleibt' );

// --- _client_uuid ----------------------------------------------------------
$uuid = LBAuth::_client_uuid('loxberry');
t_ok( preg_match('/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/', $uuid), 'client_uuid hat UUID-Form' );
t_is( LBAuth::_client_uuid('loxberry'), $uuid, 'client_uuid ist stabil' );
t_ok( LBAuth::_client_uuid('sortmgr') != $uuid, 'client_uuid je Benutzer verschieden' );

// --- _ms_api ---------------------------------------------------------------
$api2 = LBAuth::_ms_api(LBAuth::_resolve_ms(1));
t_is( $api2['ok'],       1,                   'ms_api ok' );
t_is( $api2['serial'],   'AB:CD:EF:01:02:03', 'Seriennummer aus cfg/api' );
t_is( $api2['firmware'], '17.1.7.3',          'Firmware aus cfg/api' );

// --- get_token, Gutfall ----------------------------------------------------
$calls = array();
$t = LBAuth::get_token(1);
t_is( $t['ok'],         1,                   'get_token ok' );
t_is( $t['token'],      'tokTESTVALUE123',   'Token' );
t_is( $t['validUntil'], 999999999,           'validUntil' );
t_is( $t['rights'],     1924,                'rights' );
t_is( $t['perm'],       260,                 'perm ist der Standard 0x104 = 260' );
t_is( $t['serial'],     'AB:CD:EF:01:02:03', 'Seriennummer' );
t_is( $t['firmware'],   '17.1.7.3',          'Firmware' );

$gettoken_url = '';
foreach ($calls as $c) { if (strpos($c, '/jdev/sys/gettoken/') !== false) { $gettoken_url = $c; } }
t_ok( strpos($gettoken_url,
      '/jdev/sys/gettoken/6811aac909afa7d530fd1cf87a28e4a9db15ad4e99eea57b33944319b05a86c5/loxberry/260/') !== false,
      'authHash, Benutzer und perm stehen korrekt in der URL' );

$stored = LBAuth::_store_get_token('AB:CD:EF:01:02:03', 'loxberry');
t_is( $stored['token'], 'tokTESTVALUE123', 'Token persistiert' );
t_ok( !isset($stored['key']),      'Einmalschluessel nicht persistiert' );
t_ok( !isset($stored['password']), 'Passwort nicht persistiert' );

$calls = array();
$tc = LBAuth::get_token(1);
t_is( $tc['token'], 'tokTESTVALUE123', 'zweiter Aufruf liefert denselben Token' );
t_is( count($calls), 0, 'zweiter Aufruf macht keinen HTTP-Request' );

$calls = array();
LBAuth::get_token(1, array('force' => 1));
t_ok( count($calls) >= 2, 'force holt neu' );
$tser = LBAuth::get_token('AB:CD:EF:01:02:03');
t_is( $tser['ok'], 1, 'get_token ueber die Seriennummer' );

// --- Fehlerfaelle ----------------------------------------------------------
$behaviour['rights'] = 4;
$tr = LBAuth::get_token(1, array('force' => 1));
t_is( $tr['error'], 'missingright', 'fehlendes Recht ist missingright' );
$behaviour['rights'] = 1924;

$behaviour['gettoken'] = '401';
$tb = LBAuth::get_token(1, array('force' => 1));
t_is( $tb['error'], 'badcredentials',
      'badcredentials - der 401 kommt bei gettoken, nicht bei getkey2' );
$behaviour['gettoken'] = 'ok';

$behaviour['api_fw'] = '11.2.10.21';
$calls = array();
$tf = LBAuth::get_token(1, array('force' => 1));
t_is( $tf['error'], 'fwtooold', 'zu alte Firmware ist fwtooold' );
$syscalls = 0;
foreach ($calls as $c) { if (strpos($c, '/jdev/sys/') !== false) { $syscalls++; } }
t_is( $syscalls, 0, 'bei zu alter Firmware wird kein Token angefragt' );
$behaviour['api_fw'] = '17.1.7.3';

$behaviour['unreachable_all'] = 1;
$tu = LBAuth::get_token(1, array('force' => 1));
t_is( $tu['error'], 'unreachable', 'nicht erreichbar' );
$behaviour['unreachable_all'] = 0;

$calls = array();
$tn = LBAuth::get_token(1, array('user' => 'sortmgr'));
t_is( $tn['error'], 'nocredentials', 'fremder Benutzer ohne Passwort ist nocredentials' );
t_is( count($calls), 0, 'ohne Passwort wird gar nicht erst gefragt' );

$tx = LBAuth::get_token(1, array('user' => 'sortmgr', 'password' => 'geheim', 'perm' => 0x04));
t_is( $tx['ok'],   1,         'fremder Benutzer mit Passwort bekommt einen Token' );
t_is( $tx['perm'], 4,         'uebergebene Permission wird verwendet' );
t_is( $tx['user'], 'sortmgr', 'Token gehoert dem fremden Benutzer' );

// --- token_info / request / refresh / kill ---------------------------------
LBAuth::_store_put_token('AB:CD:EF:01:02:03', 'loxberry',
	array('msnr' => 1, 'name' => 'Miniserver', 'firmware' => '17.1.7.3'),
	array('token' => 'tokTESTVALUE123', 'validUntil' => epoch2lox() + 60*86400,
	      'rights' => 1924, 'perm' => 260, 'acquired' => 1, 'info' => 'LoxBerry testhost'));

$ti = LBAuth::token_info(1);
t_is( $ti['ok'],     1,                   'token_info ok' );
t_is( $ti['token'],  'tokTESTVALUE123',   'token_info Token' );
t_is( $ti['serial'], 'AB:CD:EF:01:02:03', 'token_info Seriennummer' );
t_ok( $ti['expires_in'] > 59*86400, 'token_info Restlaufzeit' );
$tni = LBAuth::token_info(1, array('user' => 'niemand'));
t_is( $tni['error'], 'notoken', 'token_info ohne Bestand' );

$calls = array();
list($content, $info) = LBAuth::request(1, '/jdev/sps/io/Test');
t_is( $info['code'],  200, 'request code 200' );
t_is( $info['error'], 0,   'request error 0' );
t_ok( strpos($content, '"value":"42"') !== false, 'request liefert den Body' );
$cmd_url = '';
foreach ($calls as $c) { if (strpos($c, '/jdev/sps/io/Test') !== false) { $cmd_url = $c; } }
t_ok( strpos($cmd_url, '?autht=' . $TOKHASH . '&user=loxberry') !== false,
      'autht traegt den Token-Hash, user haengt an' );

$calls = array();
LBAuth::request(1, '/jdev/sps/io/Test?state=on');
$q_url = '';
foreach ($calls as $c) { if (strpos($c, '/jdev/sps/io/Test') !== false) { $q_url = $c; } }
t_ok( strpos($q_url, '?state=on&autht=') !== false, 'vorhandener Query-String wird mit & ergaenzt' );

$calls = array();
$behaviour['cmd_401_once'] = 1;
list($c2, $i2) = LBAuth::request(1, '/jdev/sps/io/Test');
t_is( $i2['error'], 0, '401 fuehrt zu einem erfolgreichen zweiten Versuch' );
$behaviour['cmd_401_once'] = 2;
list($c3, $i3) = LBAuth::request(1, '/jdev/sps/io/Test');
t_is( $i3['errcode'], 'revoked', 'zweimal 401 ist revoked' );
$behaviour['cmd_401_once'] = 0;

LBAuth::_store_put_token('AB:CD:EF:01:02:03', 'loxberry', array('msnr' => 1),
	array('token' => 'tokTESTVALUE123', 'validUntil' => epoch2lox() + 3*86400,
	      'rights' => 1924, 'perm' => 260, 'acquired' => 1, 'info' => 'x'));
$calls = array();
LBAuth::request(1, '/jdev/sps/io/Test');
$refreshcalls = 0;
foreach ($calls as $c) { if (strpos($c, '/jdev/sys/refreshjwt/') !== false) { $refreshcalls++; } }
t_is( $refreshcalls, 1, 'Restlaufzeit unter 7 Tagen loest refreshjwt aus' );
$after = LBAuth::_store_get_token('AB:CD:EF:01:02:03', 'loxberry');
t_is( $after['token'], 'eyJ0eXAiTESTJWT', 'der erneuerte JWT ersetzt den alten Token im Bestand' );

$rt = LBAuth::refresh_token(1);
t_is( $rt['ok'],    1,                 'refresh_token ok' );
t_is( $rt['token'], 'eyJ0eXAiTESTJWT', 'refresh_token liefert den JWT' );

// autht traegt den Klartext-Token, der Pfad den Hash
$calls = array();
LBAuth::refresh_token(1);
$rj_url = '';
foreach ($calls as $c) { if (strpos($c, '/jdev/sys/refreshjwt/') !== false) { $rj_url = $c; } }
t_ok( preg_match('#/jdev/sys/refreshjwt/[0-9a-f]{64}/loxberry\?autht=#', $rj_url),
      'refreshjwt: Token-Hash im Pfad' );
t_ok( strpos($rj_url, 'autht=eyJ0eXAiTESTJWT&') !== false,
      'refreshjwt: autht ist der Klartext-Token, nicht der Hash' );

$behaviour['refresh'] = '401';
$r401 = LBAuth::refresh_token(1);
t_is( $r401['error'], 'revoked', '401 bei refreshjwt ist revoked' );
$behaviour['refresh'] = 'll401';
$rll = LBAuth::refresh_token(1);
t_is( $rll['error'], 'revoked', 'HTTP 200 mit LL-Code 401 wird als Ablehnung erkannt' );
$behaviour['refresh'] = 'ok';

$knp = LBAuth::kill_token(1, array('user' => 'sortmgr'));
t_is( $knp['error'], 'nopassword', 'kill_token ohne Passwort' );
$optlog = array();
$kt = LBAuth::kill_token(1);
t_is( $kt['ok'], 1, 'kill_token mit dem Passwort aus general.json' );
$killopts = null;
foreach ($optlog as $o) { if (strpos($o['url'], '/jdev/sys/killtoken/') !== false) { $killopts = $o['opts']; } }
t_is( $killopts['basicauth_user'],     'loxberry',   'killtoken nutzt Basic-Auth' );
t_is( $killopts['basicauth_password'], 'TestPass!23', 'Basic-Auth mit dem Klartext-Passwort' );
t_is( LBAuth::_store_get_token('AB:CD:EF:01:02:03', 'loxberry'), null, 'Eintrag nach kill_token entfernt' );

// --- Prozess-Cache ---------------------------------------------------------
LBAuth::_cache_clear();
LBAuth::_store_put_token('AA:BB:CC:DD:EE:FF', 'cacheuser', array('msnr' => 1),
	array('token' => 'cached1', 'validUntil' => 5, 'rights' => 1924));
@unlink(LBAuth::$store_file);
$cc = LBAuth::_store_get_token('AA:BB:CC:DD:EE:FF', 'cacheuser');
t_is( $cc['token'], 'cached1', 'get_token bedient sich aus dem Prozess-Cache' );
LBAuth::_cache_clear();
t_is( LBAuth::_store_get_token('AA:BB:CC:DD:EE:FF', 'cacheuser'), null,
      'ohne Cache und ohne Datei ist nichts mehr da' );
LBAuth::_store_put_token('AA:BB:CC:DD:EE:FF', 'cacheuser', array('msnr' => 1),
	array('token' => 'cached2', 'validUntil' => 5, 'rights' => 1924));
$cc2 = LBAuth::_store_get_token('AA:BB:CC:DD:EE:FF', 'cacheuser');
t_is( $cc2['token'], 'cached2', 'put aktualisiert den Cache' );
LBAuth::_store_del_token('AA:BB:CC:DD:EE:FF', 'cacheuser');
t_is( LBAuth::_store_get_token('AA:BB:CC:DD:EE:FF', 'cacheuser'), null, 'del raeumt den Cache mit' );

echo "
1..$count
";
echo $failed ? "$failed FAILED
" : "ALL OK
";
exit($failed ? 1 : 0);
