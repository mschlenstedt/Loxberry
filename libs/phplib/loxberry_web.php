<?php

require_once "loxberry_system.php";
// require_once "phphtmltemplate_loxberry/template040.php";

class LBWeb
{
	public static $LBWEBVERSION = "0.3.3.3";
	
	public static $lbpluginpage = "/admin/system/index.cgi";
	public static $lbsystempage = "/admin/system/index.cgi?form=system";
		
	///////////////////////////////////////////////////////////////////
	// prints the head
	///////////////////////////////////////////////////////////////////
	public function head($pagetitle = "")
	{
		// error_log("loxberry_web: Head function called -->");
		global $template_title;
		
		# If a global template_title is set, use it
		if ($template_title !== "") {
			$pagetitle = $template_title;
		}
		$lang = LBSystem::lblanguage();
		
		$fulltitle = $pagetitle !== "" ? lbfriendlyname() . " " . $pagetitle : lbfriendlyname();
		$fulltitle = trim($fulltitle);
		if ($fulltitle === "") {
			$fulltitle = "LoxBerry";
		}
		// error_log("   Determined template title: $fulltitle");
		
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
		LBSystem::readlanguage($headobj, "language.ini", True);
		$headobj->output();

		// error_log("<-- loxberry_web: Head function finished");
	}
	
	///////////////////////////////////////////////////////////////////
	// pagestart - Prints the page
	///////////////////////////////////////////////////////////////////
	public function pagestart($pagetitle = "", $helpurl = "", $helptemplate = "", $page = "main1")
	{
		// error_log("loxberry_web: pagestart function called -->");

		global $template_title;
		global $helplink;
		global $navbar;
		
		if ($template_title !== "") {
			$pagetitle = $template_title;
		}
		if ($helplink !== "") {
			$helpurl = $helplink;
		}
		
		$lang = LBSystem::lblanguage();
		$fulltitle = $pagetitle !== "" ? lbfriendlyname() . " " . $pagetitle : lbfriendlyname();
		$fulltitle = trim($fulltitle);
		if ($fulltitle === "") {
			$fulltitle = "LoxBerry";
		}
		// error_log("   Determined template title: $fulltitle");
		
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
		
		// NavBar Start
		
		if (is_array($navbar)) {
			# navbar is defined as ARRAY
			sort($navbar, SORT_NUMERIC);
			$topnavbar = '<div data-role="navbar">' . 
				'	<ul>';
			foreach ($navbar as $element) {
				if (isset($element['active'])) {
					$btnactive = ' class="ui-btn-active"';
				} else { $btnactive = NULL; 
				}
				if (isset($element['target'])) {
					$btntarget = ' target="' . $element['target'] . '"';
				} else {
					$btntarget = "";
				}
				
				$notify = "";
				if (isset($element['notifyRed'])) {
					$notify = ' <span class="notifyRedNavBar">' . $element['notifyRed'] . '</span>';
				} elseif (isset($element['notifyBlue'])) {
					$notify = ' <span class="notifyBlueNavBar">' . $element['notifyBlue'] . '</span>';
				}
				
				if (isset($element['Name'])) {
					$topnavbar .= '		<li><a href="' . $element['URL'] . '"' . $btntarget . $btnactive . '>' . $element['Name'] . '</a>' . $notify . '</li>';
					$topnavbar_haselements = True;
				}
			}
			$topnavbar .=  '	</ul>' .
				'</div>';	
		
		} elseif (is_string($navbar)) {
			# navbar is defined as plain STRING
			$topnavbar = $navbar;
			$topnavbar_haselements = True;
		} 
		// NavBar End
			
		
		$pageobj = new LBTemplate($templatepath);
		$pageobj->paramArray(array(
					'TEMPLATETITLE' => $fulltitle,
					'HELPLINK' => $helpurl,
					'HELPTEXT' => $helptext,
					'PAGE' => $page,
					'LANG' => $lang
					));
		LBSystem::readlanguage($pageobj, "language.ini", True);
		
		if ($topnavbar_haselements) {
			$pageobj->param ( 'TOPNAVBAR', $topnavbar);
		} else {
			$pageobj->param ( 'TOPNAVBAR', "");
		}
		
		
		$pageobj->output();
		
		// error_log("<-- loxberry_web: Pagestart function finished");
	}
	
