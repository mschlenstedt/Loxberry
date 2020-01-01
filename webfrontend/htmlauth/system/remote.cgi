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

my $helplink = "https://www.loxwiki.eu/x/GokKAw";
my $helptemplate = "help_remote.html";

##########################################################################
# Read Settings
##########################################################################

# Version of this script
my $version = "2.0.0.1";
my $cgi = CGI->new;
$cgi->import_names('R');

my $cfgfile = "$lbsconfigdir/general.json";

##########################################################################
# Main program
##########################################################################

# Prevent 'only used once' warnings from Perl
$R::saveformdata if 0;
$R::supportkey if 0;
$R::disconnect if 0;
$R::Remote_Autoconnect if 0;
$R::connect if 0;
$R::reset if 0;
%LoxBerry::Web::htmltemplate_options if 0;

# CGI Vars
my $supportkey = $R::supportkey;
my $reset = $R::reset;
my $connect = $R::connect;
my $disconnect = $R::disconnect;
my $saveformdata = $R::saveformdata;
my $resp;

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

		# Kill an existing connection
		my $supportkey = `openssl x509 -noout -text -in $lbhomedir/system/supportvpn/loxberry.crt | grep "Subject: CN" | cut -d= -f2 | cut -d" " -f2`;
		chomp ($supportkey);
		if (-e "$lbhomedir/log/system_tmpfs/openvpn_$supportkey.pid") {
			my $pid = `cat $lbhomedir/log/system_tmpfs/openvpn_$supportkey.pid`;
			chomp ($pid);
			$resp = `kill $pid`;
			$resp = `sudo $lbhomedir/sbin/openvpn stop 2>&1`;
		}

		notify( "remote", "supportkey", $SL{'REMOTE.LABEL_SUPPORTKEY'} . " " . $supportkey . " - " . $SL{'REMOTE.MSGERROR_KEY_EXPIRED'}, 1);
		$resp = `rm -rf $lbhomedir/system/supportvpn/* 2>&1`;
	}

}

# Reset / Delete Support Key
if ($reset) {

	# Kill an existing connection
	my $supportkey = `openssl x509 -noout -text -in $lbhomedir/system/supportvpn/loxberry.crt | grep "Subject: CN" | cut -d= -f2 | cut -d" " -f2`;
	chomp ($supportkey);
	if (-e "$lbhomedir/log/system_tmpfs/openvpn_$supportkey.pid") {
		my $pid = `cat $lbhomedir/log/system_tmpfs/openvpn_$supportkey.pid`;
		chomp ($pid);
		$resp = `kill $pid`;
		$resp = `sudo $lbhomedir/sbin/openvpn stop 2>&1`;
	}
	$resp = `rm -rf $lbhomedir/system/supportvpn/* 2>&1`;

}

# Connect
if ($connect && -e "$lbhomedir/system/supportvpn/loxberry.cfg" && -e "$lbhomedir/system/supportvpn/loxberry.crt" ) {

	# Check Online Status
	my $p = Net::Ping->new();
	my $hostname = '10.98.98.1';
	my ($ret, $duration, $ip) = $p->ping($hostname);
	# If not already connected
	if (!$ret) {
		my $supportkey = `openssl x509 -noout -text -in $lbhomedir/system/supportvpn/loxberry.crt | grep "Subject: CN" | cut -d= -f2 | cut -d" " -f2`;
		chomp ($supportkey);
		# Kill an existing connection
		if (-e "$lbhomedir/log/system_tmpfs/openvpn_$supportkey.pid") {
			my $pid = `cat $lbhomedir/log/system_tmpfs/openvpn_$supportkey.pid`;
			chomp ($pid);
			$resp = `kill $pid`;
		}
		$resp = `sudo $lbhomedir/sbin/openvpn start 2>&1`;
		$resp = `cd $lbhomedir/system/supportvpn && openvpn --daemon --writepid $lbhomedir/log/system_tmpfs/openvpn_$supportkey.pid --log $lbhomedir/log/system_tmpfs/openvpn.log --config $lbhomedir/system/supportvpn/loxberry.cfg 2>&1`;
	}
	
	# Check Online Status
	for (my $i=0; $i < 10; $i++) {
		my $p = Net::Ping->new();
		my $hostname = '10.98.98.1';
		my ($ret, $duration, $ip) = $p->ping($hostname);
		if (!$ret) {
			sleep (1);
			next;
		} else {
			last;
		}
	}

}

