<?php

# Copyright 2017 Svethi for LoxBerry, info@sd-thierfelder.de
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


##########################################################################
# Modules
##########################################################################

require_once "loxberry_web.php";
require_once "Config/Lite.php";

##########################################################################
# Variables
##########################################################################

$helplink = "http://www.loxwiki.eu/display/LOXBERRY/LoxBerry";
$helptemplate = "help_services.html";
$template_title;
$error;


##########################################################################
# Read Settings
##########################################################################

# Version of this script
$version = "0.3.3.1";

$sversion = LBSystem::lbversion();

//$cfg	  = new Config_Lite(LBSCONFIGDIR."/general.cfg",LOCK_EX,INI_SCANNER_RAW);
//$cfg->setQuoteStrings(False);

#########################################################################
# Parameter
#########################################################################

# Set default if not available
//if (!$cfg->has("SSDP","DISABLED")) {
//	$cfg->set("SSDP","DISABLED", 0);
//	$cfg->save();
//}

##########################################################################
# Language Settings
##########################################################################

if (isset($_GET['lang'])) {
	# Nice feature: We override language detection of LoxBerry::Web
	#LBWeb::lang() = substr($_GET['lang'], 0, 2);
}
# If we did the 'override', lblanguage will give us that language
$lang = LBSystem::lblanguage();

$SL = LBSystem::readlanguage(NULL, "language.ini", True);

$template_title = $SL['COMMON.LOXBERRY_MAIN_TITLE'].":". $SL['SERVICES.WIDGETLABEL']." v$sversion";

##########################################################################
# Main program
##########################################################################

#########################################################################
# What should we do
#########################################################################

# Menu
if (isset($_GET['check_webport'])) {
  check_webport();
} else if (isset($_POST['saveformdata'])) {
  save();
} else {
  form();
}

exit;

#####################################################
# Form / Menu
#####################################################

