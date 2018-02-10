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
use LoxBerry::System;
use LoxBerry::Web;
use LoxBerry::Log;

use CGI qw/:standard/;
use LWP::UserAgent;
# use CGI::Session;
use warnings;
use strict;

##########################################################################
# Variables
##########################################################################

my $helplink = "http://www.loxwiki.eu/display/LOXBERRY/LoxBerry";
my $helptemplate = "help_myloxberry.html";
my $template_title;
my $error;

##########################################################################
# Read Configuration
##########################################################################

if (! -e "$lbsconfigdir/general.cfg" || ! -e "$lbsconfigdir/mail.cfg" || ! -e "$lbsconfigdir/htusers.dat" || ! -e "$lbsconfigdir/securepin.dat" ) {
	qx ( $lbsbindir/createconfig.pl );
}
if (-z "$lbsconfigdir/general.cfg" || -z "$lbsconfigdir/mail.cfg" || -z "$lbsconfigdir/htusers.dat" || -z "$lbsconfigdir/securepin.dat" ) {
	die "CRITICAL: One of your configuration files (general.cfg, mail.cfg, installpin.dat, securepin.dat) exists but have zero size. LoxBerry is not working in this condition.\n" . 
		"Please check if your SD card is full. If you have fixed the issue, delete all of the mentioned files that have 0 Bytes so LoxBerry can re-create them, or restore them from a backup.\n\n" . 
		"Sorry for any troubles. We love you!\n";
		exit(1);
}

# Version of this script
my $version = "0.3.3.3";

my $sversion = LoxBerry::System::lbversion();

