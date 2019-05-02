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
require_once "loxberry_system.php";
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
$version = "1.4.1.1";

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

$template_title = $SL['COMMON.LOXBERRY_MAIN_TITLE'].": ". $SL['SERVICES.WIDGETLABEL']." v$sversion";

##########################################################################
# Main program
##########################################################################

#########################################################################
# What should we do
#########################################################################

# Menu
if (isset($_GET['check_webport'])) {
  check_webport();
} else if (isset($_GET['webport_success'])) {
	webport_success();
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
		$checkedssdp = "checked=\"checked\"";
	} else {
		$checkedssdp = "";
	}
		
	$output = exec('grep -E "console=(serial0|ttyAMA0|ttyS0)" /boot/cmdline.txt'); 
	if ($output) {
		$checkedconsole = "checked=\"checked\"";
	} else {
		$checkedconsole = "";
	}

	$output = exec('grep -E "^enable_uart=1" /boot/config.txt'); 
	if ($output) {
		$checkedserial = "checked=\"checked\"";
	} else {
		$checkedserial = "";
	}

	// Print Template
	//The Navigation Bar
	$navbar[0]['Name'] = $SL['SERVICES.TITLE_PAGE_WEBSERVER'];
	$navbar[0]['URL'] = 'services.php?load=1';
	$navbar[1]['Name'] = $SL['SERVICES.TITLE_PAGE_WATCHDOG'];
	$navbar[1]['URL'] = 'watchdog.cgi';
	$navbar[2]['Name'] = $SL['SERVICES.TITLE_PAGE_OPTIONS'];
	$navbar[2]['URL'] = 'services.php?load=3';
	if (isset($_GET['load']) && ($_GET['load'] == 2)) {
		$navbar[1]['active'] = True;
	} elseif (isset($_GET['load']) && ($_GET['load'] == 3)) {
		$navbar[2]['active'] = True;
	} else {
		$navbar[0]['active'] = True;
	}

	LBWeb::lbheader($template_title, $helplink, $helptemplate);

	if (isset($navbar[2]['active'])): ?>
	<form method="post" data-ajax="false" name="main_form" id="main_form" action="/admin/system/services.php?load=3">
	<input type="hidden" name="saveformdata" value="1">
	<input type="hidden" name="ssdpd" value="1">
	<input type="hidden" name="serial" value="1">
	<input type="hidden" name="console" value="1">
	<div class="wide"><?=$SL['SERVICES.HEADING_SSDP'];?></div>
	<br>
	<table class="formtable">
		<tr>
			<td width="20%">
				<label for ="ssdpenabled"><?=$SL['SERVICES.LABEL_SSDPENABLED'];?></label>
			</td>
			<td width="2%">&nbsp;</td>
			<td width="20%">
				<input data-role="flipswitch" type="checkbox" id="ssdpenabled" name="ssdpenabled" <?=$checkedssdp;?> value="enabled"/>
			</td>
			<td width="2%">&nbsp;</td>
			<td  class="hint">
				<?=$SL['SERVICES.HINT_SSDP'];?>
			</td>
		</tr>
	</table>
	<script>
	$( "#ssdpenabled" ).flipswitch({
		onText: "<?=$SL['COMMON.BUTTON_ON'];?>"
	});
	$( "#ssdpenabled" ).flipswitch({
		offText: "<?=$SL['COMMON.BUTTON_OFF'];?>"
	});
	</script>
	<br><br><br>
	<div class="wide"><?=$SL['SERVICES.HEADING_SERIAL'];?></div>
	<br>

	<?php
	$output = exec(LBHOMEDIR."/bin/showpitype"); 
	if ($output === "unknnown"): ?>
	<center>
	<div style="background: #FF8080; font-color: black; text-shadow: none; width: 80%; border: black 1px solid; padding: 5px">
	<p>
	<?=$SL['SERVICES.HINT_NOPI'];?>
	</p>
	</div>
	</center>
	<br>
	<?php endif;?>

	<table class="formtable">
		<tr>
			<td width="20%">
				<label for ="serialenabled"><?=$SL['SERVICES.LABEL_SERIAL'];?></label>
			</td>
			<td width="2%">&nbsp;</td>
			<td width="20%">
				<input data-role="flipswitch" type="checkbox" id="serialenabled" name="serialenabled" <?=$checkedserial;?> value="enabled"/>
			</td>
			<td width="2%">&nbsp;</td>
			<td  class="hint">
				<?=$SL['SERVICES.HINT_SERIAL'];?>
			</td>
		</tr>
	</table>
	<br>
	<table class="formtable">
		<tr>
			<td width="20%">
				<label for ="consoleenabled"><?=$SL['SERVICES.LABEL_CONSOLE'];?></label>
			</td>
			<td width="2%">&nbsp;</td>
			<td width="20%">
				<input data-role="flipswitch" type="checkbox" id="consoleenabled" name="consoleenabled" <?=$checkedconsole;?> value="enabled"/>
			</td>
			<td width="2%">&nbsp;</td>
			<td  class="hint">
				<?=$SL['SERVICES.HINT_CONSOLE'];?>
			</td>
		</tr>
	</table>
	<script>
	$( "#serialenabled" ).flipswitch({
		onText: "<?=$SL['COMMON.BUTTON_ON'];?>"
	});
	$( "#serialenabled" ).flipswitch({
		offText: "<?=$SL['COMMON.BUTTON_OFF'];?>"
	});
	$( "#consoleenabled" ).flipswitch({
		onText: "<?=$SL['COMMON.BUTTON_ON'];?>"
	});
	$( "#consoleenabled" ).flipswitch({
		offText: "<?=$SL['COMMON.BUTTON_OFF'];?>"
	});
	</script>
	</form>
	<br><br><br>
	<div style="text-align:center;">
			<a id="btncancel" data-role="button" data-inline="true" data-mini="true" data-icon="delete" href="<?=LBWeb::$lbsystempage;?>"><?=$SL['COMMON.BUTTON_CANCEL'];?></a>
			<button type="submit" form="main_form" name="btnsubmit" id="btnsubmit" data-role="button" data-inline="true" data-mini="true" data-icon="check"><?=$SL['COMMON.BUTTON_SAVE'];?></button>
	</div>


	<?php else: ?>
	<form method="post" data-ajax="false" name="main_form" id="main_form" action="/admin/system/services.php?load=1">
	<input type="hidden" name="saveformdata" value="1">
	<div class="wide"><?=$SL['SERVICES.HEADING_APACHE'];?></div>
	<br>
	<table class="formtable" style="border:0; width:100%;">
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
	<br>
	<div style="text-align:center;">
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
		
	</div>
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

	$output = exec('grep -E "^enable_uart=1" /boot/config.txt'); 
	if ($output) {
		$serialstatus = "1";
	} else {
		$serialstatus = "";
	}
	if (isset($_POST['serial'])) {
		if ($_POST['serialenabled'] === "enabled") {
			if (!$serialstatus) {
				reboot_required($SL['SERVICES.HINT_REBOOT']);
			}
			exec("sudo ".LBHOMEDIR."/sbin/setserial en_uart");
		} else {
			if ($serialstatus) {
				reboot_required($SL['SERVICES.HINT_REBOOT']);
			}
			exec("sudo ".LBHOMEDIR."/sbin/setserial dis_uart");
		}
	}

	$output = exec('grep -E "console=(serial0|ttyAMA0|ttyS0)" /boot/cmdline.txt'); 
	if ($output) {
		$consolestatus = "1";
	} else {
		$consolestatus = "";
	}
	if (isset($_POST['console'])) {
		if ($_POST['consoleenabled'] === "enabled") {
			if (!$consolestatus) {
				reboot_required($SL['SERVICES.HINT_REBOOT']);
			}
			exec("sudo ".LBHOMEDIR."/sbin/setserial en_console");
		} else {
			if ($consolestatus) {
				reboot_required($SL['SERVICES.HINT_REBOOT']);
			}
			exec("sudo ".LBHOMEDIR."/sbin/setserial dis_console");
		}
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
	# Return URL
	if (isset($_GET['load']) && ($_GET['load'] == 2)) {
		$returnurl="/admin/system/services.php?load=2";
	} elseif (isset($_GET['load']) && ($_GET['load'] == 3)) {
		$returnurl="/admin/system/services.php?load=3";
	} else {
		$returnurl="/admin/system/services.php?load=1";
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
		$href=$returnurl;
	} else if (isset($webport)) {
		if ($webport === "inuse" ) {
			$headermsg = $SL['SERVICES.ERR_PORT_IN_USE'];
			$resmsg = $SL['SERVICES.CHANGE_ABORTED'];
			$waitmsg = "";
			$href=$returnurl;
		} else {
			$cfg->set("WEBSERVER","PORT",$webport);
			$cfg->set("WEBSERVER","OLDPORT",$weboldport);
			$cfg->save();
			$headermsg = $SL['SERVICES.MSG_STEP1'];
			$resmsg = $SL['SERVICES.CHANGE_SUCCESS'];
			$waitmsg = $SL['SERVICES.WAITWEBSERVER1'];
			$waitmsg2 = $SL['SERVICES.WAITWEBSERVER2'];
			$sucheadermsg = $SL['SERVICES.MSG_STEP2'];
			$sucresmsg = $SL['SERVICES.CHANGE_WEBPORTCHANGED'];
			$href="/admin/system/services.php?check_webport=1";
		}
	} else if (isset($_POST['webport'])) {
		$headermsg = $SL['SERVICES.ERR_WRONG_PORT'];
		$resmsg = $SL['SERVICES.CHANGE_ABORTED'];
		$waitmsg = "";
		$href=$returnurl;
	}
		?>
		<div style="text-align:center;">
			<center>
			<table style="border:0;">
				<tr>
					<td align="center">
						<h2 id="headermsg"><?=$headermsg;?></h2>
						<p id="resmsg">
							<?=$resmsg?>
							<br/>
							<br/>
						</p>
						<p id="waitmsg">
							<?=$waitmsg;?>
						</p>
					</td>
				</tr>
				<tr>
					<td align="center">
						<p>
							<a id="btnok" data-role="button" data-inline="true" data-mini="true" data-icon="check" href="<?=$href;?>"><?=$SL['COMMON.BUTTON_OK'];?></a>
							<h2 id="moment" style="display: none"><?=$SL['COMMON.MSG_PLEASEWAIT'];?></h2>
						</p>
					</td>
				</tr>
			</table>
			</center>
		</div>
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
		$newhref .= "://".$_SERVER['SERVER_NAME'];
		if ($webport != 80) {$newhref .= ":$webport"; }
		$chkhref = $newhref."/system/servicehelper.php";
		$cnthref = "/admin/system/services.php?check_webport=1";
		$suchref = $newhref."/admin/system/services.php";
		echo "
		<script>
			sucheadermsg = \"$sucheadermsg\";
			sucresmsg = \"$sucresmsg\";
			waitmsg2 = \"$waitmsg2\";
			btnok = document.getElementById('btnok');
			btnok.style.display = 'none';
			document.getElementById('moment').style.display='';
			setTimeout(function(){
				$.get(\"$chkhref\")
	    		.done(function(data){
	    		console.log('chkhref aufgerufen');
	    			if(data.ok == -1) {
	    			console.log('chkhref hat -1 zurückgegeben');
    					$.get(\"$cnthref\")
    						.done(function(data){
    						console.log('cnthref aufgerufen');
    							if (data.ok == -1) {
    							console.log('cnthref hat -1 zurückgegeben');
    								document.getElementById('headermsg').innerHTML = sucheadermsg;
    								document.getElementById('resmsg').innerHTML = sucresmsg;
    								document.getElementById('waitmsg').innerHTML = waitmsg2;
    								setTimeout(function(){
    								  document.getElementById('moment').style.display='none';
											btnok.style.display = '';
											btnok.href = \"$suchref\";
										}, 6000);
    							}
    					})
    					.fail(function(){
    						console.log('Fehler beim Laden der cnthref');
    					});
	    			}
	    	});
	    }, 6000);
		</script>
		";
		exec("sudo ".LBHOMEDIR."/sbin/serviceshelper webport_change ".$webport." ".$weboldport." 2>/dev/null >/dev/null &");
	}
	LBWeb::lbfooter();
	exit;
}

#####################################################
# check_webport
#####################################################
function check_webport() {
	
	global $navbar;
	global $SL;
	global $template_title;
	global $helplink;
	global $helptemplate;

	$cfg      = new Config_Lite(LBSCONFIGDIR."/general.cfg",LOCK_EX,INI_SCANNER_RAW);
	$cfg->setQuoteStrings(False);

	// Print Template
	$headermsg = $SL['SERVICES.MSG_STEP2'];
	$resmsg = $SL['SERVICES.CHANGE_WEBPORTCHANGED'];
	$waitmsg = $SL['SERVICES.WEBSERVERCLEANING'];
	$webport = $cfg['WEBSERVER']['PORT'];
	$weboldport = $cfg['WEBSERVER']['OLDPORT'];

	header('Content-Type: application/json');
	echo "{ \"ok\": \"-1\" }";
	exec("sudo ".LBHOMEDIR."/sbin/serviceshelper webport_success ".$webport." ".$weboldport." 2>/dev/null >/dev/null &");

	exit;
}

#####################################################
# webport_success
#####################################################
function webport_success() {
	
	header('Content-Type: application/json');
	echo "{ \"ok\":\"-1\" }";
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