function form() {

	global $SL;
	global $navbar;
	global $template_title;
	global $helplink;
	global $helptemplate;
	
	$cfg      = new Config_Lite(LBSCONFIGDIR."/general.cfg",LOCK_EX,INI_SCANNER_RAW);
	$cfg->setQuoteStrings(False);
	
	//set default if doesn't exist
	if (!$cfg->has("SSDP","DISABLED")) {
		$cfg->set("SSDP","DISABLED", 0);
		$cfg->save();
	}

	if ($cfg->getBool('SSDP','DISABLED',false)==false) {
		$checked = " checked=\"checked\"";
	} else {
		$checked = "";
	}
		
	// Print Template
	//The Navigation Bar
	$navbar[0]['Name'] = $SL['HEADER.TITLE_PAGE_WEBSERVER'];
	$navbar[0]['URL'] = 'services.php?load=1';
	$navbar[1]['Name'] = $SL['HEADER.TITLE_PAGE_OPTIONS'];
	$navbar[1]['URL'] = 'services.php?load=2';
	if (isset($_GET['load']) && ($_GET['load'] == 2)) {
		$navbar[1]['active'] = True;
	} else {
		$navbar[0]['active'] = True;
	}

	LBWeb::lbheader($template_title, $helplink, $helptemplate);
	if (isset($navbar[1]['active'])): ?>
	<form method="post" data-ajax="false" name="main_form" id="main_form" action="/admin/system/services.php?load=2">
	<input type="hidden" name="saveformdata" value="1">
	<input type="hidden" name="ssdpd" value="1">
	<p>
	<div class="wide"><?=$SL['SERVICES.HEADING_OPT'];?></div>
	</p>

	<table class="formtable">
		<tr>
			<td>
			<fieldset data-role="controlgroup" style="min-width:15em" data-mini="true">
				<label><input type="checkbox" name="ssdpenabled"<?=$checked;?> value="enabled"/><?=$SL['SERVICES.LABEL_SSDPENABLED'];?></label>
				</fieldset>
			</td>
			<td>&nbsp;
			</td><td  class="hint">
				<?=$SL['SERVICES.HINT_SSDP'];?>
			</td>
		</tr>
	</table>
	</form>
	<center>
		<p>
			<a id="btncancel" data-role="button" data-inline="true" data-mini="true" data-icon="delete" href="<?=LBWeb::$lbsystempage;?>"><?=$SL['COMMON.BUTTON_CANCEL'];?></a>
			<button type="submit" form="main_form" name="btnsubmit" id="btnsubmit" data-role="button" data-inline="true" data-mini="true" data-icon="check"><?=$SL['COMMON.BUTTON_SAVE'];?></button>
		</p>
	</center>
	<?php else: ?>
	<form method="post" data-ajax="false" name="main_form" id="main_form" action="/admin/system/services.php?load=1">
	<input type="hidden" name="saveformdata" value="1">
	<p>
	<div class="wide"><?=$SL['SERVICES.HEADING_APACHE'];?></div>
	</p>
	<table class="formtable" border="0" width="100%">
		<tr>
			<td>
			<label for="webport"><?=$SL['SERVICES.LABEL_WEBPORT'];?></label>
			<input placeholder="<?=$SL['SERVICES.HINT_INNER_WEBPORT'];?>" id="webport" name="webport" type="text" style="min-width:15em" class="textfield" data-validation-error-msg="<?=$SL['SERVICES.ERR_WRONG_PORT'];?>" data-validation-rule="special:port" value="<?=$cfg['WEBSERVER']['PORT'];?>">
			<script>
				$(document).ready( function ()
				{
					validate_enable('#webport');
					validate_chk_object(['#webport']);
				});
			</script>
			</td>
			<td>&nbsp;
			</td>
			<td class="hint">
			<?=$SL['SERVICES.HINT_WEBPORT'];?>
			</td>
		</tr>
	</table>
	</form>
	<center>
		<p>
			<a id="btncancel" data-role="button" data-inline="true" data-mini="true" data-icon="delete" href="<?=LBWeb::$lbsystempage;?>"><?=$SL['COMMON.BUTTON_CANCEL'];?></a>
			<button type="submit" form="main_form" name="btnsubmit" id="btnsubmit" data-role="button" data-inline="true" data-mini="true" data-icon="check"><?=$SL['COMMON.BUTTON_SAVE'];?></button>
			<pre> </pre>
			<a id="btnlogs" data-role="button" href="/admin/system/tools/logfile.cgi?logfile=system_tmpfs/apache2/error.log&header=html&format=template" target="_blank" data-inline="true" data-mini="true" data-icon="arrow-d">Apache Log</a>
			<!-- 
			<a id="btnlogs" data-role="button" href="/admin/system/tools/logfile.cgi?logfile=system_tmpfs/lighttpd/error.log&header=html&format=template" target="_blank" data-inline="true" data-mini="true" data-icon="arrow-d">Webserver Log</a>
			--> 
			<!-- 
			<a id="btnlogs" data-role="button" href="/admin/system/tools/logfile.cgi?logfile=system_tmpfs/lighttpd/cgierr.log&header=html&format=template" target="_blank" data-inline="true" data-mini="true" data-icon="arrow-d">Webserver Script Errorlog</a>
			-->
		</p>
	</center>
	<?php endif;

	LBWeb::lbfooter();
	exit;

}

#####################################################
# 
# Subroutines
#
#####################################################

