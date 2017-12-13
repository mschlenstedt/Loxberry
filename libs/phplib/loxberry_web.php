<?php

require_once "loxberry_system.php";
// require_once "phphtmltemplate_loxberry/template040.php";

class LBWeb
{
	public static $LBWEBVERSION = "0.31_02";
	public static $lbpluginpage = "/admin/system/index.cgi";
	public static $lbsystempage = "/admin/system/index.cgi?form=system";
	public static $lang;
	private static $SL;
		
	///////////////////////////////////////////////////////////////////
	// prints the head
	///////////////////////////////////////////////////////////////////
	public function head($pagetitle = "")
	{
		error_log("loxberry_web: Head function called -->");
		global $template_title;
		
		# If a global template_title is set, use it
		if ($template_title !== "") {
			$pagetitle = $template_title;
		}
		$lang = LBWeb::lblanguage();
		
		$fulltitle = $pagetitle !== "" ? lbfriendlyname() . " " . $pagetitle : lbfriendlyname();
		$fulltitle = trim($fulltitle);
		if ($fulltitle === "") {
			$fulltitle = "LoxBerry";
		}
		error_log("   Determined template title: $fulltitle");
		
		$templatepath = $templatepath = LBSTEMPLATEDIR . "/head.html";
		if (!file_exists($templatepath)) {
			error_log("   Could not locate head template $templatepath");
			echo "<p style=\"color:red;\">Could not find head template $templatepath</p>";
			exit(1);
		}
		// $headobj = new Template( array ( 
								// 'filename' => $templatepath,
								// 'die_on_bad_params' => 0,
								// 'case_sensitive' => 0,
								// 'debug' => 1,
								// //'global_vars' => 1,
								// ));
		// $headobj->AddParam('TEMPLATETITLE', $fulltitle);
		// $headobj->AddParam('LANG', $lang);
		// //$headobj->AddParam('templatetitle', $fulltitle);
		// //$headobj->AddParam('lang', $lang);
		// $headobj->EchoOutput();

		$headobj = new LBTemplate($templatepath);
		$headobj->param('TEMPLATETITLE', $fulltitle);
		$headobj->param('LANG', $lang);
		LBWeb::readlanguage($headobj, "language.ini", True);
		$headobj->output();

		error_log("<-- loxberry_web: Head function finished");
	}
	
	///////////////////////////////////////////////////////////////////
	// pagestart - Prints the page
	///////////////////////////////////////////////////////////////////
	public function pagestart($pagetitle = "", $helpurl = "", $helptemplate = "", $page = "main1")
	{
		error_log("loxberry_web: pagestart function called -->");

		global $template_title;
		global $helplink;
		
		if ($template_title !== "") {
			$pagetitle = $template_title;
		}
		if ($helplink !== "") {
			$helpurl = $helplink;
		}
		
		$lang = LBWeb::lblanguage();
		$fulltitle = $pagetitle !== "" ? lbfriendlyname() . " " . $pagetitle : lbfriendlyname();
		$fulltitle = trim($fulltitle);
		if ($fulltitle === "") {
			$fulltitle = "LoxBerry";
		}
		error_log("   Determined template title: $fulltitle");
		
		// 
		
		$helptext = LBWeb::gethelp($lang, $helptemplate);
				
		$templatepath = $templatepath = LBSTEMPLATEDIR . "/pagestart.html";
		if (!file_exists($templatepath)) {
			error_log("   Could not locate pagestart template $templatepath");
			echo "<p style=\"color:red;\">Could not find pagestart template $templatepath</p>";
			exit(1);
		}
		// $pageobj = new Template( array ( 
								// 'filename' => $templatepath,
								// 'die_on_bad_params' => 0,
								// //'debug' => 1,
								// 'global_vars' => 1,
								// ));
		// #$pageobj->AddParam('TEMPLATETITLE', $fulltitle);
		// #$pageobj->AddParam('LANG', $lang);
		// $pageobj->AddParam(array(
					// 'TEMPLATETITLE' => $fulltitle,
					// 'HELPLINK' => $helpurl,
					// 'HELPTEXT' => $helptext,
					// 'PAGE' => $page,
					// 'LANG' => $lang
					// ));
		// $pageobj->EchoOutput();
		
		$pageobj = new LBTemplate($templatepath);
		$pageobj->paramArray(array(
					'TEMPLATETITLE' => $fulltitle,
					'HELPLINK' => $helpurl,
					'HELPTEXT' => $helptext,
					'PAGE' => $page,
					'LANG' => $lang
					));
		LBWeb::readlanguage($pageobj, "language.ini", True);
		$pageobj->output();
		
		error_log("<-- loxberry_web: Pagestart function finished");
	}
	
