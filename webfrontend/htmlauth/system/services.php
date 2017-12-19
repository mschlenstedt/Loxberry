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

$cfg;

##########################################################################
# Read Settings
##########################################################################

# Version of this script
$version = "0.3.1-dev1";

$sversion = LBSystem::lbversion();

$cfg	  = new Config_Lite(LBSCONFIGDIR."/general.cfg",LOCK_EX);

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

$maintemplate = new LBTemplate(LBSTEMPLATEDIR."/services.html");

$SL = LBWeb::readlanguage($maintemplate,"language.ini",True);

$template_title = $SL['COMMON.LOXBERRY_MAIN_TITLE'].":". $SL['SERVICES.WIDGETLABEL']." v$sversion";

##########################################################################
# Main program
##########################################################################

#########################################################################
# What should we do
#########################################################################

# Menu
if (!isset($_GET['saveformdata'])) {
  form();
} else {
  save();
}

exit;

#####################################################
# Form / Menu
#####################################################

function form() {

	global $maintemplate;
	global $cfg;
	global $SL;

	$maintemplate->param( "FORM", 1);
	$maintemplate->param ("SELFURL", $_SERVER['REQUEST_URI']);

	if ($cfg['SSDP']['DISABLED']==0) {
		$checked = " checked=\"checked\"";
	} else {
		$checked = "";
	}
	$ssdp_checkbox = "<input type=\"checkbox\" name=\"ssdpdisabled\"$checked label=\"".$SL['SERVICES.LABEL_SSDPENABLED']."\">";

	$maintemplate->param('SSDP_CHECKBOX', $ssdp_checkbox);
		
	# Print Template
	#LoxBerry::Web::lbheader($template_title, $helplink, $helptemplate);
	LBWeb::lbheader($template_title, $helplink, $helptemplate);
	print $maintemplate->output();
	LBWeb::lbfooter();
	#LoxBerry::Web::lbfooter();
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
	$ssdpd_changed;

	$maintemplate->param( "SAVE", 1);
	$maintemplate->param("SELFURL", $ENV{REQUEST_URI});
	$maintemplate->param("NEXTURL", "/admin/system/index.cgi?form=system");

	if ($_GET['ssdpenabled'] !== $cfg['SSDP']['DISABLED']) {
		$ssdpstate_changed = 1;
	}
	$cfg->set("SSDP","DISABLED", $_GET['ssdpenabled']);
	$cfg->save();
	
	# Print Template
	print $maintemplate->output();
	exit;
	
	
}


#####################################################
# Error
#####################################################

function error() {
	$maintemplate = new LBTemplate(LBSTEMPLATEDIR."/error.html");
	$maintemplate->param( "ERROR", $error);
	LBWeb::readlanguage($maintemplate);
	print $maintemplate->output();
	exit;

}