#####################################################
# Save
#####################################################
function save()
{
	global $navbar;
	global $SL;
	global $template_title;
	global $helplink;
	global $helptemplate;
	
	$ssdpstate_changed;
	$webserver_changed;

	$cfg      = new Config_Lite(LBSCONFIGDIR."/general.cfg",LOCK_EX,INI_SCANNER_RAW);
	$cfg->setQuoteStrings(False);
	
	if (isset($_POST['ssdpenabled'])) {
		if ($_POST['ssdpenabled'] === "enabled") {
			$ssdpoff = false;
		} else {
			$ssdpoff = true;
		}
	} else if (isset($_POST['ssdpd'])) {
			$ssdpoff = true;
	}
	
	if (isset($_POST['webport'])) {
		if ($_POST['webport'] > 0 && $_POST['webport'] < 65535) {
			$tmp = exec("netstat -tnap | egrep ':".$_POST['webport']." .*LISTEN'");
			if ( $tmp === "" ) {
				$webport = $_POST['webport'];
				if ($webport != $cfg['WEBSERVER']['PORT']) {
					$webserver_changed = True;
					$weboldport = $cfg['WEBSERVER']['PORT'];
				}
			} else {
				$webport = 'inuse';
			}
 		}
	}
	
	
	// Print Template
	//The Navigation Bar
	$navbar[0]['Name'] = $SL['HEADER.TITLE_PAGE_WEBSERVER'];
	$navbar[0]['URL'] = 'services.php?load=1';
	$navbar[1]['Name'] = $SL['HEADER.TITLE_PAGE_OPTIONS'];
	$navbar[1]['URL'] = 'services.php?load=2';
	if ($_GET['load'] == 2) {
		$navbar[1]['active'] = True;
	} else {
		$navbar[0]['active'] = True;
	}

	LBWeb::lbheader($template_title, $helplink, $helptemplate);
	if (isset($ssdpoff) && $ssdpoff != $cfg->getBool('SSDP','DISABLED',false)) {
		$ssdpstate_changed = 1;
	}
	
	if (isset($ssdpoff)){
		$cfg->set("SSDP","DISABLED", $ssdpoff);
		$cfg->save();
		$headermsg = $SL['COMMON.MSG_ALLOK'];
		$resmsg = $SL['SERVICES.CHANGE_SUCCESS'];
		$waitmsg = "";
		$href=LBWeb::$lbsystempage;
	} else if (isset($webport)) {
		if ($webport === "inuse" ) {
			$headermsg = $SL['SERVICES.ERR_PORT_IN_USE'];
			$resmsg = $SL['SERVICES.CHANGE_ABORTED'];
			$waitmsg = "";
			$href=LBWeb::$lbsystempage;
		} else {
			$cfg->set("WEBSERVER","PORT",$webport);
			$cfg->set("WEBSERVER","OLDPORT",$weboldport);
			$cfg->save();
			$headermsg = $SL['SERVICES.MSG_STEP1'];
			$resmsg = $SL['SERVICES.CHANGE_SUCCESS'];
			$waitmsg = $SL['SERVICES.WAITWEBSERVER'];
			$href="/admin/system/services.php?check_webport=1";
		}
	} else if (isset($_POST['webport'])) {
		$headermsg = $SL['SERVICES.ERR_WRONG_PORT'];
		$resmsg = $SL['SERVICES.CHANGE_ABORTED'];
		$waitmsg = "";
		$href=LBWeb::$lbsystempage;
	}
		?>
		<center>
			<table border=0>
				<tr>
					<td align="center">
						<h2><?=$headermsg;?></h2>
						<p>
							<?=$resmsg?>
							<br/>
							<br/>
						</p>
						<p>
							<?=$waitmsg;?>
					</td>
				</tr>
				<tr>
					<td align="center">
						<p>
							<a id="btnok" data-role="button" data-inline="true" data-mini="true" data-icon="check" href="<?=$href;?>"><?=$SL['SERVICES.BTN_CONT'];?></a>
						</p>
					</td>
				</tr>
			</table>
		</center>
	<?php
	if (isset($ssdpstate_changed) && $ssdpstate_changed == 1) {
		if ($ssdpoff) {
			exec("sudo ".LBHOMEDIR."/sbin/serviceshelper ssdpd stop");
		} else {
			exec("sudo ".LBHOMEDIR."/sbin/serviceshelper ssdpd restart");
		}
	} else if (isset($webserver_changed) && $webserver_changed == True) {
		$newhref = "http";
		if ($_SERVER['HTTPS']) { $newhref .= "s"; }
		$newhref .= "://".$_SERVER['SERVER_NAME'].":".$webport."/admin/system/services.php?check_webport=1";
		echo "
		<script>
			btnok = document.getElementById('btnok');
			btnok.style.display = 'none';
			function setHREF() {
				btnok.style.display = '';
				btnok.href = \"$newhref\";
			}
			setTimeout(setHREF,5000);
		</script>
		";
		exec("sudo ".LBHOMEDIR."/sbin/serviceshelper webport_change ".$webport." ".$weboldport." 2>/dev/null >/dev/null &");
	}
	LBWeb::lbfooter();
	exit;
}

