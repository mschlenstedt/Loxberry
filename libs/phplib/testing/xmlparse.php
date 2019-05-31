<?php
	
	//$xmlresp = simplexml_load_file($url);
	// if ($xmlresp === false) {
		// echo "Errors occured\n";
		// $errors = libxml_get_errors();
		// echo("mshttp_call: An error occured loading the XML:");
		// foreach($errors as $error) {
			// echo(display_xml_error($error, $xmlresp));
		// }
		// return array (null, 500, null);
	// }
	
	// $value = (string)$xmlresp->attributes()->value;
	// $code = (string)$xmlresp->attributes()->Code;

	
	$xmlresp = '<?xml version="1.0" encoding="utf-8"?><LL control="dev/sps/io/LMS 9d:aa:a9:d3:7c:c3 artist/Tina Turner & David Bowie" value="100" Code="500"/>';
	$xmlresp = '<?xml version="1.0" encoding="utf-8"?><LL control="dev/sps/io/LMS 9d:aa:a9:d3:7c:c3 artist/Tina Turner & David Bowie" value="100" Code="500"/>';
	
	preg_match ( '/value\=\"(.*?)\"/' , $xmlresp, $matches );
	$value = $matches[1];
	preg_match ( '/Code\=\"(.*?)\"/' , $xmlresp, $matches );
	$code = $matches[1];
	

	
	echo "Value $value\nCode $code\n";
	
	// return array ($value, $code, $xmlresp);
	