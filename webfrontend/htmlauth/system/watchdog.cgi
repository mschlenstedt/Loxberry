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

my $helplink = "http://www.loxwiki.eu/display/LOXBERRY/LoxBerry";
my $helptemplate = "help_remote.html";

##########################################################################
# Read Settings
##########################################################################

# Version of this script
my $version = "1.4.0.2";
my $cgi = CGI->new;
$cgi->import_names('R');

my $cfgfile = "$lbsconfigdir/general.json";
my $loxberryversion = LoxBerry::System::lbversion();

##########################################################################
# Main program
##########################################################################

# Prevent 'only used once' warnings from Perl
$R::saveformdata if 0;
%LoxBerry::Web::htmltemplate_options if 0;

# CGI Vars

# Template
my $maintemplate = HTML::Template->new(
	filename => "$lbstemplatedir/watchdog.html",
	global_vars => 1,
	loop_context_vars => 1,
	die_on_bad_params=> 0,
	#associate => $cfg,
	%LoxBerry::Web::htmltemplate_options,
	# debug => 1,
	);
my %SL = LoxBerry::System::readlanguage($maintemplate);

# Save config
#if ($R::saveformdata) {
#
#	my $jsonobj = LoxBerry::JSON->new();
#	my $cfg = $jsonobj->open(filename => $cfgfile);
#	$cfg->{Remote}->{Httpproxy} = $R::Remote_Httpproxy;
#	$cfg->{Remote}->{Httpport} = $R::Remote_Httpport;
#	if ($R::Remote_Autoconnect) {
#	       $cfg->{Remote}->{Autoconnect} = "1";
#	} else {
#	       $cfg->{Remote}->{Autoconnect} = "0";
#	}
#	$jsonobj->write();
#
#	if ($R::Remote_Httpproxy) {
#		my $proxy = $R::Remote_Httpproxy;
#		my $port = $R::Remote_Httpport;
#		$resp = `/bin/sed -i 's#^;http-proxy .*#http-proxy $proxy $port#g' $lbhomedir/system/supportvpn/loxberry.cfg 2>&1`;
#		$resp = `/bin/sed -i 's#^http-proxy .*#http-proxy $proxy $port#g' $lbhomedir/system/supportvpn/loxberry.cfg 2>&1`;
#		$resp = `/bin/sed -i 's#^;http-proxy\$#http-proxy $proxy $port#g' $lbhomedir/system/supportvpn/loxberry.cfg 2>&1`;
#		$resp = `/bin/sed -i 's#^http-proxy\$#http-proxy $proxy $port#g' $lbhomedir/system/supportvpn/loxberry.cfg 2>&1`;
#	} else {
#		$resp = `/bin/sed -i 's#^http-proxy .*#;http-proxy#g' $lbhomedir/system/supportvpn/loxberry.cfg 2>&1`;
#	}
#
#}

# Navbar
our %navbar;
$navbar{1}{Name} = "$SL{'SERVICES.TITLE_PAGE_WEBSERVER'}";
$navbar{1}{URL} = 'services.php?load=1';
$navbar{2}{Name} = "$SL{'SERVICES.TITLE_PAGE_WATCHDOG'}";
$navbar{2}{URL} = 'watchdog.cgi';
$navbar{2}{active} = 1;
$navbar{3}{Name} = "$SL{'SERVICES.TITLE_PAGE_OPTIONS'}";
$navbar{3}{URL} = 'services.php?load=3';

# Print Template
my $template_title = $SL{'COMMON.LOXBERRY_MAIN_TITLE'} . ": " . $SL{'SERVICES.WIDGETLABEL'} . " v" . $loxberryversion;
LoxBerry::Web::head();
LoxBerry::Web::pagestart($template_title, $helplink, $helptemplate);
print $maintemplate->output();
LoxBerry::Web::pageend();
LoxBerry::Web::foot();

exit;
