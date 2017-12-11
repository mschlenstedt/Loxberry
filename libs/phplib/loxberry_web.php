<?php

require_once "loxberry_system.php";
require_once "phphtmltemplate_loxberry/template.php";

class Web
{
	public static $LBWEBVERSION = "0.31_01";
	public static $lbpluginpage = "/admin/system/index.cgi";
	public static $lbsystempage = "/admin/system/index.cgi?form=system";
	public static $lang;

	public function lblanguage() 
	{
		global $lblang;
		if (Web::$lang) { 
			error_log("Language {Web::$lang} is already set.");
			return $lang; }
		
		// error_log("Will detect language");
		if ($_GET["lang"]) {
			Web::$lang = substr($_GET["lang"], 0, 2);
			error_log("Language {Web::$lang} detected from Query string");
			return Web::$lang;
		}
		if ($_POST["lang"]) {
			Web::$lang = substr($_GET["lang"], 0, 2);
			error_log("Language {Web::$lang} detected from post data");
			return Web::$lang;
		}
		LoxBerry\System\read_generalcfg();
		if ($lblang) {
			Web::$lang = $lblang;
			error_log("Language {Web::$lang} used from general.cfg");
			return Web::$lang;
		}
		// Finally we default to en
		return "en";
	}

	
}


# main namespace
	


?>
