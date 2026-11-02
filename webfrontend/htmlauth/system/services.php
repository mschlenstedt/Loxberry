<?php

# Copyright 2017-2020 Svethi for LoxBerry, info@sd-thierfelder.de
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
require_once "loxberry_json.php";

##########################################################################
# Variables
##########################################################################

$helplink = "https://wiki.loxberry.de/konfiguration/widget_help/widget_loxberry_services/start";
$helptemplate = "help_services.html";
$template_title;
$error;


##########################################################################
# Read Settings
##########################################################################

# Version of this script
$version = "3.0.0.7";

$sversion = LBSystem::lbversion();

$cfg = new LBJSON(LBSCONFIGDIR."/general.json");

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

$template_title = $SL['COMMON.LOXBERRY_MAIN_TITLE'].": ". $SL['SERVICES.WIDGETLABEL'];

##########################################################################
# Main program
##########################################################################

#########################################################################
# What should we do
#########################################################################

header("Expires; 0");
header("Expires: Tue, 01 Jan 1980 1:00:00 GMT");
header("Cache-Control: no-cache, must-revalidate, post-check=0, pre-check=0"); 
header("Cache-Control: max-age=0");
header("Pragma: no-cache");

# Menu
if (isset($_GET['finalize'])) {
	webserver_finalize_page();
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
	global $cfg;

	/* SSL */
        if( empty($cfg->Webserver->Sslenabled) ) {
                $cfg->Webserver->Sslenabled = false;
                $cfg->write();
                recreate_generalcfg();
        }
        if( empty($cfg->Webserver->Sslport) ) {
                $cfg->Webserver->Sslport = "443";
                $cfg->write();
                recreate_generalcfg();
        }

	if ( is_enabled( $cfg->Webserver->Sslenabled ) ) {
		$checkedssl = "checked=\"checked\"";
	} else {
		$checkedssl = "";
	}
	
	/* SSDP */
	if( empty($cfg->Ssdp->Disabled) ) {
		$cfg->Ssdp->Disabled = false;
		$cfg->write();
		recreate_generalcfg();
	}
	
	if ( is_disabled( $cfg->Ssdp->Disabled ) ) {
		$checkedssdp = "checked=\"checked\"";
	} else {
		$checkedssdp = "";
	}
	
	/* FTP Server */
	$ftpstate = ftp_state();
	if($ftpstate['ActiveState'] == "active" || $ftpstate['UnitFileState'] == "enabled") {
		$checkedftp = "checked=\"checked\"";
	} else {
		$checkedftp = "";
	}
	
	/* UART /Serial console */ 
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
	$navbar[1]['URL'] = 'services_watchdog.cgi';
	
	$navbar[4]['Name'] = $SL['HEADER.PANEL_TIMESERVER'];
	$navbar[4]['URL'] = 'services_timeserver.cgi';
	
	$navbar[5]['Name'] = "Samba (SMB)";
	$navbar[5]['URL'] = 'services_samba.cgi';
	
	$navbar[50]['Name'] = $SL['SERVICES.TITLE_PAGE_OPTIONS'];
	$navbar[50]['URL'] = 'services.php?load=3';
	
	if (isset($_GET['load']) && ($_GET['load'] == 2)) {
		$navbar[1]['active'] = True;
		$page = 2;
	} elseif (isset($_GET['load']) && ($_GET['load'] == 3)) {
		$navbar[50]['active'] = True;
		$page = 3;
	} else {
		$navbar[0]['active'] = True;
		$page = 0;
	}

	LBWeb::lbheader($template_title, $helplink, $helptemplate);
	
	if ($page == 3): ?>
	<form method="post" data-ajax="false" name="main_form" id="main_form" style="max-width:80%;margin:0 auto" action="/admin/system/services.php?load=3">
	<input type="hidden" name="saveformdata" value="1">
	<input type="hidden" name="ssdpd" value="1">
	<input type="hidden" name="serial" value="1">
	<input type="hidden" name="console" value="1">
	<div class="lb-section-title"><?=$SL['SERVICES.HEADING_SSDP'];?></div>
	<div class="lb-form-row">
		<div class="lb-form-label"></div>
		<div class="lb-form-field">
			<label><input type="checkbox" id="ssdpenabled" name="ssdpenabled" <?=$checkedssdp;?> value="enabled"> <?=$SL['SERVICES.LABEL_SSDPENABLED'];?></label>
		</div>
		<div class="lb-form-help hint"><?=$SL['SERVICES.HINT_SSDP'];?></div>
	</div>

	<?php
	/* FTP form part */
	?>
	<div class="lb-section-title"><?=$SL['SERVICES.HEADING_FTP'];?></div>
	<div class="lb-form-row">
		<div class="lb-form-label"></div>
		<div class="lb-form-field">
			<label><input type="checkbox" id="ftpenabled" name="ftpenabled" <?=$checkedftp;?> value="enabled"> <?=$SL['SERVICES.LABEL_FTP'];?></label>
		</div>
		<div class="lb-form-help hint"><?=$SL['SERVICES.HINT_FTP'];?></div>
	</div>

	<?php
	/* Serial form part */
	?>
	<div class="lb-section-title"><?=$SL['SERVICES.HEADING_SERIAL'];?></div>

	<?php
	$output = exec(LBHOMEDIR."/bin/showpitype");
	if ($output === "unknnown"): ?>
	<div style="background:#FF8080;color:black;text-shadow:none;max-width:80%;margin:0 auto;border:1px solid black;padding:5px;margin-bottom:8px">
		<?=$SL['SERVICES.HINT_NOPI'];?>
	</div>
	<?php endif;?>

	<div class="lb-form-row">
		<div class="lb-form-label"></div>
		<div class="lb-form-field">
			<label><input type="checkbox" id="serialenabled" name="serialenabled" <?=$checkedserial;?> value="enabled"> <?=$SL['SERVICES.LABEL_SERIAL'];?></label>
		</div>
		<div class="lb-form-help hint"><?=$SL['SERVICES.HINT_SERIAL'];?></div>
	</div>
	<div class="lb-form-row">
		<div class="lb-form-label"></div>
		<div class="lb-form-field">
			<label><input type="checkbox" id="consoleenabled" name="consoleenabled" <?=$checkedconsole;?> value="enabled"> <?=$SL['SERVICES.LABEL_CONSOLE'];?></label>
		</div>
		<div class="lb-form-help hint"><?=$SL['SERVICES.HINT_CONSOLE'];?></div>
	</div>

	</form>
	<div class="lb-actions">
		<a id="btncancel" class="lb-btn lb-btn-sm lb-btn-icon" href="<?=LBWeb::$lbsystempage;?>"><i class="pi pi-times"></i> <?=$SL['COMMON.BUTTON_CANCEL'];?></a>
		<button type="submit" form="main_form" name="btnsubmit" id="btnsubmit" class="lb-btn lb-btn-primary lb-btn-sm lb-btn-icon"><i class="pi pi-check"></i> <?=$SL['COMMON.BUTTON_SAVE'];?></button>
	</div>


	<?php else: ?>
	<form method="post" data-ajax="false" name="main_form" id="main_form" style="max-width:80%;margin:0 auto" action="/admin/system/services.php?load=1">
	<input type="hidden" name="saveformdata" value="1">
	<input type="hidden" id="web" name="web" value="0">
	<div class="lb-section-title"><?=$SL['SERVICES.HEADING_APACHE'];?></div>
	<div class="lb-form-row">
		<div class="lb-form-label">
			<label for="webport"><?=$SL['SERVICES.LABEL_WEBPORT'];?></label>
		</div>
		<div class="lb-form-field">
			<input placeholder="<?=$SL['SERVICES.HINT_INNER_WEBPORT'];?>" id="webport" name="webport" type="text" class="lb-input" data-validation-error-msg="<?=$SL['SERVICES.ERR_WRONG_PORT'];?>" data-validation-rule="special:port" value="<?=$cfg->Webserver->Port;?>">
		</div>
		<div class="lb-form-help">
			<div class="hint"><?=$SL['SERVICES.HINT_WEBPORT'];?></div>
		</div>
	</div>

	<div class="lb-form-row">
		<div class="lb-form-label">
			<label for="sslenabled"><?=$SL['SERVICES.LABEL_SSLENABLED'];?></label>
		</div>
		<div class="lb-form-field">
			<label class="lb-toggle"><input type="checkbox" id="sslenabled" name="sslenabled" <?=$checkedssl;?> value="enabled"><span class="lb-toggle-slider"></span></label>
		</div>
		<div class="lb-form-help">
			<div class="hint"><?=$SL['SERVICES.HINT_SSL'];?></div>
		</div>
	</div>

	<div class="lb-form-row">
		<div class="lb-form-label">
			<label for="sslport"><?=$SL['SERVICES.LABEL_SSLPORT'];?></label>
		</div>
		<div class="lb-form-field">
			<input placeholder="<?=$SL['SERVICES.HINT_INNER_SSLPORT'];?>" id="sslport" name="sslport" type="text" class="lb-input" data-validation-error-msg="<?=$SL['SERVICES.ERR_WRONG_SSLPORT'];?>" data-validation-rule="special:port" value="<?=$cfg->Webserver->Sslport;?>">
		</div>
		<div class="lb-form-help">
			<div class="hint"><?=$SL['SERVICES.HINT_SSLPORT'];?></div>
		</div>
	</div>

	<div class="lb-form-row">
		<div class="lb-form-label">
			<?=$SL['SERVICES.DOWNLOAD_CACERT'];?>
		</div>
		<div class="lb-form-field">
			<a class="lb-btn lb-btn-sm lb-btn-icon" mimetype="application/x-x509-ca-cert" href="/system/cacert.cer"><i class="pi pi-download"></i> cacert.cer</a>
		</div>
		<div class="lb-form-help">
			<div class="hint"><?=$SL['SERVICES.HINT_DOWNLOAD_CACERT'];?></div>
		</div>
	</div>

	<?php $pending = webserver_pending();
	if ($pending): ?>
	<div class="lb-form-row">
		<div class="lb-form-label"></div>
		<div class="lb-form-field" style="min-width:0">
			<div class="hint" style="color:var(--lb-color-warning, #b36b00)"><?=$SL['SERVICES.WEBSERVER_PENDING'];?></div>
			<div style="display:flex;flex-wrap:wrap;gap:8px;margin-top:8px">
				<a class="lb-btn lb-btn-sm lb-btn-primary lb-btn-icon" href="<?=htmlspecialchars($pending['finalizeurl']);?>"><i class="pi pi-check"></i> <?=$SL['SERVICES.BUTTON_FINALIZE'];?></a>
				<button type="submit" form="main_form" name="webrevert" value="1" class="lb-btn lb-btn-sm lb-btn-icon"><i class="pi pi-undo"></i> <?=$SL['SERVICES.BUTTON_REVERT'];?></button>
			</div>
		</div>
	</div>
	<?php endif; ?>

	</form>
	<div class="lb-actions">
		<a id="btncancel" class="lb-btn lb-btn-sm lb-btn-icon" href="<?=LBWeb::$lbsystempage;?>"><i class="pi pi-times"></i> <?=$SL['COMMON.BUTTON_CANCEL'];?></a>
		<button type="submit" form="main_form" name="btnsubmit" id="btnsubmit" class="lb-btn lb-btn-primary lb-btn-sm lb-btn-icon"><i class="pi pi-check"></i> <?=$SL['COMMON.BUTTON_SAVE'];?></button>
		<a id="btnlogs" class="lb-btn lb-btn-sm lb-btn-icon" href="/admin/system/tools/logfile.cgi?logfile=system_tmpfs/apache2/error.log&header=html&format=template" target="_blank"><i class="pi pi-arrow-down"></i> Apache Log</a>
	</div>
	
	
<script>

$(document).ready( function () {
	validate_enable('#sslport');
	validate_chk_object(['#sslport']);
	validate_enable('#webport');
	validate_chk_object(['#webport']);
});

</script>
	
	
	
	
	
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
	global $cfg;
	
	$ssdpstate_changed;
	$webserver_changed;
	$ssl_changed;

	/* SSDP */
	if (isset($_POST['ssdpenabled'])) {
		if ($_POST['ssdpenabled'] === "enabled") {
			$ssdpoff = false;
		} else {
			$ssdpoff = true;
		}
	} else if (isset($_POST['ssdpd'])) {
			$ssdpoff = true;
	}

	/* FTP Server */
	$ftpstate = ftp_state();
	if($ftpstate['ActiveState'] == "active" || $ftpstate['UnitFileState'] == "enabled") {
		$ftpactive = true;
	} else {
		$ftpactive = false;
	}
	if( !empty($_POST['ftpenabled']) and $_POST['ftpenabled'] == "enabled" ) {
		$ftp_switch = true;
	} else {
		$ftp_switch = false;
	}
	
	if( $ftpactive != $ftp_switch ) {
		error_log("ftp_changemode()");
		ftp_changemode($ftp_switch);
	}
	
	// Check if mode has changed and generate an error
	$ftpstate = ftp_state();
	if($ftpstate['ActiveState'] == "active" || $ftpstate['UnitFileState'] == "enabled") {
		$ftpactive = true;
	} else {
		$ftpactive = false;
	}
	if( $ftpactive != $ftp_switch ) {
		error_log("ftp check: ERROR Switch and State not equal");
		$error = $SL['SERVICES.ERR_FTP_SWITCH'];
		// Errors are handled nowhere....?
	}

	/* Serial */

	$output = exec('grep -E "^enable_uart=1" /boot/config.txt');
	$serialstatus = $output ? "1" : "";

	$output = exec('grep -E "console=(serial0|ttyAMA0|ttyS0)" /boot/cmdline.txt');
	$consolestatus = $output ? "1" : "";

	$serialenabled_req = (isset($_POST['serialenabled']) && $_POST['serialenabled'] === "enabled");
	$consoleenabled_req = (isset($_POST['consoleenabled']) && $_POST['consoleenabled'] === "enabled");

	// uart must be enabled if either serial interface OR serial console is requested
	if (isset($_POST['serial'])) {
		if ($serialenabled_req || $consoleenabled_req) {
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

	if (isset($_POST['console'])) {
		if ($consoleenabled_req) {
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

	/* Apache */
	$web = null;
	if (isset($_POST['webrevert'])) {
		$web = webserver_revert();
	} else if (isset($_POST['web'])) {
		$web = webserver_save();
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
	if ( isset($ssdpoff) && $ssdpoff != is_disabled( $cfg->Ssdp->Disabled ) ) {
		$ssdpstate_changed = 1;
	}

	$headermsg = $SL['COMMON.MSG_ALLOK'];
	$resmsg = $SL['SERVICES.CHANGE_SUCCESS'];
	$href = $returnurl;
	$redirect = "";
	$oldurl = "";
	if (isset($ssdpoff)){
		$cfg->Ssdp->Disabled = $ssdpoff;
		$cfg->write();
		recreate_generalcfg();
	}
	if ($web) {
		$headermsg = $web['header'];
		$resmsg = $web['msg'];
		if (!empty($web['redirect'])) {
			$redirect = $web['redirect'];
			$oldurl = $web['oldurl'];
			$href = $redirect;
		}
	}
		?>
		<div style="text-align:center;">
			<center>
			<table style="border:0;">
				<tr>
					<td align="center">
						<h2 id="headermsg"><?=$headermsg;?></h2>
						<p id="resmsg"><?=$resmsg?></p>
						<?php if ($redirect): ?>
						<p><?=$SL['SERVICES.WEBSERVER_REDIRECT'];?></p>
						<p><?=$SL['SERVICES.WEBSERVER_NEWADDRESS'];?>: <a href="<?=htmlspecialchars($redirect);?>"><?=htmlspecialchars(webserver_baseurl($redirect));?></a></p>
						<p class="hint"><?=$SL['SERVICES.WEBSERVER_OLDADDRESS'];?>: <a href="<?=htmlspecialchars($oldurl);?>"><?=htmlspecialchars(webserver_baseurl($oldurl));?></a></p>
						<?php endif; ?>
					</td>
				</tr>
				<tr>
					<td align="center">
						<p>
							<a id="btnok" class="lb-btn lb-btn-primary lb-btn-icon" href="<?=htmlspecialchars($href);?>"><i class="pi pi-check"></i> <?=$SL['COMMON.BUTTON_OK'];?></a>
						</p>
					</td>
				</tr>
			</table>
			</center>
		</div>
		<?php if ($redirect): ?>
		<script>
			// Apache reloads 2 s after the change - then load the new address in the browser
			// (a real navigation, so the browser can show its certificate warning and ask for the login)
			setTimeout(function() { window.location.href = <?=json_encode($redirect);?>; }, 6000);
		</script>
		<?php endif;
	if (isset($ssdpstate_changed) && $ssdpstate_changed == 1) {
		if ($ssdpoff) {
			exec("sudo ".LBHOMEDIR."/sbin/serviceshelper ssdpd stop");
		} else {
			exec("sudo ".LBHOMEDIR."/sbin/serviceshelper ssdpd restart");
		}
	}
	LBWeb::lbfooter();
	exit;
}

#####################################################
# Web server: HTTP port, HTTPS on/off, HTTPS port
#
# All three are applied together by sbin/webserverconfig.pl (via
# serviceshelper), in two steps:
#  apply     on "Save": Apache serves the old AND the new ports, the
#            browser is sent to the new address
#  finalize  when the page is loaded from the new address (?finalize=1):
#            the old ports are removed
# Until it is finalized, LoxBerry stays reachable on the old address.
#####################################################

// Current web server settings from general.json
function webserver_settings()
{
	global $cfg;
	$port = (string)$cfg->Webserver->Port;
	$sslport = (string)$cfg->Webserver->Sslport;
	return array(
		'port' => ctype_digit($port) ? (int)$port : 80,
		'ssl' => is_enabled($cfg->Webserver->Sslenabled) ? 1 : 0,
		'sslport' => ctype_digit($sslport) ? (int)$sslport : 443,
	);
}

function webserver_valid_port($p)
{
	return ctype_digit((string)$p) && (int)$p >= 1 && (int)$p <= 65535;
}

// Host the browser used, without port (IPv6 in brackets)
function webserver_host()
{
	$host = isset($_SERVER['HTTP_HOST']) ? $_SERVER['HTTP_HOST'] : $_SERVER['SERVER_ADDR'];
	if (preg_match('/^(\[[^\]]+\])(:\d+)?$/', $host, $m)) {
		return $m[1];
	}
	return preg_replace('/:\d+$/', '', $host);
}

function webserver_url($https, $port, $path)
{
	$url = ($https ? "https" : "http") . "://" . webserver_host();
	if (($https && $port != 443) || (!$https && $port != 80)) {
		$url .= ":" . $port;
	}
	return $url . $path;
}

function webserver_baseurl($url)
{
	return preg_replace('#^(https?://[^/]+).*$#', '$1', $url);
}

function webserver_request_https()
{
	return !empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off';
}

// Address to finalize a change: HTTPS if it was switched on or its port changed,
// HTTP if HTTPS was switched off, otherwise the protocol of this page
function webserver_finalize_url($old, $new)
{
	if (!$new['ssl']) {
		$https = false;
	} else if (!$old['ssl'] || $old['sslport'] != $new['sslport']) {
		$https = true;
	} else {
		$https = webserver_request_https();
	}
	return webserver_url($https, $https ? $new['sslport'] : $new['port'], "/admin/system/services.php?finalize=1");
}

// Runs the root helper; returns array(exitcode, result line)
// The result line starts with OK, ERROR or INUSE - other output (warnings) is ignored.
function webserver_helper($action, $s)
{
	$out = array();
	$rc = 0;
	exec("sudo ".LBHOMEDIR."/sbin/serviceshelper webserver_".$action." ".(int)$s['port']." ".(int)$s['ssl']." ".(int)$s['sslport']." 2>&1", $out, $rc);
	$result = "";
	foreach ($out as $line) {
		if (preg_match('/^(OK|ERROR|INUSE)\b/', $line)) {
			$result = $line;
		}
	}
	if ($result === "") {
		$result = implode(" ", $out);
	}
	return array($rc, $result);
}

function webserver_result($header, $msg)
{
	return array('header' => $header, 'msg' => $msg);
}

function webserver_save()
{
	global $cfg, $SL;
	$old = webserver_settings();
	$new = array(
		'port' => trim(isset($_POST['webport']) ? $_POST['webport'] : ''),
		'ssl' => isset($_POST['sslenabled']) ? 1 : 0,
		'sslport' => trim(isset($_POST['sslport']) ? $_POST['sslport'] : ''),
	);
	if (!webserver_valid_port($new['port'])) {
		return webserver_result($SL['SERVICES.ERR_WRONG_PORT'], $SL['SERVICES.CHANGE_ABORTED']);
	}
	if (!webserver_valid_port($new['sslport'])) {
		return webserver_result($SL['SERVICES.ERR_WRONG_SSLPORT'], $SL['SERVICES.CHANGE_ABORTED']);
	}
	$new['port'] = (int)$new['port'];
	$new['sslport'] = (int)$new['sslport'];
	if ($new['port'] == $new['sslport']) {
		return webserver_result($SL['SERVICES.ERR_SAME_PORT'], $SL['SERVICES.CHANGE_ABORTED']);
	}
	if ($new == $old && !webserver_pending()) {
		return null;
	}
	return webserver_change($old, $new);
}

// Discard a change that was not finalized: back to the previous settings
function webserver_revert()
{
	global $cfg, $SL;
	$cur = webserver_settings();
	$prev = array(
		'port' => webserver_valid_port((string)$cfg->Webserver->Oldport) ? (int)$cfg->Webserver->Oldport : $cur['port'],
		'ssl' => isset($cfg->Webserver->Oldsslenabled) ? (is_enabled($cfg->Webserver->Oldsslenabled) ? 1 : 0) : $cur['ssl'],
		'sslport' => webserver_valid_port((string)$cfg->Webserver->Oldsslport) ? (int)$cfg->Webserver->Oldsslport : $cur['sslport'],
	);
	return webserver_change($cur, $prev);
}

function webserver_change($old, $new)
{
	global $cfg, $SL;
	list($rc, $out) = webserver_helper("apply", $new);
	if ($rc == 3) {
		return webserver_result($SL['SERVICES.ERR_PORT_IN_USE'], $SL['SERVICES.CHANGE_ABORTED']);
	}
	if ($rc != 0 || strpos($out, "OK") !== 0) {
		// no "OK" line: the helper failed or does not know the action
		error_log("webserver apply failed ($rc): $out");
		return webserver_result($SL['SERVICES.ERR_PORTCHANGE'], $SL['SERVICES.CHANGE_ABORTED']." ".htmlspecialchars($out));
	}
	$cfg->Webserver->Oldport = (string)$old['port'];
	$cfg->Webserver->Oldsslport = (string)$old['sslport'];
	$cfg->Webserver->Oldsslenabled = $old['ssl'] ? true : false;
	$cfg->Webserver->Port = (string)$new['port'];
	$cfg->Webserver->Sslport = (string)$new['sslport'];
	$cfg->Webserver->Sslenabled = $new['ssl'] ? true : false;
	$cfg->write();
	recreate_generalcfg();

	$r = webserver_result($SL['SERVICES.WEBSERVER_SWITCHING'], $SL['SERVICES.CHANGE_SUCCESS']);
	$r['redirect'] = webserver_finalize_url($old, $new);
	$r['oldurl'] = webserver_url(webserver_request_https(), (int)$_SERVER['SERVER_PORT'], "/admin/system/services.php");
	return $r;
}

// Ports of the first <VirtualHost ...> line of a file
function webserver_vhost_ports($file)
{
	$c = @file_get_contents($file);
	if ($c === false || !preg_match('/^[ \t]*<VirtualHost\b([^>]*)>/mi', $c, $m)) {
		return array();
	}
	preg_match_all('/:(\d+)\b/', $m[1], $p);
	$ports = array_map('intval', $p[1]);
	sort($ports);
	return array_values(array_unique($ports));
}

// A change that is not finalized yet: Apache serves other ports than general.json says.
// Returns false or array('finalizeurl' => ...)
function webserver_pending()
{
	$s = webserver_settings();
	$dir = LBHOMEDIR."/system/apache2";
	$http = webserver_vhost_ports("$dir/sites-available/000-default.conf");
	$sslon = file_exists("$dir/sites-enabled/001-default-ssl.conf");
	$https = webserver_vhost_ports("$dir/sites-available/001-default-ssl.conf");
	$pending = ($http != array($s['port']))
		|| ($sslon != (bool)$s['ssl'])
		|| ($s['ssl'] && $https != array($s['sslport']));
	if (!$pending) {
		return false;
	}
	$https_target = $s['ssl'] && webserver_request_https();
	return array('finalizeurl' => webserver_url($https_target, $https_target ? $s['sslport'] : $s['port'], "/admin/system/services.php?finalize=1"));
}

// ?finalize=1 - the browser arrived on the new address
function webserver_finalize_page()
{
	global $SL, $template_title, $helplink, $helptemplate, $navbar;
	$s = webserver_settings();
	$https = webserver_request_https();
	$reqport = (int)$_SERVER['SERVER_PORT'];
	$ontarget = (!$https && $reqport == $s['port']) || ($https && $s['ssl'] && $reqport == $s['sslport']);
	$headermsg = $SL['COMMON.MSG_ALLOK'];
	$resmsg = $SL['SERVICES.WEBSERVER_FINALIZED'];
	$href = "/admin/system/services.php?load=1";
	if (!webserver_pending()) {
		// nothing to do (e.g. page reloaded)
	} else if (!$ontarget) {
		$headermsg = $SL['SERVICES.WEBSERVER_SWITCHING'];
		$resmsg = $SL['SERVICES.WEBSERVER_NOTTARGET'];
		$href = $s['ssl'] ? webserver_url(true, $s['sslport'], "/admin/system/services.php?finalize=1") : webserver_url(false, $s['port'], "/admin/system/services.php?finalize=1");
	} else {
		list($rc, $out) = webserver_helper("finalize", $s);
		if ($rc != 0 || strpos($out, "OK") !== 0) {
			error_log("webserver finalize failed ($rc): $out");
			$headermsg = $SL['SERVICES.ERR_PORTCHANGE'];
			$resmsg = htmlspecialchars($out);
		}
	}
	LBWeb::lbheader($template_title, $helplink, $helptemplate);
	?>
	<div style="text-align:center;">
		<h2><?=$headermsg;?></h2>
		<p><?=$resmsg;?></p>
		<p><a class="lb-btn lb-btn-primary lb-btn-icon" href="<?=htmlspecialchars($href);?>"><i class="pi pi-check"></i> <?=$SL['COMMON.BUTTON_OK'];?></a></p>
	</div>
	<?php
	LBWeb::lbfooter();
	exit;
}

#####################################################
# check ftp state
#####################################################
function ftp_state() {
	$vsftpoutput = trim (shell_exec("sudo systemctl show -p UnitFileState -p ActiveState vsftpd.service") );
	// error_log("vsftpoutput: ".$vsftpoutput);
	if(!empty($vsftpoutput)) {
		$ftplines = explode( "\n", $vsftpoutput, 10 );
		foreach($ftplines as $line) {
			// error_log("ftpline: ".$line);
			$linearr = explode ( '=', $line, 2 );
			$ftpstate[$linearr[0]] = $linearr[1];
		}
	} 
	return($ftpstate);
}

#####################################################
# change ftp mode
#####################################################
function ftp_changemode($switch) {
	if($switch == true) {
		shell_exec("sudo systemctl --quiet start vsftpd.service");
		shell_exec("sudo systemctl --quiet enable vsftpd.service");
	} else {
		shell_exec("sudo systemctl --quiet stop vsftpd.service");
		shell_exec("sudo systemctl --quiet disable vsftpd.service");
	}	
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

#####################################################
# Recreate general.cfg from general.json
#####################################################
function recreate_generalcfg() 
	{
		// If the general.json is changed, we require to manually 
		// trigger the recreation of the new general.cfg
		exec( LBSHTMLAUTHDIR."/ajax/ajax-config-handler.cgi action=recreate-generalcfg");
	}

?>
