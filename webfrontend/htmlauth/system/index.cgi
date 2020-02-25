#!/usr/bin/perl

# Copyright 2016-2017 Michael Schlenstedt, michael@loxberry.de
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
use LoxBerry::Web;

use CGI qw/:standard/;
use warnings;
use strict;

##########################################################################
# Variables
##########################################################################

my $helplink = "https://www.loxwiki.eu/x/84YKAw";
my $helptemplate;
my $template_title;
my $error;

##########################################################################
# Read Configuration
##########################################################################

if (! -e "$lbsconfigdir/general.cfg" || ! -e "$lbsconfigdir/general.json" || ! -e "$lbsconfigdir/mail.json" || ! -e "$lbsconfigdir/htusers.dat" || ! -e "$lbsconfigdir/securepin.dat" ) {
	qx ( $lbsbindir/createconfig.pl );
}
if (-z "$lbsconfigdir/general.cfg" || -z "$lbsconfigdir/general.json" || -z "$lbsconfigdir/mail.json" || -z "$lbsconfigdir/htusers.dat" || -z "$lbsconfigdir/securepin.dat" ) {
	die "CRITICAL: One of your configuration files (general.cfg, mail.json, installpin.dat, securepin.dat) exists but have zero size. LoxBerry is not working in this condition.\n" . 
		"Please check if your SD card is full. If you have fixed the issue, delete all of the mentioned files that have 0 Bytes so LoxBerry can re-create them, or restore them from a backup.\n\n" . 
		"Sorry for any troubles. We love you!\n";
		exit(1);
}

# Version of this script
my $version = "2.0.2.1";

my $sversion = LoxBerry::System::lbversion();

my $bins = LoxBerry::System::get_binaries();
my $sudobin = $bins->{SUDO};

#########################################################################
# Parameter
#########################################################################

# Import form parameters to the namespace R
my $cgi = CGI->new;
$cgi->import_names('R');
# Example: Parameter lang is now $R::lang

##########################################################################
# Check for first start and setup assistent
##########################################################################

my $wizardfile = "$lbsdatadir/wizard.dat";
if (! -e $wizardfile) {
	# Delete LoxBerryID
	system ("rm -f $lbsconfigdir/loxberryid.cfg > /dev/null 2>&1");
	# Resize SDCard
	system ("$sudobin -n $lbssbindir/resize_rootfs > $lbslogdir/rootfsresized.log 2>&1");
	reboot_required("Setup Wizard");
	# Start Wizard
	print $cgi->redirect('/admin/system/wizard.cgi');
	exit;
}


##########################################################################
# Language Settings
##########################################################################

if ($R::lang) {
	# Nice feature: We override language detection of LoxBerry::Web
	$LoxBerry::Web::lang = substr($R::lang, 0, 2);
}
# If we did the 'override', lblanguage will give us that language
my $lang = lblanguage();
our $maintemplate = HTML::Template->new(
				filename => "$lbstemplatedir/index.html",
				global_vars => 1,
				loop_context_vars => 1,
				die_on_bad_params=> 0,
				%htmltemplate_options,
				#debug => 1,
				#stack_debug => 1,
				);

our %SL = LoxBerry::System::readlanguage($maintemplate);

$template_title = "$SL{'COMMON.LOXBERRY_MAIN_TITLE'}";

##########################################################################
# Main program
##########################################################################

#########################################################################
# What should we do
#########################################################################

# Nothing todo? Goto Main menu
&mainmenu;

exit;

#####################################################
# Main Meenu
#####################################################

