<?php
// loxberry_auth.php - token authentication at the Loxone Miniserver.
// Port of libs/perllib/LoxBerry/Auth.pm - same method names, same array keys.
// PHP 7.4 compatible (that is the version on the target systems).

require_once "loxberry_system.php";

class LBAuth
{
	public static $VERSION = "4.0.0.1";
	public static $DEBUG = 0;

	// Permission bits of the Miniserver token API
	const PERM_ADMIN = 0x01;
	const PERM_WEB   = 0x02;
	const PERM_APP   = 0x04;
	const PERM_SYSWS = 0x100;

	// App + Sys-WS: ~3 months lifetime, includes the right to reboot
	public static $DEFAULT_PERM = 0x104;
	// Renew as soon as less than this many seconds are left
	public static $REFRESH_THRESHOLD = 604800;
	public static $TIMEOUT = 10;
	// Below this firmware the token endpoints need application layer encryption
	public static $MIN_FIRMWARE = "11.2.10.22";

	// Test hooks
	public static $store_file = null;
	public static $transport  = null;

	private static function dbg($msg)
	{
		if (self::$DEBUG) { error_log("loxberry_auth: " . $msg); }
	}

	####################################################
	# Pure helpers - no I/O, no state
	####################################################

	// An empty hashAlg means SHA1 (Miniservers before the field existed)
	public static function _norm_alg($alg)
	{
		$alg = ($alg === null) ? '' : strtoupper($alg);
		$alg = preg_replace('/[^A-Z0-9]/', '', $alg);
		if ($alg === '' || $alg === 'SHA1') { return 'SHA1'; }
		if ($alg === 'SHA256') { return 'SHA256'; }
		return null;
	}

	public static function _hash_hex($alg, $data)
	{
		return hash($alg === 'SHA256' ? 'sha256' : 'sha1', $data);
	}

	// The key from getkey2 is hex encoded and used as raw bytes
	public static function _hmac_hex($alg, $data, $keyhex)
	{
		return hash_hmac($alg === 'SHA256' ? 'sha256' : 'sha1', $data, hex2bin($keyhex));
	}

	// The Miniserver expects the password hash in uppercase
	public static function _pw_hash($password, $salt, $alg)
	{
		return strtoupper(self::_hash_hex($alg, $password . ':' . $salt));
	}

	public static function _auth_hash($user, $pwhash, $keyhex, $alg)
	{
		return self::_hmac_hex($alg, $user . ':' . $pwhash, $keyhex);
	}

	public static function _token_hash($token, $keyhex, $alg)
	{
		return self::_hmac_hex($alg, $token, $keyhex);
	}

	// jdev/cfg/api returns its value as a STRING using single quotes - that is
	// not valid JSON and must not be fed to json_decode.
	public static function _parse_api_value($value)
	{
		if ($value === null || $value === '') { return null; }
		$out = array();
		if (preg_match_all("/'([^']+)'\\s*:\\s*(?:'([^']*)'|([^,}\\s]+))/", $value, $m, PREG_SET_ORDER)) {
			foreach ($m as $one) {
				$out[$one[1]] = ($one[2] !== '') ? $one[2] : (isset($one[3]) ? $one[3] : $one[2]);
			}
		}
		return count($out) ? $out : null;
	}

	public static function _fw_supported($fw)
	{
		if ($fw === null || $fw === '') { return 0; }
		$is  = explode('.', $fw);
		$min = explode('.', self::$MIN_FIRMWARE);
		for ($i = 0; $i < 4; $i++) {
			$a = isset($is[$i])  ? intval($is[$i])  : 0;
			$b = isset($min[$i]) ? intval($min[$i]) : 0;
			if ($a > $b) { return 1; }
			if ($a < $b) { return 0; }
		}
		return 1;
	}

