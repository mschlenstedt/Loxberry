#!/usr/bin/perl

# Copyright 2018 Michael Schlenstedt, michael@loxberry.de
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
use LoxBerry::Storage;
use LoxBerry::Web;
use LoxBerry::Log;

use Config::Simple;
use warnings;
use strict;

##########################################################################
# Variables
##########################################################################

my $helpurl = "http://www.loxwiki.eu/display/LOXBERRY/LoxBerry";

our $cfg;
our $phrase;
our $namef;
our $value;
our %query;
our $lang;
our $template_title;
our $help;
our @help;
our $helptext;
our $helplink;
our $languagefile;

##########################################################################
# Read Settings
##########################################################################

# Version of this script
my $version = "1.0.0.1";

$cfg = new Config::Simple("$lbhomedir/config/system/general.cfg");

##########################################################################
# Language Settings
##########################################################################

$lang = lblanguage();

##########################################################################
# Main program
##########################################################################

# Get CGI
our  $cgi = CGI->new;

my $maintemplate = HTML::Template->new(
		filename => "$lbstemplatedir/netshares.html",
		global_vars => 1,
		loop_context_vars => 1,
		die_on_bad_params=> 0,
		associate => $cfg,
		%htmltemplate_options,
		# debug => 1,
		);
	
my %SL = LoxBerry::System::readlanguage($maintemplate);

# Print Template
$template_title = $SL{'COMMON.LOXBERRY_MAIN_TITLE'} . ": " . $SL{'NETSHARES.WIDGETLABEL'};

LoxBerry::Web::lbheader();

# Save new server
if ($cgi->param("saveformdata")) {
	
	$maintemplate->param("SAVE", 1);

	# Credits
	my $file=$cgi->param("serverip");
	my $username=$cgi->param("username");
	my $password=$cgi->param("password");
	my $type=$cgi->param("type");
        open(F,">$lbhomedir/system/samba/credentials/$file");
        print F <<EOF;
uid=1001
gid=1001
username=$username
password=$password
EOF
        close (F);

	qx(ln -f -s /media/$type/$file $lbhomedir/system/storage/$type/$file);

	# Check read state
	qx(sudo /etc/init.d/autofs restart);
	qx(ls $lbhomedir/system/storage/$type/$file/);
	if ($? ne 0) {
		# Some servers semms not to list the shares, so try to list files inside the shares
		qx(ls $lbhomedir/system/storage/$type/$file/*);
		if ($? ne 0) {
			$maintemplate->param("WARNING", $SL{'NETSHARES.ADD_WARNING'});
		}
	}

}

# Add new server?
if ($cgi->param("a") eq "add") {

	$maintemplate->param("ADD", 1);

}

# Remove server?
if ($cgi->param("a") eq "del") {

	my @fields = split(/\|/, $cgi->param("server"));
	my $server = @fields[0];
	my $type = @fields[1];
	if ($cgi->param("q") ne "y") {
		$maintemplate->param("SELFURL", "/admin/system/netshares.cgi?a=del&s=$server&t=$type");
		$maintemplate->param("SERVER", $server);
		$maintemplate->param("QUESTION", 1);
	} else {
		my $server = $cgi->param("s");
		my $type = $cgi->param("t");
		qx(rm -f $lbhomedir/system/storage/$type/$server);
		qx(rm -f $lbhomedir/system/samba/credentials/$server);
		$maintemplate->param("DEL", 1);
	}

}

# Create debuglog?
if ($cgi->param("a") eq "debuglog") {

	$maintemplate->param("DEBUGLOG", 1);

	# Create a logging object
	my $log = LoxBerry::Log->new (	
			name => 'daemon',
       			filename => "$lbhomedir/log/system_tmpfs/netshare_debug.log",
			package => 'LoxBerry Netshares',
			name => 'netshares.cgi',
			loglevel => 7,
			stderr => 1,
	);
	
	LOGSTART "netshares.cgi - debugging starts";
	LOGALERT "WARNING! THIS LOGFILE WILL CONTAIN YOUR NETSHARE CREDENTIALS!";

	my @netservers = LoxBerry::Storage::get_netservers();
	LOGINF "Output of 'cat /etc/fstab':";
	$log->close;
	qx ( cat /etc/fstab >> $lbhomedir/log/system_tmpfs/netshare_debug.log 2>&1 );
	$log->open;
	LOGINF "Output of 'mount':";
	$log->close;
	qx ( mount >> $lbhomedir/log/system_tmpfs/netshare_debug.log 2>&1 );
	$log->open;
	LOGINF "Output of 'ls -l /etc/creds':";
	$log->close;
	qx ( ls -l /etc/creds  >> $lbhomedir/log/system_tmpfs/netshare_debug.log 2>&1 );
	$log->open;
	LOGINF "Output of 'ls -l $lbhomedir/system/samba/credentials':";
	$log->close;
	qx ( ls -l $lbhomedir/system/samba/credentials  >> $lbhomedir/log/system_tmpfs/netshare_debug.log 2>&1 );
	$log->open;
	foreach my $netserver (@netservers) {
		LOGOK "Server: $netserver->{NETSERVER_SERVER}";
		LOGINF "Type: $netserver->{NETSERVER_TYPE}";
		LOGINF "PATH: $netserver->{NETSERVER_SERVERPATH}";
		if ($netserver->{NETSERVER_TYPE} eq "smb") {
			LOGINF "Output of 'cat $lbhomedir/system/samba/credentials/$netserver->{NETSERVER_SERVER}':";
			$log->close;
			qx ( cat $lbhomedir/system/samba/credentials/$netserver->{NETSERVER_SERVER}  >> $lbhomedir/log/system_tmpfs/netshare_debug.log 2>&1 );
			$log->open;
			LOGINF "Output of '/etc/auto.smb $netserver->{NETSERVER_SERVER}'";
			$log->close;
			qx ( /etc/auto.smb $netserver->{NETSERVER_SERVER} >> $lbhomedir/log/system_tmpfs/netshare_debug.log 2>&1 );
			$log->open;
			LOGINF "Output of 'smbclient -A $lbhomedir/system/samba/credentials/$netserver->{NETSERVER_SERVER} -gL $netserver->{NETSERVER_SERVER} --debuglevel=10':";
			$log->close;
			qx ( smbclient -A $lbhomedir/system/samba/credentials/$netserver->{NETSERVER_SERVER} -gL $netserver->{NETSERVER_SERVER} --debuglevel=10 >> $lbhomedir/log/system_tmpfs/netshare_debug.log 2>&1 );
			$log->open;
		}
	}

}

# Show overview?
if ( !$cgi->param("a") && !$cgi->param("saveformdata") ) {

	# Get all Network shares
	my @netshares = LoxBerry::Storage::get_netshares(0, 1);
	my @netservers = LoxBerry::Storage::get_netservers();
	if (-e "$lbhomedir/log/system_tmpfs/netshare_debug.log" ) {
		$maintemplate->param("DEBUGLOGEXISTS", 1);
	}
	$maintemplate->param("FORM", 1);
	$maintemplate->param("NETSHARES", \@netshares);
	$maintemplate->param("NETSERVERS", \@netservers);

}

# Output Template
print $maintemplate->output();
undef $maintemplate;			

LoxBerry::Web::lbfooter();

exit;
