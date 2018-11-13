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
my $version = "1.2.0.2";

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
		filename => "$lbstemplatedir/usbstorage.html",
		global_vars => 1,
		loop_context_vars => 1,
		die_on_bad_params=> 0,
		associate => $cfg,
		%htmltemplate_options,
		# debug => 1,
		);
	
my %SL = LoxBerry::System::readlanguage($maintemplate);

# Print Template
$template_title = $SL{'COMMON.LOXBERRY_MAIN_TITLE'} . ": " . $SL{'USBSTORAGE.WIDGETLABEL'};

LoxBerry::Web::lbheader();

# Create debuglog?
if ($cgi->param("a") eq "debuglog") {

	$maintemplate->param("DEBUGLOG", 1);

	# Create a logging object
	my $log = LoxBerry::Log->new (	
			name => 'daemon',
       			filename => "$lbhomedir/log/system_tmpfs/usbstorage_debug.log",
			package => 'LoxBerry USB Storage',
			name => 'usbstorage.cgi',
			loglevel => 7,
			stderr => 1,
	);
	
	LOGSTART "usbstorage.cgi - debugging starts";

	my @usbstorages = LoxBerry::Storage::get_usbstorage("H");

	LOGINF "Output of 'cat /etc/fstab':";
	$log->close;
	qx ( cat /etc/fstab >> $lbhomedir/log/system_tmpfs/usbstorage_debug.log 2>&1 );
	$log->open;
	LOGINF "Output of 'mount':";
	$log->close;
	qx ( mount >> $lbhomedir/log/system_tmpfs/usbstorage_debug.log 2>&1 );
	$log->open;
	LOGINF "Output of 'dmesg':";
	$log->close;
	qx ( dmesg  >> $lbhomedir/log/system_tmpfs/usbstorage_debug.log 2>&1 );
	$log->open;
	LOGINF "Output of 'lsblk -a -l -O':";
	$log->close;
	qx ( lsblk -a -l -O  >> $lbhomedir/log/system_tmpfs/usbstorage_debug.log 2>&1 );
	$log->open;
	LOGINF "Output of 'lsusb -v':";
	$log->close;
	qx ( lsusb -v  >> $lbhomedir/log/system_tmpfs/usbstorage_debug.log 2>&1 );
	$log->open;
	LOGINF "Output of 'df -a -T':";
	$log->close;
	qx ( df -a -T >> $lbhomedir/log/system_tmpfs/usbstorage_debug.log 2>&1 );
	$log->open;
	foreach my $usbstorage (@usbstorages) {
		LOGOK "Device: $usbstorage->{USBSTORAGE_DEVICE}";
		LOGINF "Block Device: $usbstorage->{USBSTORAGE_BLOCKDEVICE}";
		LOGINF "Type: $usbstorage->{USBSTORAGE_TYPE}";
		LOGINF "PATH: $usbstorage->{USBSTORAGE_DEVICEPATH}";
	}

}

# Show overview?
if ( !$cgi->param("a") ) {

	# Get all Network shares
	my @usbstorages = LoxBerry::Storage::get_usbstorage("H");
	if (-e "$lbhomedir/log/system_tmpfs/usbstorage_debug.log" ) {
		$maintemplate->param("DEBUGLOGEXISTS", 1);
	}
	$maintemplate->param("FORM", 1);
	$maintemplate->param("USBSTORAGES", \@usbstorages);

}

# Output Template
print $maintemplate->output();
undef $maintemplate;			

LoxBerry::Web::lbfooter();

exit;
