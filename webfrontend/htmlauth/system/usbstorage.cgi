#!/usr/bin/perl

# Copyright 2018-2020 Michael Schlenstedt, michael@loxberry.de
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
use LoxBerry::JSON;
use Data::Dumper;
use warnings;
use strict;

##########################################################################
# Variables
##########################################################################

our $helpurl = "https://wiki.loxberry.de/konfiguration/widget_help/widget_usb_storages";

##########################################################################
# Read Settings
##########################################################################

# Version of this script
my $version = "2.0.2.1";

##########################################################################
# Language Settings
##########################################################################

my $lang = lblanguage();

##########################################################################
# Main program
##########################################################################

# Get CGI
my  $cgi = CGI->new;

my $maintemplate = HTML::Template->new(
		filename => "$lbstemplatedir/usbstorage.html",
		global_vars => 1,
		loop_context_vars => 1,
		die_on_bad_params=> 0,
		# associate => $cfg,
		%htmltemplate_options,
		# debug => 1,
		);
	
my %SL = LoxBerry::System::readlanguage($maintemplate);

# Print Template
my $template_title = $SL{'COMMON.LOXBERRY_MAIN_TITLE'} . ": " . $SL{'USBSTORAGE.WIDGETLABEL'};

LoxBerry::Web::lbheader($template_title, $helpurl, "help_usbstorage.html");

my $param_a=$cgi->param("a") if $cgi->param("a");

# Create debuglog?
if ($param_a eq "debuglog") {

	$maintemplate->param("DEBUGLOG", 1);

	# Create a logging object
	my $log = LoxBerry::Log->new (	
			name => 'daemon',
       			filename => "$lbhomedir/log/system_tmpfs/usbstorage_debug.log",
			package => 'core',
			name => 'USB Storage',
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

} else {
	
	# Show overview
	# Get all USB shares
	my @usbstorages = LoxBerry::Storage::get_usbstorage("H");
	if (-e "$lbhomedir/log/system_tmpfs/usbstorage_debug.log" ) {
		$maintemplate->param("DEBUGLOGEXISTS", 1);
	}
	$maintemplate->param("USBSTORAGES", \@usbstorages);
	$maintemplate->param("OVERVIEW", 1);

}

# Output Template
print $maintemplate->output();
undef $maintemplate;			

LoxBerry::Web::lbfooter();

exit;
