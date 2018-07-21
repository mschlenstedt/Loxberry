<?php

	echo "=================================================================================\n";
	
	$cobj = curl_init();

	$msurl = "schlenn.dynvpn.de:6080";
	$user = "loxberryadmin";
	$pass = "loxberry";

	// $msurl = "reifen01.fenzis.net";
	// $user = "admin";
	// $pass = "j1lSPHeu";

	
	$publickey = NULL;
	$apikey = NULL;
	$msver = NULL;
	$salt = NULL;
	$key = NULL;
	$ownkey = NULL;
	$iv = NULL;
	$token = NULL;
	$encsessionkey = NULL;
	
	// get_apikey();
	get_publickey();
	get_token();
	$output = send_request("dev/cfg/ip");
	//$output = send_request("dev/fsget/log/def.log");
	
	
	curl_close($cobj);


	
function get_publickey()
{
		global $msurl;
		global $cobj;
		global $publickey;
		
		echo "*************** get_publickey START **************\n";
		
		curl_setopt($cobj, CURLOPT_URL, "http://" . $msurl . "/jdev/sys/getPublicKey");
		curl_setopt($cobj, CURLOPT_RETURNTRANSFER, 1);
	
		$output = curl_exec($cobj);
		// echo "get_publickey: $output \n";
		$json_publickey = json_decode($output, True);
		$publickey = $json_publickey["LL"]["value"];
		// echo "Public Key: $publickey\n";
		$publickey = str_replace("-----BEGIN CERTIFICATE-----", "-----BEGIN PUBLIC KEY-----\n", $publickey);
		$publickey = str_replace("-----END CERTIFICATE-----", "\n-----END PUBLIC KEY-----", $publickey);
		// echo "Public Key: $publickey\n";
		
		$publickey = openssl_pkey_get_public ($publickey);
		
		// while ($msg = openssl_error_string())
			// echo $msg . "\n";
		
		echo "Public Key: $publickey\n";
		echo "*************** get_publickey END **************\n";
		
}
	
	
function get_apikey()
{
	global $msurl;
	global $msver;
	global $cobj;
	global $apikey;
	
	echo "*************** get_apikey START **************\n";
		
	curl_setopt($cobj, CURLOPT_URL, "http://" . $msurl . "/jdev/cfg/apiKey");
	curl_setopt($cobj, CURLOPT_RETURNTRANSFER, 1);

	$output = curl_exec($cobj);
	// echo $output;
	$json_apikey = json_decode($output, True);
	
	// var_dump($json_apikey);
	
	// key and version are not json but a string in value, therefore convert it to json
	$json_apikey2 = json_decode(str_replace("'", '"', $json_apikey['LL']['value']), True);
	// var_dump($json_apikey2);
	
	$apikey = $json_apikey2['key'];
	$msver =  $json_apikey2['version'];
	
	echo "API Key: $apikey  MSVer: $msver\n";
	echo "*************** get_apikey END **************\n";
	
}

function encrypt_command($cmd)
{
	global $publickey;
	global $cobj;
	global $msurl;
	global $salt;
	global $key;
	global $iv;
	global $encsessionkey;
		
	
	echo "*************** encrypt_command START **************\n";
	
	
	if(! isset($publickey) || $publickey == "") {
		get_publickey();
	}
	echo "Public key: $publickey\n";
	if (! isset($salt) || $salt == "") {
		$salt = dechex(rand(0,65535));
	}
	echo "Salt: $salt\n";
	$plaintext = "salt/$salt/$cmd\0";
	echo "Plaintext: $plaintext\n";
	
//	$keysize = 1024;
//	$sslres = openssl_pkey_new (array('private_key_bits' => $keysize));
//	openssl_pkey_export($sslres, $key);

	if (! isset($key) || $key == "") {
		$key = openssl_random_pseudo_bytes(32);
	}
	$keyhex = bin2hex($key);
	echo "Key: $keyhex\n";
	$ivlen = openssl_cipher_iv_length("AES-256-CBC");
	echo "IVLen: $ivlen\n";
	if (! isset($iv) || $iv == "") {
		$iv = openssl_random_pseudo_bytes($ivlen);
	}
	$ivhex = bin2hex($iv);
	echo "IV: " . $ivhex . "\n";
	
	// Encrypt
	$cipher = openssl_encrypt($plaintext, "AES-256-CBC", $key, 0, $iv);
	// $cipher = base64_encode($cipher);
	echo "Cipher: $cipher\n";
	
	echo "Test Decrypt: " . openssl_decrypt($cipher, "AES-256-CBC", $key, 0, $iv) . "\n";
	
	$enccipher = urlencode($cipher);
	echo "URI-ecnoded cipher: $enccipher\n";
	
	$encryptedcmd = "jdev/sys/enc/$enccipher";
	//$encryptedcmd = "jdev/sys/fenc/$enccipher";
	echo "Encrypted command: $encryptedcmd\n";
	
	// echo "Public key: $publickey\n";
	openssl_public_encrypt("${keyhex}:${ivhex}", $sessionkey, $publickey);
	
	$sessionkey = base64_encode($sessionkey);
	if (! isset($encsessionkey)) {
		$encsessionkey = urlencode($sessionkey);
	}
	print "Enc Session key: $encsessionkey\n";
	
	$encryptedcmd = "$encryptedcmd?sk=$encsessionkey";
	echo "Encrypted command: $encryptedcmd\n";
	
	echo "*************** encrypt_command END **************\n";
	
	return $encryptedcmd;
	
}

