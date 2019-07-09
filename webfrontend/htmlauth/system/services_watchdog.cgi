#!/usr/bin/perl

# Copyright 2016-2018 Michael Schlenstedt, michael@loxberry.de
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
use LoxBerry::JSON;
use LoxBerry::Web;
use LoxBerry::Log;
use CGI::Carp qw(fatalsToBrowser);
use Net::Ping;
use CGI;
use warnings;
use strict;

##########################################################################
# Variables
##########################################################################

my $helplink = "https://www.loxwiki.eu/x/bogKAw";
my $helptemplate = "help_services.html";

##########################################################################
# Read Settings
##########################################################################

# Version of this script
my $version = "1.4.2.3";
my $cgi = CGI->new;
$cgi->import_names('R');

my $cfgfilejson = "$lbsconfigdir/general.json";
my $cfgfilemail = "$lbsconfigdir/mail.json";
my $cfgfilewd = "$lbhomedir/system/watchdog/watchdog.conf";
my $loxberryversion = LoxBerry::System::lbversion();

my $jsonobj = LoxBerry::JSON->new();
my $cfgjson = $jsonobj->open(filename => $cfgfilejson);

my $jsonobjm = LoxBerry::JSON->new();
my $cfgjsonm = $jsonobjm->open(filename => $cfgfilemail);

# Create default config if not exists
if ( !defined($cfgjson->{Watchdog}->{Enable}) ) {
	$cfgjson->{Watchdog}->{Enable} = "0";
	$cfgjson->{Watchdog}->{Logging} = "0";
	my $resp = `/sbin/ip route | awk '/^default/ { print \$3 }'`;
	chomp ($resp);
	$cfgjson->{Watchdog}->{Ping} = "$resp";
	$cfgjson->{Watchdog}->{Maxload1} = "24";
	$cfgjson->{Watchdog}->{Maxload5} = "18";
	$cfgjson->{Watchdog}->{Maxload15} = "12";
	$cfgjson->{Watchdog}->{Minmem} = "10000";
	$cfgjson->{Watchdog}->{Maxtemp} = "85";
	$cfgjson->{Watchdog}->{Tempsensor} = "/sys/class/thermal/thermal_zone0/temp";

	$jsonobj->write();
}

##########################################################################
# Main program
##########################################################################

# Prevent 'only used once' warnings from Perl
$R::saveformdata if 0;
%LoxBerry::Web::htmltemplate_options if 0;

# Template
my $maintemplate = HTML::Template->new(
	filename => "$lbstemplatedir/services_watchdog.html",
	global_vars => 1,
	loop_context_vars => 1,
	die_on_bad_params=> 0,
	#associate => $cfg,
	%LoxBerry::Web::htmltemplate_options,
	# debug => 1,
	);
my %SL = LoxBerry::System::readlanguage($maintemplate);
 
# Push json config to template
my $cfgfilecontent = LoxBerry::System::read_file($cfgfilejson);
$cfgfilecontent =~ s/[\r\n]//g;
$maintemplate->param('JSONCONFIG', $cfgfilecontent);