	///////////////////////////////////////////////////////////////////
	// gethelp - Collects the help text
	// Currently, only plugin help is supported (no system help)
	///////////////////////////////////////////////////////////////////
	function gethelp($lang, $helptemplate)
	{
		global $lbpplugindir;
		global $lbptemplatedir;
		
		// error_log("gethelp -> lbpplugindir: $lbpplugindir lbptemplatedir: $lbptemplatedir");
		// error_log("   Parameters: lang: $lang helptemplate: $helptemplate");
		
		if (file_exists("$lbptemplatedir/help/$helptemplate")) { 
			$templatepath = "$lbptemplatedir/help/$helptemplate";
			$ismultilang = True;
			// error_log("gethelp: Multilang template found - using templatepath $templatepath");
		} elseif (file_exists("$lbptemplatedir/$lang/$helptemplate")) {
			$templatepath = "$lbptemplatedir/$lang/$helptemplate";
			$ismultilang = False;
			// error_log("gethelp: Legacy lang $lang template found - using templatepath $templatepath");
		} elseif (file_exists("$lbptemplatedir/en/$helptemplate")) {
			$templatepath = "$lbptemplatedir/en/$helptemplate";
			$ismultilang = False;
			// error_log("gethelp: Legacy fallback lang en template found - using templatepath $templatepath");
		} elseif (file_exists("$lbptemplatedir/de/$helptemplate")) {
			$templatepath = "$lbptemplatedir/de/$helptemplate";
			$ismultilang = False;
			// error_log("gethelp: Legacy fallback lang de template found - using templatepath $templatepath");
		} else {
			//error_log("gethelp: No help found. Returning default text.");
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
			LBSystem::readlanguage($helpobj, $langfile);
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
		global $reboot_required_file;
		$lang = LBSystem::lblanguage();
		$templatepath = $templatepath = LBSTEMPLATEDIR . "/pageend.html";
		$pageobj = new LBTemplate($templatepath);
		$SL = LBSystem::readlanguage($pageobj, "language.ini", True);
		$pageobj->param('LANG', $lang);
		
		// Reboot required button
		if (file_exists("$reboot_required_file")) {
			$reboot_req_string='<div data-href="/admin/system/power.cgi" id="btnpower_alert" style="pointer-events: none; display:none; width:30px; height:30px; background-repeat: no-repeat; background-image: url(\'/system/images/reboot_required.svg\');"></div><script>$(document).ready( function(){ $("#btnpower").attr("title","'.$SL['POWER.MSG_REBOOT_REQUIRED_SHORT'].'");  $("#btnpower_alert").on("click", function(e){ var ele = e.target; window.location.replace(ele.getAttribute("data-href"));}); function reboot_on(){ var reboot_alert_offset = $("#btnpower").offset(); $("#btnpower_alert").css({"padding": "0px", "border": "0px", "z-index": 10000, "top": "4px" ,"left" : reboot_alert_offset.left + 4, "position":"absolute" }); $("#btnpower_alert").fadeTo( 2000 , 1.0, function() { setTimeout(function(){ reboot_off(); }, 2700); }); }; function reboot_off(){ var reboot_alert_offset = $("#btnpower").offset(); $("#btnpower_alert").css({"padding": "0px", "border": "0px", "z-index": 10000, "top": "4px" ,"left" : reboot_alert_offset.left + 4, "position":"absolute" }); $("#btnpower_alert").fadeTo( 2000 , 0.1, function() { setTimeout(function(){ reboot_on(); }, 100); });   }; reboot_on(); });</script>';
			$pageobj->param('REBOOT_REQUIRED', $reboot_req_string);
		}

		echo $pageobj->output();
	}
	
	///////////////////////////////////////////////////////////////////
	// foot - Prints the footer
	///////////////////////////////////////////////////////////////////
	public function foot()
	{
		$lang = LBSystem::lblanguage();
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
	// Detects the language 
	// Moved to LBSystem::lblanguage
	///////////////////////////////////////////////////////////////////
	public function lblanguage() 
	{
		$phpself = basename(__FILE__);
		error_Log("$phpself: LBWeb::lblanguage was moved to LBSystem::lblanguage. The call was redirected, but you should update your program.");
		return LBSystem::lblanguage();
	}

	///////////////////////////////////////////////////////////////////
	// readlanguage - reads the language to an array and template
	///////////////////////////////////////////////////////////////////
	public function readlanguage($template = NULL, $genericlangfile = "language.ini", $syslang = FALSE)
	{
		$phpself = basename(__FILE__);
		error_Log("$phpself: LBWeb::readlanguage was moved to LBSystem::readlanguage. The call was redirected, but you should update your program.");
		return LBSystem::readlanguage($template, $genericlangfile, $syslang);
	}
		
	function get_plugin_icon($iconsize = 64)
	{
		global $lbshtmldir;
		global $lbpplugindir;
		
		if 		($iconsize > 256) { $iconsize = 512; }
		elseif	($iconsize > 128) { $iconsize = 256; }
		elseif	($iconsize > 64) { $iconsize = 128; }
		else					{ $iconsize = 64; }
		$logopath = "$lbshtmldir/images/icons/$lbpplugindir/icon_$iconsize.png";
		$logopath_web = "/system/images/icons/$lbpplugindir/icon_$iconsize.png";
	
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
		// error_log("LBTemplate construct: templatepath: $templatepath");
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
