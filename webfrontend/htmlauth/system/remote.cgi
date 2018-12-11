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

my $helpurl = "http://www.loxwiki.eu/display/LOXBERRY/LoxBerry";
my $helptemplate = "help_remote.html";

##########################################################################
# Read Settings
##########################################################################

# Version of this script
my $version = "1.4.0.1";
my $cgi = CGI->new;
$cgi->import_names('R');

my $cfgfile = "$lbsconfigdir/general.json";

##########################################################################
# Main program
##########################################################################

# Prevent 'only used once' warnings from Perl
$R::saveformdata if 0;
$R::supportkey if 0;
%LoxBerry::Web::htmltemplate_options if 0;

# CGI Vars
my $supportkey = $R::supportkey;
my $reset = $R::reset;

# Template
my $maintemplate = HTML::Template->new(
	filename => "$lbstemplatedir/remote.html",
	global_vars => 1,
	loop_context_vars => 1,
	die_on_bad_params=> 0,
	#associate => $cfg,
	%LoxBerry::Web::htmltemplate_options,
	# debug => 1,
	);
my %SL = LoxBerry::System::readlanguage($maintemplate);

# Clear expired key
if (-e "$lbhomedir/system/supportvpn/loxberry.crt" ) {
	my $certdate = `openssl x509 -noout -text -in $lbhomedir/system/supportvpn/loxberry.crt | grep "Not After" | cut -d: -f2-10 | cut -d" " -f2-10`;
	$certdate = `date --date '$certdate'`;
	chomp ($certdate);
	my $certepoche = `date --date '$certdate' +%s`;
	chomp ($certepoche);
	my $nowepoche = `date +%s`;
	if ($nowepoche > $certepoche) {


                #
                # ADD HERE: STOP OPENVPN CONNECTION
                #


		notify( "remote", "supportkey", $SL{'REMOTE.LABEL_SUPPORTKEY'} . " " . $supportkey . " - " . $SL{'REMOTE.MSGERROR_KEY_EXPIRED'}, 1);
		my $resp = `rm -rf /$lbhomedir/system/supportvpn/* 2>&1`;
	}
}

# Reset / Delete Support Key
if ($reset) {

                #
                # ADD HERE: STOP OPENVPN CONNECTION
                #

	my $resp = `rm -rf /$lbhomedir/system/supportvpn/* 2>&1`;

}

# New Support Key submitted
if ($supportkey) {
	my $bins = LoxBerry::System::get_binaries();
	my $keyurl = "https://supportvpn.loxberry.de/keys/$supportkey/key.tgz";

	my $resp = `rm -rf /$lbhomedir/system/supportvpn/* 2>&1`;
	$resp = `$bins->{CURL} -q --connect-timeout 10 --max-time 60 --retry 5 -LfksSo $lbhomedir/system/supportvpn/$supportkey.tgz $keyurl 2>&1`;
	if ($? ne "0") {
		$maintemplate->param("ERROR", 1);
		$maintemplate->param("ERRORMSG", $SL{'REMOTE.MSGERROR_KEY_DOES_NOT_EXIST'});
		$resp = `rm -rf /$lbhomedir/system/supportvpn/* 2>&1`;
	}
	if (!$maintemplate->param("ERROR")) {
		$resp = `cd /$lbhomedir/system/supportvpn && $bins->{TAR} xvfz $lbhomedir/system/supportvpn/$supportkey.tgz 2>&1`;
		if ($? ne "0") {
			$maintemplate->param("FORM1", 0);
			$maintemplate->param("ERROR", 1);
			$maintemplate->param("ERRORMSG", $SL{'REMOTE.MSGERROR_KEY_COULD_NOT_BE_EXTRACTED'});
			$resp = `rm -rf /$lbhomedir/system/supportvpn/* 2>&1`;
		}
	}
	if (!$maintemplate->param("ERROR")) {
		$resp = `/bin/sed -i 's#REPLACELBHOMEDIR#$lbhomedir#g' $lbhomedir/system/supportvpn/loxberry.cfg 2>&1`;
		my $certdate = `openssl x509 -noout -text -in $lbhomedir/system/supportvpn/loxberry.crt | grep "Not After" | cut -d: -f2-10 | cut -d" " -f2-10`;
		$certdate = `date --date '$certdate'`;
		chomp ($certdate);
		my $certepoche = `date --date '$certdate' +%s`;
		chomp ($certepoche);
		my $nowepoche = `date +%s`;
		if ($nowepoche > $certepoche) {
			#notify( "remote", "supportkey", $SL{'REMOTE.LABEL_SUPPORTKEY'} . " " . $supportkey . ": " . $SL{'REMOTE.MSGERROR_KEY_EXPIRED'}, 1);
			$resp = `rm -rf /$lbhomedir/system/supportvpn/* 2>&1`;
			$maintemplate->param("ERROR", 1);
			$maintemplate->param("ERRORMSG", $SL{'REMOTE.MSGERROR_KEY_EXPIRED'});
		}
	}

}

# There's a valid Support Key
if (-e "$lbhomedir/system/supportvpn/loxberry.crt" && !$maintemplate->param("ERROR") ) {

	my $supportkey = `openssl x509 -noout -text -in $lbhomedir/system/supportvpn/loxberry.crt | grep "Subject: CN" | cut -d= -f2 | cut -d" " -f2`;
	chomp ($supportkey);
	my $certdate = `openssl x509 -noout -text -in $lbhomedir/system/supportvpn/loxberry.crt | grep "Not After" | cut -d: -f2-10 | cut -d" " -f2-10`;
	$certdate = `date --date '$certdate'`;
	chomp ($certdate);

	$maintemplate->param("SUPPORTKEY", $supportkey);
	$maintemplate->param("CERTDATE", $certdate);
	$maintemplate->param("FORM2", 1);

	# Check Online Status
	my $p = Net::Ping->new();
	my $hostname = '10.98.98.1';
	my ($ret, $duration, $ip) = $p->ping($hostname);
	if ($ret) {
		$maintemplate->param("ONLINE", 1);
		$maintemplate->param("STATUS", $SL{'REMOTE.MSG_ONLINE'});
	} else {
		$maintemplate->param("OFFLINE", 1);
		$maintemplate->param("STATUS", $SL{'REMOTE.MSG_OFFLINE'});
	}

	# Push json config to template
	my $cfgfilecontent = LoxBerry::System::read_file($cfgfile);
	$cfgfilecontent =~ s/[\r\n]//g;
	$maintemplate->param('JSONCONFIG', $cfgfilecontent);

	my $js = LoxBerry::JSON::read_file($cfgfile, 'Remote');
	$maintemplate->param('JSONCONFIGSCRIPT', $js);

}

# No valid support key
if (!-e "$lbhomedir/system/supportvpn/loxberry.crt" && !$maintemplate->param("ERROR") ) {

	$maintemplate->param("FORM1", 1);

}


# Print Template
my $template_title = $SL{'COMMON.LOXBERRY_MAIN_TITLE'} . ": " . $SL{'REMOTE.WIDGETLABEL'};
my $helplink;
my $helptemplate;
LoxBerry::Web::head();
LoxBerry::Web::pagestart($template_title, $helplink, $helptemplate);
if ($maintemplate->param("FORM1")) {
	print LoxBerry::Log::get_notifications_html("remote");
}
print $maintemplate->output();
LoxBerry::Web::pageend();
LoxBerry::Web::foot();

exit;
