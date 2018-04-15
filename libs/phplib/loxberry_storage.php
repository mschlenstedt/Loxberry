<?php

require_once "loxberry_system.php";

// get_storage_html
function get_storage_html ($args)
{

	global $lbpdatadir;

	$STORAGEHANDLERURL = "http://localhost:" . lbwebserverport() . "/admin/system/tools/ajax-storage-handler.cgi";	

	$args['action'] = 'init';
	
	// $fields = array(
		// 'action' => 'init',
	// );
	
	if (!isset($args['localdir']) && isset($lbpdatadir)) {
		$args['localdir'] = $lbpdatadir;
	}
	
	$options = array(
		'http' => array(
			'header'  => "Content-type: application/x-www-form-urlencoded; charset=utf-8\r\n",
			'method'  => 'POST',
			'content' => http_build_query($args)
			)
	);
	$context  = stream_context_create($options);
	$result = file_get_contents($STORAGEHANDLERURL, false, $context);
	if ($result === FALSE) { 
		error_log("get_storage_html: Could not get storage html"); 
		return;
	}
	
	return $result;

}