	///////////////////////////////////////////////////////////////////
	// gethelp - Collects the help text
	// Currently, only plugin help is supported (no system help)
	///////////////////////////////////////////////////////////////////
	function gethelp($lang, $helptemplate)
	{
		global $LBPLUGINDIR;
		global $LBTEMPLATEDIR;
		
		error_log("gethelp -> LBPLUGINDIR: $LBPLUGINDIR LBTEMPLATEDIR: $LBTEMPLATEDIR");
		error_log("   Parameters: lang: $lang helptemplate: $helptemplate");
		
		if (file_exists("$LBTEMPLATEDIR/help/$helptemplate")) { 
			$templatepath = "$LBTEMPLATEDIR/help/$helptemplate";
			$ismultilang = True;
			error_log("gethelp: Multilang template found - using templatepath $templatepath");
		} elseif (file_exists("$LBTEMPLATEDIR/$lang/$helptemplate")) {
			$templatepath = "$LBTEMPLATEDIR/$lang/$helptemplate";
			$ismultilang = False;
			error_log("gethelp: Legacy lang $lang template found - using templatepath $templatepath");
		} elseif (file_exists("$LBTEMPLATEDIR/en/$helptemplate")) {
			$templatepath = "$LBTEMPLATEDIR/en/$helptemplate";
			$ismultilang = False;
			error_log("gethelp: Legacy fallback lang en template found - using templatepath $templatepath");
		} elseif (file_exists("$LBTEMPLATEDIR/de/$helptemplate")) {
			$templatepath = "$LBTEMPLATEDIR/de/$helptemplate";
			$ismultilang = False;
			error_log("gethelp: Legacy fallback lang de template found - using templatepath $templatepath");
		} else {
			error_log("gethelp: No help found. Returning default text.");
			if ($lang === "de") {
				$helptext = "Keine weitere Hilfe verfügbar.";
			} else {
				$helptext = "No further help available.";
			}
			return $helptext;
		}
		
		// Multilang templates
		if ($ismultilang) {
			$pos = strrpos($helptemplate, ".");
			if ($pos === false) {
				error_log("gethelp: Illegal option '$helptemplate'. This should be in the form 'helptemplate.html' without pathes.");
				return null;
			}
			$langfile = substr($helptemplate, 0, $pos) . ".ini";
			$helpobj = new LBTemplate($templatepath);
			LBWeb::readlanguage($helpobj, $langfile);
			$helptext = $helpobj->outputString();
			return $helptext;
		}
		// Legacy templates
		else {
			$helptext = file_get_contents($templatepath);
			return $helptext;
		}
	}
	
	///////////////////////////////////////////////////////////////////
	// pageend - Prints the page end
	///////////////////////////////////////////////////////////////////
	public function pageend()
	{
		$lang = LBWeb::lblanguage();
		$templatepath = $templatepath = LBSTEMPLATEDIR . "/pageend.html";
		$pageobj = new LBTemplate($templatepath);
		$pageobj->param('LANG', $lang);
		echo $pageobj->output();
	}
	
	///////////////////////////////////////////////////////////////////
	// foot - Prints the footer
	///////////////////////////////////////////////////////////////////
	public function foot()
	{
		$lang = LBWeb::lblanguage();
		$templatepath = $templatepath = LBSTEMPLATEDIR . "/foot.html";
		$footobj = new LBTemplate($templatepath);
		$footobj->param('LANG', $lang);
		echo $footobj->output();
	}
	
	///////////////////////////////////////////////////////////////////
	// lbheader - Prints head and pagestart
	///////////////////////////////////////////////////////////////////
	public function lbheader($pagetitle = "", $helpurl = "", $helptemplate = "")
	{
		LBWeb::head($pagetitle);
		LBWeb::pagestart($pagetitle, $helpurl, $helptemplate);
	}
	
	///////////////////////////////////////////////////////////////////
	// lbfooter - Prints pageend and footer
	///////////////////////////////////////////////////////////////////
	public function lbfooter()
	{
		LBWeb::pageend();
		LBWeb::foot();
	}
	
	
	///////////////////////////////////////////////////////////////////
	// Detects the language from query, post or general.cfg
	///////////////////////////////////////////////////////////////////
	public function lblanguage() 
	{
		global $lblang;
		if (isset(LBWeb::$lang)) { 
			error_log("Language " . LBWeb::$lang . " is already set.");
			return LBWeb::$lang; }
		
		// error_log("Will detect language");
		if (isset($_GET["lang"])) {
			LBWeb::$lang = substr($_GET["lang"], 0, 2);
			error_log("Language " . LBWeb::$lang . " detected from Query string");
			return LBWeb::$lang;
		}
		if (isset($_POST["lang"])) {
			LBWeb::$lang = substr($_GET["lang"], 0, 2);
			error_log("Language " . LBWeb::$lang . " detected from post data");
			return LBWeb::$lang;
		}
		LBSystem::read_generalcfg();
		if (isset($lblang)) {
			LBWeb::$lang = $lblang;
			error_log("Language " . LBWeb::$lang . " used from general.cfg");
			return LBWeb::$lang;
		}
		// Finally we default to en
		return "en";
	}

