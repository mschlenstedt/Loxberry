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
use File::Samba;
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
my $error;
our $SMB = "$LoxBerry::System::lbhomedir/system/samba/smb.conf";

##########################################################################
# Read Settings
##########################################################################

# Version of this script
my $version = "1.5.0.1";
my $cgi = CGI->new;
$cgi->import_names('R');

##########################################################################
# Main program
##########################################################################

# Prevent 'only used once' warnings from Perl
$R::saveformdata if 0;
%LoxBerry::Web::htmltemplate_options if 0;


##########################################################################
# Read current smb.conf
##########################################################################
my $smbcfg = File::Samba->new("$SMB");
if (!$smbcfg) {
	$error = "Could not read your Samba configuration ($SMB)";
}

##########################################################################
# Check for Ajax requests
##########################################################################

if ($R::saveformdata) {
	ajax();
	exit;
}

# Template
my $maintemplate = HTML::Template->new(
	filename => "$lbstemplatedir/services_samba.html",
	global_vars => 1,
	loop_context_vars => 1,
	die_on_bad_params=> 0,
	#associate => $cfg,
	%LoxBerry::Web::htmltemplate_options,
	# debug => 1,
	);
my %SL = LoxBerry::System::readlanguage($maintemplate);

$maintemplate->param("ERROR", $error);
$maintemplate->param("SMBGLOBAL", LoxBerry::JSON::escape(encode_json($smbcfg->{_global})));




# Navbar
our %navbar;
$navbar{0}{Name} = "$SL{'SERVICES.TITLE_PAGE_WEBSERVER'}";
$navbar{0}{URL} = 'services.php?load=1';
$navbar{1}{Name} = "$SL{'SERVICES.TITLE_PAGE_WATCHDOG'}";
$navbar{1}{URL} = 'services_watchdog.cgi';
$navbar{5}{Name} = "Samba (SMB)";
$navbar{5}{URL} = 'services_samba.cgi';
$navbar{5}{active} = 1;

$navbar{50}{Name} = "$SL{'SERVICES.TITLE_PAGE_OPTIONS'}";
$navbar{50}{URL} = 'services.php?load=3';

# Print Template
my $template_title = $SL{'COMMON.LOXBERRY_MAIN_TITLE'} . ": " . $SL{'SERVICES.WIDGETLABEL'} . " v" . LoxBerry::System::lbversion();
LoxBerry::Web::head();
LoxBerry::Web::pagestart($template_title, $helplink, $helptemplate);
print $maintemplate->output();
LoxBerry::Web::pageend();
LoxBerry::Web::foot();

exit;


######################################################################
# AJAX functions
######################################################################

sub ajax 
{

	my $smbcfg_changed;
	my $tmp_filename = '/tmp/lb_smb_conf_' . int(rand(10000)) . '.tmp';
	my %resp;
	
	if ($smbcfg->globalParameter('workgroup') ne $R::global_workgroup) {
		$smbcfg->globalParameter('workgroup', $R::global_workgroup);
		$smbcfg_changed = 1;
	}
	
	# Parameters were changed
	if($smbcfg_changed) {
		require File::Copy;
		eval {
			$smbcfg->save($tmp_filename);
			$resp{debug} = `testparm -s --debuglevel=1 $tmp_filename 2>&1`;
			my $exitcode = $? >> 8;
			if($exitcode) {
				die ("New configuration file failed the Samba configuration test. Not saved.");
			}
			File::Copy::copy($tmp_filename, $SMB);
		};
		if ($@) {
			$resp{error} = "Error saving configuration: $@";
		}
		unlink $tmp_filename;
		
		# Needs sudo
		`sudo /bin/systemctl reload smbd 2>&1 > /dev/null`; 
		
		print $cgi->header(
			-type => 'application/json',
			-charset => 'utf-8',
			-status => "200 OK",
		);	
		
		delete $resp{debug} if(!$resp{error});
		$resp{statusText} = "Saved successfully.";
		
		
	} else {
		print $cgi->header(
			-type => 'application/json',
			-charset => 'utf-8',
			-status => "200 Not Modified",
		);	
		$resp{statusText} = "No changes.";
	
	}
	
	print encode_json(\%resp);
	
	exit;
}