function check_webport() {
	
	global $navbar;
	global $SL;
	global $template_title;
	global $helplink;
	global $helptemplate;

	$cfg      = new Config_Lite(LBSCONFIGDIR."/general.cfg",LOCK_EX,INI_SCANNER_RAW);
	$cfg->setQuoteStrings(False);

	// Print Template
	//The Navigation Bar
	$navbar[0]['Name'] = $SL['HEADER.TITLE_PAGE_WEBSERVER'];
	$navbar[0]['URL'] = 'services.php?load=1';
	$navbar[1]['Name'] = $SL['HEADER.TITLE_PAGE_OPTIONS'];
	$navbar[1]['URL'] = 'services.php?load=2';
	if ($_GET['load'] == 2) {
		$navbar[1]['active'] = True;
	} else {
		$navbar[0]['active'] = True;
	}

	LBWeb::lbheader($template_title, $helplink, $helptemplate);
	if ($_SERVER['SERVER_PORT'] != $cfg['WEBSERVER']['PORT']) {
		$headermsg = $SL['SERVICES.ERR_PORTCHANGE'];
		$resmsg = $SL['SERVICES.CHANGE_ABORTED'];
		$waitmsg = "";
	} else {
		$headermsg = $SL['SERVICES.MSG_STEP2'];
		$resmsg = $SL['SERVICES.CHANGE_WEBPORTCHANGED'];
		$waitmsg = $SL['SERVICES.WEBSERVERCLEANING'];
		$webport = $cfg['WEBSERVER']['PORT'];
		$weboldport = $cfg['WEBSERVER']['OLDPORT'];
	}
	?>
		<center>
			<table border=0>
				<tr>
					<td align="center">
						<h2><?=$headermsg;?></h2>
						<p>
							<?=$resmsg?>
							<br/>
							<br/>
						</p>
						<p>
							<?=$waitmsg;?>
					</td>
				</tr>
				<tr>
					<td align="center">
						<p>
							<a id="btnok" data-role="button" data-inline="true" data-mini="true" data-icon="check" href="<?=LBWeb::$lbsystempage;?>"><?=$SL['COMMON.BUTTON_OK'];?></a>
						</p>
					</td>
				</tr>
			</table>
		</center>
	<?php
	if ($waitmsg != "") {
		echo "
		<script>
			btnok = document.getElementById('btnok');
			btnok.style.display = 'none';
			function setHREF() {
				btnok.style.display = '';
			}
			setTimeout(setHREF,6000);
		</script>
		";
		exec("sudo ".LBHOMEDIR."/sbin/serviceshelper webport_success ".$webport." ".$weboldport." 2>/dev/null >/dev/null &");
	}
	LBWeb::lbfooter();
	exit;
}


#####################################################
# Error
#####################################################

function error() {
	$maintemplate = new LBTemplate(LBSTEMPLATEDIR."/error.html");
	$maintemplate->param( "ERROR", $error);
	LBSystem::readlanguage($maintemplate);
	LBWeb::lbheader($template_title, $helplink, $helptemplate);
	print $maintemplate->output();
	LBWeb::lbfooter();
	exit;

}

?>