# Disconnect
if ($disconnect && -e "$lbhomedir/system/supportvpn/loxberry.crt" ) {

	# Kill an existing connection
	my $supportkey = `openssl x509 -noout -text -in $lbhomedir/system/supportvpn/loxberry.crt | grep "Subject: CN" | cut -d= -f2 | cut -d" " -f2`;
	chomp ($supportkey);
	if (-e "$lbhomedir/log/system_tmpfs/openvpn_$supportkey.pid") {
		my $pid = `cat $lbhomedir/log/system_tmpfs/openvpn_$supportkey.pid`;
		chomp ($pid);
		$resp = `kill $pid`;
		$resp = `sudo $lbhomedir/sbin/openvpn stop 2>&1`;
	}

}

# Save config
if ($saveformdata) {

	my $jsonobj = LoxBerry::JSON->new();
	my $cfg = $jsonobj->open(filename => $cfgfile);
	$cfg->{Remote}->{Httpproxy} = $R::Remote_Httpproxy;
	$cfg->{Remote}->{Httpport} = $R::Remote_Httpport;
	if ($R::Remote_Autoconnect) {
	       $cfg->{Remote}->{Autoconnect} = "1";
	} else {
	       $cfg->{Remote}->{Autoconnect} = "0";
	}
	$jsonobj->write();

	if ($R::Remote_Httpproxy) {
		my $proxy = $R::Remote_Httpproxy;
		my $port = $R::Remote_Httpport;
		$resp = `/bin/sed -i 's#^;http-proxy .*#http-proxy $proxy $port#g' $lbhomedir/system/supportvpn/loxberry.cfg 2>&1`;
		$resp = `/bin/sed -i 's#^http-proxy .*#http-proxy $proxy $port#g' $lbhomedir/system/supportvpn/loxberry.cfg 2>&1`;
		$resp = `/bin/sed -i 's#^;http-proxy\$#http-proxy $proxy $port#g' $lbhomedir/system/supportvpn/loxberry.cfg 2>&1`;
		$resp = `/bin/sed -i 's#^http-proxy\$#http-proxy $proxy $port#g' $lbhomedir/system/supportvpn/loxberry.cfg 2>&1`;
	} else {
		$resp = `/bin/sed -i 's#^http-proxy .*#;http-proxy#g' $lbhomedir/system/supportvpn/loxberry.cfg 2>&1`;
	}

}

# New Support Key submitted
if ($supportkey) {

	my $bins = LoxBerry::System::get_binaries();
	my $keyurl = "https://supportvpn.loxberry.de/keys/$supportkey/key.tgz";
	
	# Kill an existing connection
	my $supportkey = `openssl x509 -noout -text -in $lbhomedir/system/supportvpn/loxberry.crt | grep "Subject: CN" | cut -d= -f2 | cut -d" " -f2`;
	chomp ($supportkey);
	if (-e "$lbhomedir/log/system_tmpfs/openvpn_$supportkey.pid") {
		my $pid = `cat $lbhomedir/log/system_tmpfs/openvpn_$supportkey.pid`;
		chomp ($pid);
		$resp = `kill $pid`;
		$resp = `sudo $lbhomedir/sbin/openvpn stop 2>&1`;
	}

	$resp = `rm -rf /$lbhomedir/system/supportvpn/* 2>&1`;
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

}

# No valid support key
if (!-e "$lbhomedir/system/supportvpn/loxberry.crt" && !$maintemplate->param("ERROR") ) {

	$maintemplate->param("FORM1", 1);

}


# Print Template
my $template_title = $SL{'COMMON.LOXBERRY_MAIN_TITLE'} . ": " . $SL{'REMOTE.WIDGETLABEL'};
LoxBerry::Web::head();
LoxBerry::Web::pagestart($template_title, $helplink, $helptemplate);
if ($maintemplate->param("FORM1")) {
	print LoxBerry::Log::get_notifications_html("remote");
}
print $maintemplate->output();
LoxBerry::Web::pageend();
LoxBerry::Web::foot();

exit;