# Save config
if ($R::saveformdata) {

	system ("sudo systemctl stop watchdog.service");

	if ($R::Watchdog_Enable) {
		$cfgjson->{Watchdog}->{Enable} = "1";
	} else {
		$cfgjson->{Watchdog}->{Enable} = "0";
	}

	if ($R::Watchdog_Logging) {
		$cfgjson->{Watchdog}->{Logging} = "1";
		system ("ln -s $lbssbindir/watchdog_cron.pl $lbhomedir/system/cron/cron.01min/01-watchdoglogging");
	} else {
		$cfgjson->{Watchdog}->{Logging} = "0";
		unlink ("$lbslogdir/watchdogdata.log");
		unlink ("$lbhomedir/system/cron/cron.01min/01-watchdoglogging");
	}

	$cfgjson->{Watchdog}->{Ping} = $R::Watchdog_Ping;
	$cfgjson->{Watchdog}->{Maxload1} = $R::Watchdog_Maxload1;
	$cfgjson->{Watchdog}->{Maxload5} = $R::Watchdog_Maxload5;
	$cfgjson->{Watchdog}->{Maxload15} = $R::Watchdog_Maxload15;
	$cfgjson->{Watchdog}->{Minmem} = $R::Watchdog_Minmem;
	$cfgjson->{Watchdog}->{Maxtemp} = $R::Watchdog_Maxtemp;
	$cfgjson->{Watchdog}->{Tempsensor} = $R::Watchdog_Tempsensor;

	$jsonobj->write();

	open(F,">$cfgfilewd") || die "Cannot open $cfgfilewd";
	flock(F,2);
	print F "interval = 10\n";
	print F "logtick  = 30\n";
	print F "realtime = yes\n";
	print F "priority = 1\n";
	if ($R::Watchdog_Ping) { print F "ping = $R::Watchdog_Ping\n"; };
	if ($R::Watchdog_Maxload1) { print F "max-load-1 = $R::Watchdog_Maxload1\n"; };
	if ($R::Watchdog_Maxload5) { print F "max-load-5 = $R::Watchdog_Maxload5\n"; };
	if ($R::Watchdog_Maxload15) { print F "max-load-15 = $R::Watchdog_Maxload15\n"; };
	if ($R::Watchdog_Minmem) { print F "min-memory = $R::Watchdog_Minmem\n"; };
	if ($R::Watchdog_Maxtemp && $R::Watchdog_Tempsensor) { 
		print F "temperature-sensor = $R::Watchdog_Tempsensor\n";
		print F "max-temperature = $R::Watchdog_Maxtemp\n";
	};
	if ( is_enabled($cfgjsonm->{SMTP}->{ACTIVATE_MAIL}) && $cfgjsonm->{SMTP}->{EMAIL} && ( is_enabled($cfgjsonm->{NOTIFICATION}->{MAIL_SYSTEM_ERRORS}) || is_enabled($cfgjsonm->{NOTIFICATION}->{MAIL_SYSTEM_INFOS}) ) ) {
			print F "admin = $cfgjsonm->{SMTP}->{EMAIL}\n";
	};
	flock(F,8);
	close (F);

	if ($R::Watchdog_Enable) {
		$cfgjson->{Watchdog}->{Enable} = "1";
		system ("sudo systemctl enable watchdog.service");
		system ("sudo systemctl start watchdog.service");
	} else {
		$cfgjson->{Watchdog}->{Enable} = "0";
		system ("sudo systemctl disable watchdog.service");
	}

	$maintemplate->param('SAVE', 1);

} else {

	$maintemplate->param('FORM', 1);

}

# Temperature
my $sensor = $cfgjson->{Watchdog}->{Tempsensor};
my $temp = qx(cat $sensor);
chomp $temp;
$temp = sprintf("%.1f", $temp/1000);
$maintemplate->param('TEMPERATURE', $temp);

# Navbar
our %navbar;
$navbar{0}{Name} = "$SL{'SERVICES.TITLE_PAGE_WEBSERVER'}";
$navbar{0}{URL} = 'services.php?load=1';
$navbar{1}{Name} = "$SL{'SERVICES.TITLE_PAGE_WATCHDOG'}";
$navbar{1}{URL} = 'services_watchdog.cgi';
$navbar{1}{active} = 1;
$navbar{5}{Name} = "Samba (SMB)";
$navbar{5}{URL} = 'services_samba.cgi';
$navbar{50}{Name} = "$SL{'SERVICES.TITLE_PAGE_OPTIONS'}";
$navbar{50}{URL} = 'services.php?load=3';

# Print Template
my $template_title = $SL{'COMMON.LOXBERRY_MAIN_TITLE'} . ": " . $SL{'SERVICES.WIDGETLABEL'} . " v" . $loxberryversion;
LoxBerry::Web::head();
LoxBerry::Web::pagestart($template_title, $helplink, $helptemplate);
print $maintemplate->output();
LoxBerry::Web::pageend();
LoxBerry::Web::foot();

exit;
