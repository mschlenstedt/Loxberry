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
$version = "0.3.1-dev1";

$sversion = LBSystem::lbversion();

$cfg	  = new Config_Lite(LBSCONFIGDIR."/general.cfg",LOCK_EX,INI_SCANNER_RAW);
$cfg->setQuoteStrings(False);

#########################################################################
# Parameter
#########################################################################

# Set default if not available
if (!$cfg->has("SSDP","DISABLED")) {
	$cfg->set("SSDP","DISABLED", 0);
	$cfg->save();
}

##########################################################################
# Language Settings
##########################################################################

if (isset($_GET['lang'])) {
	# Nice feature: We override language detection of LoxBerry::Web
	#LBWeb::lang() = substr($_GET['lang'], 0, 2);
}
# If we did the 'override', lblanguage will give us that language
$lang = LBWeb::lblanguage();

$SL = LBWeb::readlanguage($maintemplate,"language.ini",True);

$template_title = $SL['COMMON.LOXBERRY_MAIN_TITLE'].":". $SL['SERVICES.WIDGETLABEL']." v$sversion";

##########################################################################
# Main program
##########################################################################

#########################################################################
# What should we do
#########################################################################

# Menu
if (!isset($_POST['saveformdata'])) {
  form();
} else {
  save();
}

exit;

#####################################################
# Form / Menu
#####################################################

function form() {

	global $SL;
	global $navbar;
	
	$cfg      = new Config_Lite(LBSCONFIGDIR."/general.cfg",LOCK_EX,INI_SCANNER_RAW);
	$cfg->setQuoteStrings(False);

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
	if ($_GET['load'] == 2) {
		$navbar[1]['active'] = True;
	} else {
		$navbar[0]['active'] = True;
	}

	LBWeb::lbheader($template_title, $helplink, $helptemplate);
	if ($navbar[1]['active']): ?>
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
			<a id="btncancel" data-role="button" data-inline="true" data-mini="true" data-icon="delete" href="/admin/system/services.php?load=2&reload"><?=$SL['COMMON.BUTTON_CANCEL'];?></a>
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
			<input placeholder="<?=$SL['SERVICES.HINT_INNER_WEBPORT'];?>" id="webport" name="webport" type="text" style="min-width:15em" class="textfield" value="<?=$cfg['WEBSERVER']['PORT'];?>">
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
			<a id="btncancel" data-role="button" data-inline="true" data-mini="true" data-icon="delete" href="/admin/system/services.php"><?=$SL['COMMON.BUTTON_CANCEL'];?></a>
			<button type="submit" form="main_form" name="btnsubmit" id="btnsubmit" data-role="button" data-inline="true" data-mini="true" data-icon="check"><?=$SL['COMMON.BUTTON_SAVE'];?></button>
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
			$webport = $_POST['webport'];
			if ($webport != $cfg['WEBSERVER']['PORT']) {
				$webserver_changed = True;
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
	if ($ssdpoff != $cfg->getBool('SSDP','DISABLED',false)) {
		$ssdpstate_changed = 1;
	}
	
	if (isset($ssdpoff)){
		$cfg->set("SSDP","DISABLED", $ssdpoff);
		$cfg->save();
		$headermsg = $SL['COMMON.MSG_ALLOK'];
		$resmsg = $SL['SERVICES.CHANGE_SUCCESS'];
		$waitmsg = "";
	} else if (isset($webport)) {
		$cfg->set("WEBSERVER","PORT",$webport);
		$cfg->save();
		$headermsg = $SL['COMMON.MSG_ALLOK'];
		$resmsg = $SL['SERVICES.CHANGE_SUCCESS'];
		$waitmsg = $SL['SERVICES.WAITWEBSERVER'];
	} else if (isset($_POST['webport'])) {
		$headermsg = $SL['SERVICES.ERR_WRONG_PORT'];
		$resmsg = $SL['SERVICES.CHANGE_ABORTED'];
		$waitmsg = "";
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
							<a id="btnok" data-role="button" data-inline="true" data-mini="true" data-icon="check" href="/admin/system/services.php"><?=$SL['COMMON.BUTTON_OK'];?></a>
						</p>
					</td>
				</tr>
			</table>
		</center>
	<?php
	if ($ssdpstate_changed == 1) {
		system("sudo /opt/loxberry/sbin/serviceshelper ssdpd restart");
	} else if ($webserver_changed == True) {
		system("sudo /opt/loxberry/sbin/serviceshelper change_webport");
		$newhref = "http";
		if ($_SERVER['HTTPS']) { $newhref .= "s"; }
		$newhref .= "://".$_SERVER['SERVER_ADDR'].":".$webport."/";
		echo "
		<script>
			btnok = document.getElementById('btnok');
			btnok.style.display = 'none';
			function setHREF() {
				btnok.style.display = '';
				btnok.href = \"$newhref\";
			}
			setTimeout(setHREF,10000);
		</script>
		";
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
	LBWeb::readlanguage($maintemplate);
	LBWeb::lbheader($template_title, $helplink, $helptemplate);
	print $maintemplate->output();
	LBWeb::lbfooter();
	exit;

}

?>
