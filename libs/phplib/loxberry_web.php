<?php

require_once "loxberry_system.php";
// require_once "phphtmltemplate_loxberry/template040.php";

class Web
{
	public static $LBWEBVERSION = "0.31_01";
	public static $lbpluginpage = "/admin/system/index.cgi";
	public static $lbsystempage = "/admin/system/index.cgi?form=system";
	public static $lang;
	
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
		$lang = Web::lblanguage();
		
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
		
		$lang = Web::lblanguage();
		$fulltitle = $pagetitle !== "" ? lbfriendlyname() . " " . $pagetitle : lbfriendlyname();
		$fulltitle = trim($fulltitle);
		if ($fulltitle === "") {
			$fulltitle = "LoxBerry";
		}
		error_log("   Determined template title: $fulltitle");
		
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
		$pageobj->output();
		
		error_log("<-- loxberry_web: Pagestart function finished");
	}
	
	
	///////////////////////////////////////////////////////////////////
	// pageend - Prints the page end
	///////////////////////////////////////////////////////////////////
	public function pageend()
	{
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
		Web::head($pagetitle);
		Web::pagestart($pagetitle, $helpurl, $helptemplate);
	}
	
	///////////////////////////////////////////////////////////////////
	// lbfooter - Prints pageend and footer
	///////////////////////////////////////////////////////////////////
	public function lbfooter()
	{
		Web::pageend();
		Web::foot();
	}
	
	
	///////////////////////////////////////////////////////////////////
	// Detects the language from query, post or general.cfg
	///////////////////////////////////////////////////////////////////
	public function lblanguage() 
	{
		global $lblang;
		if (isset(Web::$lang)) { 
			error_log("Language " . Web::$lang . " is already set.");
			return Web::$lang; }
		
		// error_log("Will detect language");
		if (isset($_GET["lang"])) {
			Web::$lang = substr($_GET["lang"], 0, 2);
			error_log("Language " . Web::$lang . " detected from Query string");
			return Web::$lang;
		}
		if (isset($_POST["lang"])) {
			Web::$lang = substr($_GET["lang"], 0, 2);
			error_log("Language " . Web::$lang . " detected from post data");
			return Web::$lang;
		}
		LoxBerry\System\read_generalcfg();
		if (isset($lblang)) {
			Web::$lang = $lblang;
			error_log("Language " . Web::$lang . " used from general.cfg");
			return Web::$lang;
		}
		// Finally we default to en
		return "en";
	}

	
}
////////////////////////////////////////////////////////////
// Christian's Quick and Dirty 'HTML::Template'
////////////////////////////////////////////////////////////
class LBTemplate
 {
	public $valuearray;
	public $template;
	
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
			error_log("Key: $tmplvar Value: $value");
			$this->template = str_replace("<TMPL_VAR $tmplvar>", $value, $this->template);
		}
	}
	
	public function output()
	{
	$this->replaceTmplVar();
	echo $this->template;	
	}
	
	
 }

# main namespace
	


?>