	///////////////////////////////////////////////////////////////////
	// readlanguage - reads the language to an array and template
	///////////////////////////////////////////////////////////////////
	public function readlanguage($template = NULL, $genericlangfile = "language.ini", $syslang = FALSE)
	{
		if (!is_object($template) && is_string($template)) {
			$genericlangfile = $template;
			$template = NULL;
		}
		if ($syslang == true) {
			$genericlangfile = LBSTEMPLATEDIR . "/lang/language.ini";
		} else {
			$genericlangfile = LBTEMPLATEDIR . "/lang/$genericlangfile";
		}
		
		$lang = LBWeb::lblanguage();
		$pos = strrpos($genericlangfile, ".");
		if ($pos === false) {
				error_log("readlanguage: Illegal option '$genericlangfile'. This should be in the form 'language.ini' without pathes.");
				return null;
		}
		
		
		$langfile = substr($genericlangfile, 0, $pos) . "_" . $lang . substr($genericlangfile, $pos);
		$enlangfile = substr($genericlangfile, 0, $pos) . "_en" . substr($genericlangfile, $pos);
		error_log("readlanguage: $langfile enlangfile: $enlangfile");
		
		if ($syslang == false || ($syslang == True && !is_array(self::$SL))) { 
			if (file_exists($langfile)) {
				$currlang = LBWeb::read_language_file($langfile);
			}
			if (file_exists($enlangfile)) {
				$enlang = LBWeb::read_language_file($enlangfile);
			}
		
			foreach ($enlang as $section => $sectionarray)  {
				foreach ($sectionarray as $tag => $langstring)  {
					$language["$section.$tag"] = $langstring;
					// error_log("Tag: $section.$tag Langstring: $langstring");
				}
			}
			foreach ($currlang as $section => $sectionarray)  {
				foreach ($sectionarray as $tag => $langstring)  {
					$language["$section.$tag"] = $langstring;
					// error_log("Tag: $section.$tag Langstring: $langstring");
				}
			}
			if ($syslang) {
				self::$SL = $language;
			}
		} elseif ($syslang == True && is_array(self::$SL)) {
			error_log("readlanguage: Re-use cached system language"); 
			$language = self::$SL;
		}
		
		if (is_object($template)) {
			$template->paramArray($language);
		}
	
		return $language;

	}
	
	
	function read_language_file($langfile)
	{
		$langarray = parse_ini_file($langfile, True, INI_SCANNER_RAW) or error_log("LoxBerry Web ERROR: Could not read language file $langfile");
		if ($langarray == false) {
			error_log("Cannot read language $langfile");
		}
		return $langarray;
	}
	
	function get_plugin_icon($iconsize = 64)
	{
		global $LBSHTMLDIR;
		global $LBPLUGINDIR;
		
		if 		($iconsize > 256) { $iconsize = 512; }
		elseif	($iconsize > 128) { $iconsize = 256; }
		elseif	($iconsize > 64) { $iconsize = 128; }
		else					{ $iconsize = 64; }
		$logopath = "$LBSHTMLDIR/images/icons/$LBPLUGINDIR/icon_$iconsize.png";
		$logopath_web = "/system/images/icons/$LBPLUGINDIR/icon_$iconsize.png";
	
		if (file_exists($logopath)) { 
			return $logopath_web;
		}
		return undef;
	}
}
////////////////////////////////////////////////////////////
// Christian's Quick and Dirty 'HTML::Template'
////////////////////////////////////////////////////////////
class LBTemplate
 {
	private $valuearray;
	private $template;
		
	function __construct($templatepath)
	{
		error_log("LBTemplate construct: templatepath: $templatepath");
		$this->template = file_get_contents($templatepath);
	}
	public function param($varname, $value)
	{
			$this->valuearray[$varname] = $value;
	}
	public function paramArray($vararray)
	{
			foreach ($vararray as $key => $value) {
				$this->param($key, $value);
			}
	}
	
	function replaceTmplVar() 
	{
		foreach ($this->valuearray as $tmplvar => $value) {
			// error_log("Key: $tmplvar Value: $value");
			$this->template = str_replace("<TMPL_VAR $tmplvar>", $value, $this->template);
		}
	}
	
	public function output()
	{
	$this->replaceTmplVar();
	echo $this->template;	
	}
	
	public function outputString()
	{
	$this->replaceTmplVar();
	return $this->template;	
	}
 }

# main namespace
	


?>