function get_token()
{
	global $cobj;
	global $msurl;
	global $user;
	global $pass;
	global $token;
	global $ownkey;
	
	echo "*************** get_token START **************\n";
	
	$keysalt = getkey2();
	
	$ownkey = $keysalt['key'];
	$salt = $keysalt['salt'];
	
	echo "User: $user  Pass: $pass\n";
	echo "key: $ownkey  salt: $salt\n";
	
	$pwHash = strtoupper(sha1("${pass}:${salt}"));
	$hash_plain = "${user}:${pwHash}";
	echo "Hash_plain: $hash_plain\n";
	$hash = hash_hmac("sha1", $hash_plain, hex2bin($ownkey)); // Hex
	echo "Hash: $hash\n";
	echo "PWHash: $pwHash  Hash: $hash\n";
	
	$uuid = urlencode("098802e1-02b4-603c-ffffeee000d80cfd");
	// Required?
	//$uuid = urlencode($uuid);
	
	$info = urlencode("dasistmeinclient");
	
	$request = "jdev/sys/gettoken/$hash/$user/2/$uuid/$info";
	print "Token command before encryption: **$request**\n";
	$request = encrypt_command($request);
	
	$request = "http://$msurl/$request";
	curl_setopt($cobj, CURLOPT_URL, $request);
	
	$output = curl_exec($cobj);
	
	echo "Request: $request \nResponse: $output\n";
	
	$json_token = json_decode($output, True);
	
	$token = $json_token['LL']['value']['token'];
	$tokenvalid = $json_token['LL']['value']['validUntil'];
	$ownkey = $json_token['LL']['value']['key'];
	
	echo "Token: $token  TokenValid: $tokenvalid\n";
	echo "Key: $ownkey\n";
	
	echo "*************** get_token END **************\n";
	
	
}

function getkey2 ()
{
	global $cobj;
	global $msurl;
	global $user;
	
	$keysalt = [];
	
	echo "*************** getkey2 START **************\n";
	
	$request = "jdev/sys/getkey2/$user";
	echo "getkey2 request: " . $request . "\n";	
	$request = encrypt_command($request);
	echo "getkey2 request: " . $request . "\n";	
	curl_setopt($cobj, CURLOPT_URL, "http://" . $msurl . "/" . $request );
	curl_setopt($cobj, CURLOPT_RETURNTRANSFER, 1);
	$output = curl_exec($cobj);
	echo "Output: $output\n";
	$json_getkey = json_decode($output, True);
	// var_dump($json_getkey);
	$keysalt['key'] = $json_getkey["LL"]["value"]["key"];
	$keysalt['salt'] = $json_getkey["LL"]["value"]["salt"];
	
	echo "*************** getkey2 END **************\n";
	
	return $keysalt;
	
}

function decrypt_response($resp)
{
	global $key;
	global $iv;
	
	$plaintext = openssl_encrypt($resp, "AES-256-CBC", $key, 0, $iv);
	return $plaintext;
	
	
	
	
}

function send_request($cmd)
{
	
	global $cobj;
	global $msurl;
	global $user;
	global $token;
	global $ownkey;
	global $apikey;
	echo "*************** send_request START **************\n";
	echo "Command is: $cmd\n";
	
	// if (! isset($apikey)) {
		// get_apikey();
	// }
		
	
	// $hash_plain = "${user}:${token}";
	// $tokenhash = hash_hmac("sha1", $token, hex2bin($apikey)); 
	// //$hash = hash_hmac("sha1", $hash_plain, hex2bin($apikey)); // Hex
	// $authcmd = $cmd . "?autht=$tokenhash&user=$user";
	// $request = encrypt_command($authcmd);
	// curl_setopt($cobj, CURLOPT_URL, "http://" . $msurl . "/" . $request );
	// curl_setopt($cobj, CURLOPT_RETURNTRANSFER, 1);
	// $output = curl_exec($cobj);
	
	// $hash_plain = "${user}:${token}";
	$tokenhash = hash_hmac("sha1", $token, hex2bin($ownkey)); 
	//$hash = hash_hmac("sha1", $hash_plain, hex2bin($apikey)); // Hex
	$authcmd = $cmd . "?autht=$tokenhash&user=$user";
	$request = encrypt_command($authcmd);
	curl_setopt($cobj, CURLOPT_URL, "http://" . $msurl . "/" . $request );
	curl_setopt($cobj, CURLOPT_RETURNTRANSFER, 1);
	$output = curl_exec($cobj);
	
		
	echo "Authcmd   : $authcmd\n";
	echo "Encrypted : $request\n";
	//echo "hash_plain: $hash_plain\n";
	echo "Token     : $token\n";
	echo "Key       : $ownkey\n";
	echo "APIKey       : $apikey\n";
	//echo "HMAC-SHA1 : $hash\n";
	echo "Response  : $output\n";
	
	
	
	
	
	
	return $output;	
	echo "*************** send_request END **************\n";
	
}