	// tokenRights is a bitmask; perm 0x104 was measured to return 1924
	public static function _rights_granted($rights, $bit)
	{
		if ($rights === null || $bit === null) { return 0; }
		return ((intval($rights) & intval($bit)) == intval($bit)) ? 1 : 0;
	}

	####################################################
	# Token store - data/system/tokens.json, 0600, owner loxberry
	####################################################

	public static function _store_file()
	{
		if (self::$store_file) { return self::$store_file; }
		global $lbsdatadir;
		if (!empty($lbsdatadir)) { return $lbsdatadir . "/tokens.json"; }
		return null;
	}

	private static function _ksort_deep(&$a)
	{
		if (!is_array($a)) { return; }
		ksort($a);
		foreach ($a as $k => $v) {
			if (is_array($v)) { self::_ksort_deep($a[$k]); }
		}
	}

	private static function _store_decode($content)
	{
		if ($content === null || trim($content) === '') { return array(); }
		$data = json_decode($content, true);
		if (!is_array($data)) {
			self::dbg("tokens.json is not readable JSON - starting empty");
			return array();
		}
		return $data;
	}

	private static function _store_encode($data)
	{
		$copy = $data;
		self::_ksort_deep($copy);
		return json_encode($copy, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
	}

	// Read the full store under a shared lock. A missing file is an empty
	// store and is NOT created here.
	public static function _store_read()
	{
		$file = self::_store_file();
		if (!$file || !file_exists($file)) { return array(); }
		$fh = @fopen($file, 'r');
		if (!$fh) { return array(); }
		@flock($fh, LOCK_SH);
		$content = stream_get_contents($fh);
		@flock($fh, LOCK_UN);
		fclose($fh);
		return self::_store_decode($content);
	}

	// Read-modify-write under ONE exclusive lock. $cb must take the store BY
	// REFERENCE: function (&$data) { ... }
	// Returns 1 = written, 0 = unchanged, null = error.
	public static function _store_update($cb)
	{
		$file = self::_store_file();
		if (!$file) { self::dbg("no token store path available"); return null; }

		$fh = @fopen($file, 'c+');
		if (!$fh) { self::dbg("cannot open $file"); return null; }
		if (!flock($fh, LOCK_EX)) { fclose($fh); return null; }

		$content = stream_get_contents($fh);
		$data    = self::_store_decode($content);
		$before  = self::_store_encode($data);

		$cb($data);

		$after = self::_store_encode($data);
		if ($after === $before && trim($content) !== '') {
			@flock($fh, LOCK_UN);
			fclose($fh);
			return 0;
		}

		rewind($fh);
		ftruncate($fh, 0);
		fwrite($fh, $after);
		fflush($fh);
		@flock($fh, LOCK_UN);
		fclose($fh);

		@chmod($file, 0600);
		@chown($file, 'loxberry');
		return 1;
	}

	// Process cache: the token lives in the process, the file is pure
	// persistence across restarts. The single 401 retry in request() covers
	// the case that another process changed the file behind our back.
	private static $tokencache = array();

	public static function _cache_clear()
	{
		self::$tokencache = array();
		return 1;
	}

	public static function _store_get_token($serial, $user)
	{
		if (!$serial || !$user) { return null; }
		$ck = "$serial|$user";
		if (array_key_exists($ck, self::$tokencache)) { return self::$tokencache[$ck]; }

		$data = self::_store_read();
		if (!isset($data[$serial]['users'][$user])) { return null; }
		self::$tokencache[$ck] = $data[$serial]['users'][$user];
		return self::$tokencache[$ck];
	}

	public static function _store_put_token($serial, $user, $msmeta, $tokendata)
	{
		if (!$serial || !$user) { return null; }
		self::$tokencache["$serial|$user"] = $tokendata;
		return self::_store_update(function (&$data) use ($serial, $user, $msmeta, $tokendata) {
			if (!isset($data[$serial])) { $data[$serial] = array(); }
			foreach ($msmeta as $k => $v) { $data[$serial][$k] = $v; }
			if (!isset($data[$serial]['users'])) { $data[$serial]['users'] = array(); }
			$data[$serial]['users'][$user] = $tokendata;
		});
	}

	public static function _store_del_token($serial, $user)
	{
		if (!$serial || !$user) { return null; }
		unset(self::$tokencache["$serial|$user"]);
		return self::_store_update(function (&$data) use ($serial, $user) {
			if (isset($data[$serial]['users'][$user])) {
				unset($data[$serial]['users'][$user]);
			}
		});
	}

	####################################################
	# Result objects
	####################################################

	public static function _err($code, $message)
	{
		self::dbg("$code - $message");
		return array('ok' => 0, 'error' => $code, 'message' => $message);
	}

	####################################################
	# Miniserver resolution
	####################################################

	public static function _ms_baseurl($msc)
	{
		if (!$msc) { return null; }
		$transport = !empty($msc['Transport']) ? $msc['Transport'] : 'http';
		$port = ($transport == 'https') ? $msc['PortHttps'] : $msc['Port'];
		if (!$port) { $port = ($transport == 'https') ? 443 : 80; }
		$ip = $msc['IPAddress'];
		if (strpos($ip, ':') !== false) { $ip = '[' . $ip . ']'; }
		return "$transport://$ip:$port";
	}

	// Accepts a Miniserver number or a serial. A serial is resolved through the
	// token store. With a user but without a password the password stays null
	// on purpose - the password from general.json belongs to that user only.
	public static function _resolve_ms($ms, $opts = array())
	{
		if ($ms === null || $ms === '') { return self::_err('msnotfound', 'No Miniserver given'); }

		$serial = null;
		$msnr   = null;
		if (preg_match('/^\d+$/', (string)$ms)) {
			$msnr = intval($ms);
		} else {
			$serial = strtoupper($ms);
			$data = self::_store_read();
			if (isset($data[$serial]['msnr'])) { $msnr = $data[$serial]['msnr']; }
			if ($msnr === null) {
				return self::_err('msnotfound',
					"Serial $ms is unknown - fetch a token for this Miniserver first");
			}
		}

		$miniservers = LBSystem::get_miniservers();
		if (!isset($miniservers[$msnr])) {
			return self::_err('msnotfound', "Miniserver $ms is not configured");
		}
		$msc = $miniservers[$msnr];

		$user = isset($opts['user']) ? $opts['user'] : $msc['Admin_RAW'];
		if (isset($opts['password'])) {
			$password = $opts['password'];
		} else {
			$password = isset($opts['user']) ? null : $msc['Pass_RAW'];
		}

		return array(
			'ok'            => 1,
			'msnr'          => $msnr,
			'name'          => $msc['Name'],
			'baseurl'       => self::_ms_baseurl($msc),
			'user'          => $user,
			'password'      => $password,
			'serial'        => $serial,
			'is_lbsystem'   => 1,
			'lbsystem_user' => $msc['Admin_RAW'],
		);
	}

	####################################################
	# general.json: Authmethod (read only - never written by this lib)
	####################################################

	public static function auth_method($ms)
	{
		if ($ms === null || $ms === '') { return 'basicauth'; }

		$msnr = $ms;
		if (!preg_match('/^\d+$/', (string)$ms)) {
			$data = self::_store_read();
			$serial = strtoupper($ms);
			if (!isset($data[$serial]['msnr'])) { return 'basicauth'; }
			$msnr = $data[$serial]['msnr'];
		}

		global $lbsconfigdir;
		$raw = @file_get_contents("$lbsconfigdir/general.json");
		if ($raw === false) { return 'basicauth'; }
		$cfg = json_decode($raw, true);
		if (!is_array($cfg)) { return 'basicauth'; }

		if (isset($cfg['Miniserver'][$msnr]['Authmethod'])
		    && strtolower($cfg['Miniserver'][$msnr]['Authmethod']) === 'token') {
			return 'token';
		}
		return 'basicauth';
	}

	####################################################
	# HTTP transport
	# Verified on Miniserver 17.1.7.3: jdev/cfg/api and jdev/sys/getkey2 answer
	# without any authentication. Only killtoken needs Basic Auth.
	####################################################

	public static function _http_get($url, $opts = array())
	{
		$ch = curl_init($url);
		curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
		curl_setopt($ch, CURLOPT_HEADER, false);
		curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
		curl_setopt($ch, CURLOPT_SSL_VERIFYHOST, 0);
		curl_setopt($ch, CURLOPT_TIMEOUT, isset($opts['timeout']) ? $opts['timeout'] : self::$TIMEOUT);
		if (isset($opts['basicauth_user'])) {
			curl_setopt($ch, CURLOPT_HTTPAUTH, CURLAUTH_BASIC);
			curl_setopt($ch, CURLOPT_USERPWD, $opts['basicauth_user'] . ':'
			            . (isset($opts['basicauth_password']) ? $opts['basicauth_password'] : ''));
		}
		$body = curl_exec($ch);
		$code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
		$err  = curl_error($ch);
		curl_close($ch);
		// no connection at all -> code 0
		if ($body === false || !$code) { return array(null, null, $err ? $err : 'no connection'); }
		return array(intval($code), $body, strval($code));
	}

	public static function _call($url, $opts = array())
	{
		self::dbg("GET $url");
		$t = self::$transport ? self::$transport : array('LBAuth', '_http_get');
		return call_user_func($t, $url, $opts);
	}

	// The LL envelope. value is an array for most endpoints and a string for
	// jdev/cfg/api. A non-JSON body (the Miniserver answers 401 in HTML) is null.
	public static function _ll_value($body)
	{
		if ($body === null || trim($body) === '') { return null; }
		$j = json_decode($body, true);
		if (!is_array($j) || !isset($j['LL']) || !is_array($j['LL'])) { return null; }
		return isset($j['LL']['value']) ? $j['LL']['value'] : null;
	}

	// The LL envelope carries its OWN status code, and the Miniserver does not
	// always mirror it into the HTTP status: refreshjwt answers HTTP 200 with
	// LL.code 401 when the token signature is not accepted. Measured on 17.1.7.3.
	// The field is spelled "Code" by some endpoints (jdev/cfg/api) and "code" by
	// others (jdev/sys/*), so both are read.
	public static function _ll_code($body)
	{
		if ($body === null || trim($body) === '') { return null; }
		$j = json_decode($body, true);
		if (!is_array($j) || !isset($j['LL']) || !is_array($j['LL'])) { return null; }
		$c = isset($j['LL']['code']) ? $j['LL']['code'] : (isset($j['LL']['Code']) ? $j['LL']['Code'] : null);
		if ($c === null || !preg_match('/^\d+$/', (string)$c)) { return null; }
		return intval($c);
	}

	// The code that really decides: an HTTP 200 carrying a different LL code is
	// a failure, not a success.
	public static function _effective_code($code, $body)
	{
		if ($code === null || $code != 200) { return $code; }
		$ll = self::_ll_code($body);
		if ($ll !== null && $ll != 200) { return $ll; }
		return $code;
	}

	// Stable per host and user, so the Miniserver does not collect a new client
	// entry on every call. Derived, never persisted.
	public static function _client_uuid($user)
	{
		$h = hash('sha256', lbhostname() . '|' . $user . '|loxberry-auth');
		return substr($h,0,8) . '-' . substr($h,8,4) . '-' . substr($h,12,4) . '-'
		     . substr($h,16,4) . '-' . substr($h,20,12);
	}

	####################################################
	# Miniserver identity: serial + firmware in one call
	####################################################

	public static function _ms_api($res, $opts = array())
	{
		list($code, $body) = self::_call($res['baseurl'] . '/jdev/cfg/api', $opts);
		if ($code === null) { return self::_err('unreachable', $res['baseurl'] . ' did not answer'); }
		$code = self::_effective_code($code, $body);
		if ($code != 200)   { return self::_err('httperror', "jdev/cfg/api returned $code"); }

		$api = self::_parse_api_value(self::_ll_value($body));
		if (!$api) { return self::_err('parseerror', 'jdev/cfg/api could not be parsed'); }
		if (empty($api['snr'])) { return self::_err('parseerror', 'jdev/cfg/api has no serial'); }

		return array('ok' => 1, 'serial' => strtoupper($api['snr']),
		             'firmware' => isset($api['version']) ? $api['version'] : '');
	}

	public static function _getkey2($res, $user, $opts = array())
	{
		$url = $res['baseurl'] . '/jdev/sys/getkey2/' . rawurlencode($user);
		list($code, $body) = self::_call($url, $opts);
		if ($code === null) { return self::_err('unreachable', $res['baseurl'] . ' did not answer'); }
		$code = self::_effective_code($code, $body);
		if ($code == 401)   { return self::_err('badcredentials', "getkey2 returned $code for user $user"); }
		if ($code != 200)   { return self::_err('httperror', "getkey2 returned $code"); }

		$v = self::_ll_value($body);
		if (!is_array($v)) { return self::_err('parseerror', 'getkey2 could not be parsed'); }
		$alg = self::_norm_alg(isset($v['hashAlg']) ? $v['hashAlg'] : null);
		if (!$alg) { return self::_err('parseerror', 'getkey2 returned an unknown hashAlg'); }
		return array('ok' => 1, 'key' => $v['key'], 'salt' => $v['salt'], 'alg' => $alg);
	}

	// The serial of a Miniserver number, as far as an earlier run persisted it.
	// Looking it up here keeps get_token free of HTTP when a token is cached.
	public static function _serial_from_store($msnr)
	{
		$data = self::_store_read();
		foreach ($data as $s => $entry) {
			if (isset($entry['msnr']) && $entry['msnr'] == $msnr) {
				return array($s, isset($entry['firmware']) ? $entry['firmware'] : null);
			}
		}
		return array(null, null);
	}

	// Like _resolve_ms, but an unknown serial makes every configured Miniserver
	// be asked for its own serial. That is the only way a serial enters the store.
	public static function _resolve_ms_probing($ms, $opts = array())
	{
		$res = self::_resolve_ms($ms, $opts);
		if ($res['ok']) { return $res; }
		if (preg_match('/^\d+$/', (string)$ms)) { return $res; }

		$want = strtoupper($ms);
		$miniservers = LBSystem::get_miniservers();
		$keys = array_keys($miniservers);
		sort($keys);
		foreach ($keys as $msnr) {
			$cand = self::_resolve_ms($msnr, $opts);
			if (!$cand['ok']) { continue; }
			$api = self::_ms_api($cand, $opts);
			if (!$api['ok'] || $api['serial'] !== $want) { continue; }
			$cand['serial']   = $want;
			$cand['firmware'] = $api['firmware'];
			return $cand;
		}
		return self::_err('msnotfound', "No configured Miniserver has serial $ms");
	}

	####################################################
	# get_token
	####################################################

	public static function get_token($ms, $opts = array())
	{
		$res = self::_resolve_ms_probing($ms, $opts);
		if (!$res['ok']) { return $res; }

		$user = $res['user'];
		if (!$user) { return self::_err('nocredentials', "No user for Miniserver $ms"); }

		$perm = isset($opts['perm']) ? intval($opts['perm']) : self::$DEFAULT_PERM;

		// The serial is stable and may come from the store - that is what keeps
		// a cached token completely free of HTTP.
		$serial   = $res['serial'];
		$firmware = isset($res['firmware']) ? $res['firmware'] : null;
		if (!$serial) {
			list($s, $f) = self::_serial_from_store($res['msnr']);
			$serial = $s;
			if (!$firmware) { $firmware = $f; }
		}

		if (empty($opts['force']) && $serial) {
			$have = self::_store_get_token($serial, $user);
			if ($have && !empty($have['token']) && self::_rights_granted($have['rights'], $perm)) {
				return array('ok' => 1, 'token' => $have['token'], 'validUntil' => $have['validUntil'],
				             'rights' => $have['rights'], 'perm' => $have['perm'], 'user' => $user,
				             'serial' => $serial, 'firmware' => $firmware, 'msnr' => $res['msnr']);
			}
		}

		// Without a password nothing can be fetched - check that before
		// bothering the Miniserver with a single request.
		$password = $res['password'];
		if ($password === null || $password === '') {
			return self::_err('nocredentials', "No password available for user $user");
		}

		// From here on a token is really fetched. Unlike the serial the
		// firmware changes with every Miniserver update, so it is never taken
		// from the store.
		if (!isset($res['firmware'])) {
			$api = self::_ms_api($res, $opts);
			if (!$api['ok']) { return $api; }
			$serial   = $api['serial'];
			$firmware = $api['firmware'];
		}

		if (!self::_fw_supported($firmware)) {
			return self::_err('fwtooold', "Miniserver firmware $firmware is below "
			       . self::$MIN_FIRMWARE . " - tokens would need application encryption");
		}

		$k = self::_getkey2($res, $user, $opts);
		if (!$k['ok']) { return $k; }

		$pwhash   = self::_pw_hash($password, $k['salt'], $k['alg']);
		$authhash = self::_auth_hash($user, $pwhash, $k['key'], $k['alg']);
		$info     = isset($opts['info']) ? $opts['info'] : 'LoxBerry ' . lbhostname();

		$url = $res['baseurl'] . '/jdev/sys/gettoken/' . $authhash . '/' . rawurlencode($user)
		     . '/' . $perm . '/' . self::_client_uuid($user) . '/' . rawurlencode($info);

		list($code, $body) = self::_call($url, $opts);
		if ($code === null) { return self::_err('unreachable', $res['baseurl'] . ' did not answer'); }
		$code = self::_effective_code($code, $body);
		// A wrong user or password shows up HERE, not at getkey2
		if ($code == 401) { return self::_err('badcredentials', "gettoken returned 401 for user $user"); }
		if ($code != 200) { return self::_err('httperror', "gettoken returned $code"); }

		$v = self::_ll_value($body);
		if (!is_array($v) || empty($v['token'])) { return self::_err('parseerror', 'gettoken could not be parsed'); }

		if (!self::_rights_granted($v['tokenRights'], $perm)) {
			return self::_err('missingright', sprintf(
				"Miniserver granted rights %s, which does not include the requested permission %d (0x%x)",
				$v['tokenRights'], $perm, $perm));
		}

		$tokendata = array(
			'token' => $v['token'], 'validUntil' => $v['validUntil'], 'rights' => $v['tokenRights'],
			'perm' => $perm, 'acquired' => epoch2lox(), 'info' => $info,
		);
		self::_store_put_token($serial, $user, array(
			'msnr' => $res['msnr'], 'name' => $res['name'], 'is_lbsystem' => $res['is_lbsystem'],
			'lbsystem_user' => $res['lbsystem_user'], 'firmware' => $firmware, 'checked' => epoch2lox(),
		), $tokendata);

		return array_merge($tokendata, array('ok' => 1, 'user' => $user, 'serial' => $serial,
		                                     'firmware' => $firmware, 'msnr' => $res['msnr']));
	}

	####################################################
	# token_info / refresh_token / kill_token / request
	####################################################

	public static function token_info($ms, $opts = array())
	{
		$res = self::_resolve_ms_probing($ms, $opts);
		if (!$res['ok']) { return $res; }

		$serial = $res['serial'];
		$data   = self::_store_read();
		if (!$serial) {
			foreach ($data as $s => $entry) {
				if (isset($entry['msnr']) && $entry['msnr'] == $res['msnr']) { $serial = $s; break; }
			}
		}
		if (!$serial) { return self::_err('notoken', "No token stored for Miniserver $ms"); }

		if (empty($data[$serial]['users'][$res['user']]['token'])) {
			return self::_err('notoken', "No token stored for user " . $res['user']);
		}
		$have = $data[$serial]['users'][$res['user']];

		return array(
			'ok' => 1, 'token' => $have['token'], 'validUntil' => $have['validUntil'],
			'rights' => $have['rights'], 'perm' => isset($have['perm']) ? $have['perm'] : null,
			'info' => isset($have['info']) ? $have['info'] : null,
			'user' => $res['user'], 'serial' => $serial, 'msnr' => $res['msnr'],
			'firmware' => isset($data[$serial]['firmware']) ? $data[$serial]['firmware'] : null,
			'expires_in' => intval($have['validUntil']) - epoch2lox(),
		);
	}

	// refreshjwt works with token authentication only - no password involved.
	// It answers with a JWT (eyJ0eXAi...) instead of the hex token.
	public static function refresh_token($ms, $opts = array())
	{
		$have = self::token_info($ms, $opts);
		if (!$have['ok']) { return $have; }
		$res = self::_resolve_ms_probing($ms, $opts);
		if (!$res['ok']) { return $res; }

		$k = self::_getkey2($res, $have['user'], $opts);
		if (!$k['ok']) { return $k; }
		$hash = self::_token_hash($have['token'], $k['key'], $k['alg']);

		// The path carries the token HASH, autht the PLAIN token. Measured on
		// 17.1.7.3: hashing both consumes the one-time key twice and the
		// Miniserver answers HTTP 200 with LL.code 401.
		$url = $res['baseurl'] . '/jdev/sys/refreshjwt/' . $hash . '/' . rawurlencode($have['user'])
		     . '?autht=' . rawurlencode($have['token']) . '&user=' . rawurlencode($have['user']);

		list($code, $body) = self::_call($url, $opts);
		if ($code === null) { return self::_err('unreachable', $res['baseurl'] . ' did not answer'); }
		$code = self::_effective_code($code, $body);
		if ($code == 401) { return self::_err('revoked', 'refreshjwt returned 401 - the token was not accepted'); }
		if ($code != 200) { return self::_err('httperror', "refreshjwt returned $code"); }

		$v = self::_ll_value($body);
		if (!is_array($v) || empty($v['token'])) { return self::_err('parseerror', 'refreshjwt could not be parsed'); }

		$tokendata = array(
			'token' => $v['token'], 'validUntil' => $v['validUntil'],
			'rights' => isset($v['tokenRights']) ? $v['tokenRights'] : $have['rights'],
			'perm' => $have['perm'], 'acquired' => epoch2lox(), 'info' => $have['info'],
		);
		self::_store_put_token($have['serial'], $have['user'],
			array('msnr' => $res['msnr'], 'checked' => epoch2lox()), $tokendata);

		return array_merge($tokendata, array('ok' => 1, 'user' => $have['user'],
			'serial' => $have['serial'], 'firmware' => $have['firmware'], 'msnr' => $res['msnr']));
	}

	// Revoking needs the password: killtoken was measured to work with Basic
	// Auth only, not with token authentication.
	public static function kill_token($ms, $opts = array())
	{
		$have = self::token_info($ms, $opts);
		if (!$have['ok']) { return $have; }
		$res = self::_resolve_ms_probing($ms, $opts);
		if (!$res['ok']) { return $res; }
		if ($res['password'] === null || $res['password'] === '') {
			return self::_err('nopassword', "kill_token needs the password of user " . $have['user']);
		}

		$k = self::_getkey2($res, $have['user'], $opts);
		if (!$k['ok']) { return $k; }
		$hash = self::_token_hash($have['token'], $k['key'], $k['alg']);

		$url = $res['baseurl'] . '/jdev/sys/killtoken/' . $hash . '/' . rawurlencode($have['user']);
		$callopts = array_merge($opts, array(
			'basicauth_user' => $have['user'], 'basicauth_password' => $res['password']));

		list($code, $body) = self::_call($url, $callopts);
		if ($code === null) { return self::_err('unreachable', $res['baseurl'] . ' did not answer'); }
		$code = self::_effective_code($code, $body);
		if ($code == 401) { return self::_err('badcredentials', 'killtoken returned 401'); }
		if ($code != 200) { return self::_err('httperror', "killtoken returned $code"); }

		self::_store_del_token($have['serial'], $have['user']);
		return array('ok' => 1, 'user' => $have['user'], 'serial' => $have['serial']);
	}

	private static function _sign_url($baseurl, $command, $token, $user, $res, $opts)
	{
		$k = self::_getkey2($res, $user, $opts);
		if (!$k['ok']) { return array(null, $k); }
		$hash = self::_token_hash($token, $k['key'], $k['alg']);
		$sep = (strpos($command, '?') !== false) ? '&' : '?';
		return array($baseurl . $command . $sep . 'autht=' . $hash . '&user=' . rawurlencode($user), null);
	}

	// Returns array($content, $info) - same keys as mshttp_call2, plus errcode.
	public static function request($ms, $command, $opts = array())
	{
		$info = array('code' => null, 'status' => null, 'error' => 1, 'message' => '', 'errcode' => null);

		$tok = self::get_token($ms, $opts);
		if (!$tok['ok']) {
			$info['errcode'] = $tok['error']; $info['message'] = $tok['message'];
			return array(null, $info);
		}

		$left = intval($tok['validUntil']) - epoch2lox();
		if ($left <= 0) {
			$tok = self::get_token($ms, array_merge($opts, array('force' => 1)));
		} elseif ($left < self::$REFRESH_THRESHOLD) {
			$r = self::refresh_token($ms, $opts);
			if ($r['ok']) { $tok = $r; }
		}
		if (!$tok['ok']) {
			$info['errcode'] = $tok['error']; $info['message'] = $tok['message'];
			return array(null, $info);
		}

		$res = self::_resolve_ms_probing($ms, $opts);
		if (!$res['ok']) {
			$info['errcode'] = $res['error']; $info['message'] = $res['message'];
			return array(null, $info);
		}

		for ($attempt = 1; $attempt <= 2; $attempt++) {
			list($url, $urlerr) = self::_sign_url($res['baseurl'], $command, $tok['token'], $tok['user'], $res, $opts);
			if (!$url) {
				$info['errcode'] = $urlerr['error']; $info['message'] = $urlerr['message'];
				return array(null, $info);
			}

			list($code, $body, $status) = self::_call($url, $opts);
			if ($code === null) {
				$info['errcode'] = 'unreachable';
				$info['message'] = $res['baseurl'] . ' did not answer';
				return array(null, $info);
			}
			$code = self::_effective_code($code, $body);
			$info['code'] = $code; $info['status'] = $status;

			if ($code == 401) {
				// The token may be gone on the Miniserver although validUntil
				// still looks fine. Fetch a new one and retry ONCE.
				if ($attempt == 1) {
					$fresh = self::get_token($ms, array_merge($opts, array('force' => 1)));
					if ($fresh['ok']) { $tok = $fresh; continue; }
					$info['errcode'] = $fresh['error']; $info['message'] = $fresh['message'];
					return array(null, $info);
				}
				$info['errcode'] = 'revoked';
				$info['message'] = "$command returned 401 twice - the token was revoked";
				return array(null, $info);
			}

			if ($code < 200 || $code >= 300) {
				$info['errcode'] = 'httperror';
				$info['message'] = "$command FAILED - Error $code";
				return array(null, $info);
			}

			$info['error'] = 0; $info['message'] = 'Request ok';
			return array($body, $info);
		}
	}
}