sub mainmenu {

	# $LoxBerry::Log::DEBUG = 1;
	
	my @plugins;
	
	our %navbar;
	$navbar{1}{Name} = $SL{'HEADER.TITLE_PAGE_PLUGINS'};
	$navbar{1}{URL} = "/admin/system/index.cgi";
	$navbar{2}{Name} = $SL{'HEADER.TITLE_PAGE_SYSTEM'};
	$navbar{2}{URL} = "/admin/system/index.cgi?form=system";

	if (!$R::form || $R::form ne "system") {
		# Get Plugins from plugin database
		@plugins = LoxBerry::System::get_plugins();
		$maintemplate->param('PLUGINS' => \@plugins);
		$helptemplate = "help_index_plugins.html";

	} else {
		$helptemplate = "help_index_system.html";

		# Create SYSTEM widget list
		# Prepare System Date Time for Love Clock
		# our $systemdatetime = time()*1000;
		# (our $sec, our $min, our $hour, our $mday, our $mon, our $year, our $wday, our $yday, our $isdst) = localtime();
		# our $systemdate = $year + 1900 . "-" . sprintf ('%02d' ,$mon) . "-" . sprintf ('%02d' ,$mday);
		# $maintemplate->param( 	'SEC' => $sec,
								# 'MIN' => $min,
								# 'HOUR' => $hour
		# );
		
		$maintemplate->param('WIDGETS' => [
			{ 
				WIDGET_TITLE => $SL{'HEADER.PANEL_MYLOXBERRY'}, 
				WIDGET_ICON => "/system/images/icons/main_myloxberry.svg",
				WIDGET_CGI => "/admin/system/myloxberry.cgi",
				NOTIFY_PACKAGE => "myloxberry",
			} ,
			{
				WIDGET_TITLE => $SL{'HEADER.PANEL_ADMIN'},
				WIDGET_ICON => "/system/images/icons/main_admin.png", 
				WIDGET_CGI => "/admin/system/admin.cgi",
				NOTIFY_PACKAGE => "admin",
			} ,
			{
				WIDGET_TITLE => $SL{'HEADER.PANEL_MINISERVER'}, 
				WIDGET_ICON => "/system/images/icons/main_miniserver.svg",
				WIDGET_CGI => "/admin/system/miniserver.cgi",
				NOTIFY_PACKAGE => "miniserver",
			},
			# {
				# WIDGET_TITLE => $SL{'HEADER.PANEL_TIMESERVER'},
				# WIDGET_ICON => "/system/images/icons/blank_64.png",
				# WIDGET_CGI => "/admin/system/timeserver.cgi",
				# NOTIFY_PACKAGE => "timeserver",
				# WIDGET_CLOCK => 1
			# },
			{
				WIDGET_TITLE => $SL{'HEADER.PANEL_NETWORK'},
				WIDGET_ICON => "/system/images/icons/main_network.png",
				WIDGET_CGI => "/admin/system/network.cgi",
				NOTIFY_PACKAGE => "network",
			},
			{
				WIDGET_TITLE => $SL{'HEADER.PANEL_PLUGININSTALL'},
				WIDGET_ICON => "/system/images/icons/main_plugininstall.png",
				WIDGET_CGI => "/admin/system/plugininstall.cgi",
				NOTIFY_PACKAGE => "plugininstall",
			},
			{
				WIDGET_TITLE => $SL{'HEADER.PANEL_UPDATES'},
				WIDGET_ICON => "/system/images/icons/main_updates.png",
				WIDGET_CGI => "/admin/system/updates.cgi",
				NOTIFY_PACKAGE => "updates",
				
			},
			{
				WIDGET_TITLE => 'Log Manager',
				WIDGET_ICON => "/system/images/icons/main_logmanager.png",
				WIDGET_CGI => "/admin/system/logmanager.cgi",
				NOTIFY_PACKAGE => "logmanager",
				
			},
			{
				WIDGET_TITLE => $SL{'HEADER.PANEL_SERVICES'},
				WIDGET_ICON => "/system/images/icons/main_services.png",
				WIDGET_CGI => "/admin/system/services.php",
				NOTIFY_PACKAGE => "services",
				
			},
			{
				WIDGET_TITLE => $SL{'HEADER.PANEL_REBOOT'},
				WIDGET_ICON => "/system/images/icons/main_power.png",
				WIDGET_CGI => "/admin/system/power.cgi",
				NOTIFY_PACKAGE => "power",
			},
			{
				WIDGET_TITLE => $SL{'HEADER.PANEL_MAILSERVER'},
				WIDGET_ICON => "/system/images/icons/main_mail.png",
				WIDGET_CGI => "/admin/system/mailserver.cgi",
				NOTIFY_PACKAGE => "mailserver",
			},
			{
				WIDGET_TITLE => $SL{'HEADER.PANEL_SETUPASSISTENT'},
				WIDGET_ICON => "/system/images/icons/main_setupassistent.png",
				WIDGET_CGI => "/admin/system/wizard.cgi",
				NOTIFY_PACKAGE => "wizard",
			},
			{
				WIDGET_TITLE => $SL{'HEADER.PANEL_TRANSLATE'},
				WIDGET_ICON => "/system/images/icons/main_translate.png",
				WIDGET_CGI => "/admin/system/translate.cgi",
				NOTIFY_PACKAGE => "translate",
			},
			{
				WIDGET_TITLE => $SL{'HEADER.PANEL_FILEMANAGER'},
				WIDGET_ICON => "/system/images/icons/main_filemanager.png",
				WIDGET_CGI => "/admin/system/tools/filemanager/filemanager.php",
				NOTIFY_PACKAGE => "filemanager",
			},
			{
				WIDGET_TITLE => $SL{'HEADER.PANEL_NETSHARES'},
				WIDGET_ICON => "/system/images/icons/main_netshares.png",
				WIDGET_CGI => "/admin/system/netshares.cgi",
				NOTIFY_PACKAGE => "netshares",
			},
			{
				WIDGET_TITLE => $SL{'HEADER.PANEL_USBSTORAGE'},
				WIDGET_ICON => "/system/images/icons/main_usbstorage.png",
				WIDGET_CGI => "/admin/system/usbstorage.cgi",
				NOTIFY_PACKAGE => "usbstoage",
			},
			{
				WIDGET_TITLE => $SL{'HEADER.PANEL_REMOTE'},
				WIDGET_ICON => "/system/images/icons/main_remote.png",
				WIDGET_CGI => "/admin/system/remote.cgi",
				NOTIFY_PACKAGE => "remote",
			},
			{
				WIDGET_TITLE => $SL{'HEADER.PANEL_DONATE'},
				WIDGET_ICON => "/system/images/icons/main_donate.png",
				WIDGET_CGI => "/admin/system/donate.cgi",
				NOTIFY_PACKAGE => "donate",
			},
		]);
		
	}

	$maintemplate->param( 'SVERSION' => $sversion);
	$template_title = $SL{'COMMON.LOXBERRY_MAIN_TITLE'};
	LoxBerry::Web::head($template_title);
	$template_title = $SL{'COMMON.LOXBERRY_MAIN_TITLE'} . " <span class='hint'>V$sversion</span>";

	if (!$R::form || $R::form ne "system") {
		$navbar{1}{active} = 1;
		$maintemplate->param('PAGE_PLUGIN', 1);
	} else {
		$navbar{2}{active} = 1;
		$maintemplate->param('PAGE_SYSTEM', 1);
	}

	# Slow down Notitfys for PI1 (needs too much CPU)
	my $output = qx ($lbsbindir/showpitype);
	chomp ($output);
	if ($output eq "type_1") {
		$maintemplate->param('NOTIFY_POLLTIME', 30000);
	} else {
		$maintemplate->param('NOTIFY_POLLTIME', 5000);
	}

	LoxBerry::Web::pagestart($template_title, $helplink, $helptemplate);
	print $maintemplate->output();
	LoxBerry::Web::pageend();
	LoxBerry::Web::foot();

	exit;

}

exit;


#####################################################
# Debugging: ERR INFO
#####################################################

sub ERR 
{
	my ($message) = @_;
	print STDERR "index.cgi ERROR: $message\n";
}
sub INFO
{
	my ($message) = @_;
	print STDERR "index.cgi INFO: $message\n";
}


