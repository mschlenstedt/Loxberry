<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/transitional.dtd">
<HTML lang="de">
 <HEAD>
  <META http-equiv="Content-Type" content="text/html; charset=utf-8">
  <META name="robots"             content="noindex,nofollow">
  <TITLE>LoxBerry  - Error :-(</TITLE>
  <LINK rel="shortcut icon"              href="/system/images/favicon.ico">
 </HEAD>
 <BODY bgColor="#FAF8FB" leftmargin="5px" topMargin="0px" marginheight="0px" marginwidth="5px">
 <center>
  <font face="Verdana, Arial, sans-serif" font-size="14px" color="#FF5A00">
  <br>
  <img src="/system/images/apache_error.png">
  <br>


  <?php
  $langs = array();

  if (isset($_SERVER['HTTP_ACCEPT_LANGUAGE'])) {
    // break up string into pieces (languages and q factors)
    preg_match_all('/([a-z]{1,8}(-[a-z]{1,8})?)\s*(;\s*q\s*=\s*(1|0\.[0-9]+))?/i', $_SERVER['HTTP_ACCEPT_LANGUAGE'], $lang_parse);

    if (count($lang_parse[1])) {
        // create a list like "en" => 0.8
        $langs = array_combine($lang_parse[1], $lang_parse[4]);
    	
        // set default to 1 for any without q factor
        foreach ($langs as $lang => $val) {
            if ($val === '') $langs[$lang] = 1;
        }

        // sort list based on value	
        arsort($langs, SORT_NUMERIC);
    }
  }

  // look through sorted list and use first one that matches our languages
  foreach ($langs as $lang => $val) {
 	if (strpos($lang, 'de') === 0) {
		// show German site
                include ("de.php"); 
                break;
	//} else if (strpos($lang, 'en') === 0) {
	//	// show English site
	//} 
	} else {
		// show English site
                include ("en.php"); 
                break;
	} 
  }
  ?>


 </BODY>
</HTML>