my $cfg = new Config::Simple("$lbsconfigdir/general.cfg");
my %Config = $cfg->vars();

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
	# Resize SDCard
	system ("$lbsbindir/resize_rootfs > /boot/rootfsresized");
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
				associate => $cfg,
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

	my @plugins;
	
	# Check notifications
	my %notification_errors;
	my %notification_oks;
	my $notification_allerrors = 0;
	my $notification_alloks = 0;
	
	my @notifications = get_notifications();
	for my $notification (@notifications ) {
		if ($notification->{SEVERITY} eq 'err') {
			$notification_errors{$notification->{PACKAGE}}++;
			$notification_oks{$notification->{PACKAGE}}++;
			$notification_allerrors++;
		} else {
			$notification_oks{$notification->{PACKAGE}}++;
			$notification_alloks++;
		}
	}

	our %navbar;
	$navbar{1}{Name} = $SL{'HEADER.TITLE_PAGE_PLUGINS'};
	$navbar{1}{URL} = "/admin/system/index.cgi";
	$navbar{2}{Name} = $SL{'HEADER.TITLE_PAGE_SYSTEM'};
	$navbar{2}{URL} = "/admin/system/index.cgi?form=system";
	$navbar{2}{notifyBlue} = $notification_allerrors == 0 && $notification_alloks != 0 ? $notification_alloks : undef;
	$navbar{2}{notifyRed} = $notification_allerrors != 0 ? ($notification_allerrors+$notification_alloks)  : undef;

	if (!$R::form || $R::form ne "system") {
		# Get Plugins from plugin database
		@plugins = LoxBerry::System::get_plugins();
		$maintemplate->param('PLUGINS' => \@plugins);
	} else {
		# Create SYSTEM widget list
		
		# Prepare System Date Time for Love Clock
		our $systemdatetime = time()*1000;
		(our $sec, our $min, our $hour, our $mday, our $mon, our $year, our $wday, our $yday, our $isdst) = localtime();
		our $systemdate = $year + 1900 . "-" . sprintf ('%02d' ,$mon) . "-" . sprintf ('%02d' ,$mday);
		$maintemplate->param( 	'SEC' => $sec,
								'MIN' => $min,
								'HOUR' => $hour
							);
		
		
		# print STDERR "Index: Update Errors: $notification_errors{'updates'} \n";
		# print STDERR "Index: Update Infos: $notification_oks{'updates'} \n";
		
		
		$maintemplate->param('WIDGETS' => [
			{ 
				WIDGET_TITLE => $SL{'HEADER.PANEL_MYLOXBERRY'}, 
				WIDGET_ICON => "/system/images/icons/main_myloxberry.svg",
				WIDGET_CGI => "/admin/system/myloxberry.cgi",
				WIDGET_NOTIFY_BLUE => $notification_oks{'myloxberry'},
				WIDGET_NOTIFY_RED => $notification_errors{'myloxberry'},
			} ,
			{
				WIDGET_TITLE => $SL{'HEADER.PANEL_ADMIN'},
				WIDGET_ICON => "/system/images/icons/main_admin.png", 
				WIDGET_CGI => "/admin/system/admin.cgi",
				WIDGET_NOTIFY_BLUE => $notification_oks{'admin'},
				WIDGET_NOTIFY_RED => $notification_errors{'admin'},
			} ,
			{
				WIDGET_TITLE => $SL{'HEADER.PANEL_MINISERVER'}, 
				WIDGET_ICON => "/system/images/icons/main_miniserver.svg",
				WIDGET_CGI => "/admin/system/miniserver.cgi",
				WIDGET_NOTIFY_BLUE => $notification_oks{'miniserver'},
				WIDGET_NOTIFY_RED => $notification_errors{'miniserver'},
			},
			{
				WIDGET_TITLE => $SL{'HEADER.PANEL_TIMESERVER'},
				WIDGET_ICON => "/system/images/icons/blank_64.png",
				WIDGET_CGI => "/admin/system/timeserver.cgi",
				WIDGET_CLOCK => 1
			},
			{
				WIDGET_TITLE => $SL{'HEADER.PANEL_NETWORK'},
				WIDGET_ICON => "/system/images/icons/main_network.png",
				WIDGET_CGI => "/admin/system/network.cgi",
				WIDGET_NOTIFY_BLUE => $notification_oks{'network'},
				WIDGET_NOTIFY_RED => $notification_errors{'network'},
			},
			{
				WIDGET_TITLE => $SL{'HEADER.PANEL_PLUGININSTALL'},
				WIDGET_ICON => "/system/images/icons/main_plugininstall.png",
				WIDGET_CGI => "/admin/system/plugininstall.cgi",
				WIDGET_NOTIFY_BLUE => $notification_oks{'plugininstall'},
				WIDGET_NOTIFY_RED => $notification_errors{'plugininstall'},
			},
			{
				WIDGET_TITLE => $SL{'HEADER.PANEL_UPDATES'},
				WIDGET_ICON => "/system/images/icons/main_updates.png",
				WIDGET_CGI => "/admin/system/updates.cgi",
				WIDGET_NOTIFY_BLUE => $notification_oks{'updates'},
				WIDGET_NOTIFY_RED => $notification_errors{'updates'},
				
			},
			{
				WIDGET_TITLE => $SL{'HEADER.PANEL_SERVICES'},
				WIDGET_ICON => "/system/images/icons/main_services.png",
				WIDGET_CGI => "/admin/system/services.php",
				WIDGET_NOTIFY_BLUE => $notification_oks{'services'},
				WIDGET_NOTIFY_RED => $notification_errors{'services'},
				
			},
			{
				WIDGET_TITLE => $SL{'HEADER.PANEL_REBOOT'},
				WIDGET_ICON => "/system/images/icons/main_power.png",
				WIDGET_CGI => "/admin/system/power.cgi",
				WIDGET_NOTIFY_BLUE => $notification_oks{'power'},
				WIDGET_NOTIFY_RED => $notification_errors{'power'},
			},
			{
				WIDGET_TITLE => $SL{'HEADER.PANEL_MAILSERVER'},
				WIDGET_ICON => "/system/images/icons/main_mail.png",
				WIDGET_CGI => "/admin/system/mailserver.cgi",
				WIDGET_NOTIFY_BLUE => $notification_oks{'mailserver'},
				WIDGET_NOTIFY_RED => $notification_errors{'mailserver'},
			},
			{
				WIDGET_TITLE => $SL{'HEADER.PANEL_SETUPASSISTENT'},
				WIDGET_ICON => "/system/images/icons/main_setupassistent.png",
				WIDGET_CGI => "/admin/system/wizard.cgi",
			},
			{
				WIDGET_TITLE => $SL{'HEADER.PANEL_TRANSLATE'},
				WIDGET_ICON => "/system/images/icons/main_translate.png",
				WIDGET_CGI => "/admin/system/translate.cgi",
				WIDGET_NOTIFY_BLUE => $notification_oks{'translate'},
				WIDGET_NOTIFY_RED => $notification_errors{'translate'},
			},
			{
				WIDGET_TITLE => $SL{'HEADER.PANEL_DONATE'},
				WIDGET_ICON => "/system/images/icons/main_donate.png",
				WIDGET_CGI => "/admin/system/donate.cgi",
				WIDGET_NOTIFY_BLUE => $notification_oks{'donate'},
				WIDGET_NOTIFY_RED => $notification_errors{'donate'},
			}
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


