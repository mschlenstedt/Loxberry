#!/usr/bin/perl

# Copyright 2016-2020 Michael Schlenstedt, michael@loxberry.de
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
#print STDERR "Execute admin.cgi\n#################\n";
use MIME::Base64;

use CGI::Carp qw(fatalsToBrowser);
use CGI qw/:standard/;
use Config::Simple;
use DBI;
use warnings;
use strict;
# no strict "refs"; # we need it for template system

##########################################################################
# Variables
##########################################################################

my $helpurl = "https://wiki.loxberry.de/konfiguration/widget_help/widget_admin_access";
my $helptemplate = "help_admin.html";

our $cfg;
our $phrase;
our $namef;
our $value;
our %query;
our $lang;
our $template_title;
our $help;
our @help;
our $installfolder;
our $languagefile;
our $error;
our $saveformdata;
our $adminuser;
our $adminpass1;
our $adminpass2;
our $adminpassold;
our $securepin1;
our $securepin2;
our $securepinold;
our $output;
our $message;
our $adminuserold = $ENV{REMOTE_USER};
our $do;
our $nexturl;
our $salt;
our $dsn;
our $dbh;
our $sth;
our $sqlerr;
our $nodefaultpwd;
our $creditwebadmin;
our $creditconsole;
our $creditsecurepin;
our $wraperror = 0;
my $quoted_adminpass1;
my $quoted_adminpassold;

##########################################################################
# Read Settings
##########################################################################

# Version of this script
my $version = "3.0.0.0";

$cfg = new Config::Simple("$lbsconfigdir/general.cfg");

my $cgi = CGI->new;
$cgi->import_names('R');

my $maintemplate = HTML::Template->new(
			filename => "$lbstemplatedir/admin.html",
			global_vars => 1,
			loop_context_vars => 1,
			die_on_bad_params=> 0,
			associate => $cgi,
			%htmltemplate_options,
			#debug => 1,
			);

my %SL = LoxBerry::System::readlanguage($maintemplate);

##########################################################################
# Language Settings
##########################################################################
$lang = lblanguage();
$maintemplate->param( "LBHOSTNAME", lbhostname());
$maintemplate->param( "LANG", $lang);
$maintemplate->param ( "SELFURL", $ENV{REQUEST_URI});

##########################################################################
# Main program
##########################################################################

#########################################################################
# What should we do
#########################################################################

# Step 1 or beginning
$R::saveformdata if (0);
$R::do if (0);

if (!$R::saveformdata || $R::do eq "form") {
  $maintemplate->param("FORM", 1);
  &form;
} else {
  $maintemplate->param("SAVE", 1);
  &save;
}

exit;

#####################################################
# Form
#####################################################

sub form {
	
	$maintemplate->param("ADMINUSEROLD" , $adminuserold);
		
	# Print Template
	$template_title = $SL{'COMMON.LOXBERRY_MAIN_TITLE'} . ": " . $SL{'ADMIN.WIDGETLABEL'};
	LoxBerry::Web::lbheader($template_title, $helpurl, $helptemplate);

	print $maintemplate->output();
	undef $maintemplate;			

	LoxBerry::Web::pageend();
	LoxBerry::Web::foot();
	
	exit;

}

#####################################################
# Save
#####################################################

sub save {

	my $exitcode;
	
	$R::adminuserold if (0);
	$R::adminuser if (0);
	$R::adminpass1 if (0);
	$R::adminpass2 if (0);
	$R::adminpassold if (0);
	$R::securepin1 if (0);
	$R::securepin2 if (0);
	$R::securepinold if (0);
	
	$adminuserold         = $R::adminuserold;
	$adminpassold         = $R::adminpassold;
	$securepinold         = $R::securepinold;
	$adminuser            = trim($R::adminuser);
	$adminpass1           = trim($R::adminpass1);
	$adminpass2           = trim($R::adminpass2);
	$securepin1           = trim($R::securepin1);
	$securepin2           = trim($R::securepin2);

	##################################
	#  server-side form validation
	##################################
	
	# Check password and PIN
	
	# IMMED: SecurePIN does not match
	if (LoxBerry::System::check_securepin($securepinold)) {
		$error = $SL{'ADMIN.SAVE_ERR_SECUREPIN_WRONG'};
		&error;
	}

	# IMMED: Check Password
	$output = qx(sudo $lbssbindir/credentialshandler.pl checkpasswd 'loxberry' '$adminpassold');
	chomp ($output);
	$exitcode  = $? >> 8;
	if ($exitcode == 1) {
		$error = $SL{'ADMIN.SAVE_OK_WRONG_PASSWORD'};
		&error;
	} elsif ($exitcode != 0) {	
		$error = $SL{'ADMIN.SAVE_ERR_GENERAL'} . "credentialshandler.pl checkpasswd Error: $output Errorcode $exitcode";
		&error;
	}
	
	##
	## AT THIS STAGE, USER HAS SUCCESSFULLY AUTHENTICATED WITH PASSWORD AND SECUREPIN
	##
	
	# Validate username
	if ($adminuser ne $adminuserold) {
		# Username changed
		$_ = $adminuser;
		if (! m/^([A-Za-z0-9\_\-]){3,20}$/) {
			$error = $SL{'ADMIN.MSG_VAL_USERNAME_ERROR'};
			&error;
		}
	}
	
	# Validate passwords
	if ($adminpass1 || $adminpass2) {
		$_ = $adminpass1;
		if (m/\"\'\@\:/ ) {
			$error = $SL{'ADMIN.MSG_VAL_PASSWORD_ERROR'};
			&error;
		}
		if ($adminpass1 ne $adminpass2) {
			$error = $SL{'ADMIN.MSG_VAL_PASSWORD_DIFFERENT'};
			&error;
		}
	}

	# Validate new SecurePINs
	if ($securepin1 || $securepin2) {
		$_ = $securepin1;
		if (! m/^((([A-Za-z0-9]){4,10})|(){0})$/ ) {
			$error = $SL{'ADMIN.MSG_VAL_SECUREPIN_ERROR'};
			&error;
		}
		if ( $securepin1 ne $securepin2 ) {
			$error = $SL{'ADMIN.MSG_VAL_SECUREPIN_DIFFERENT'};
			&error;
		}
	}

	# Validate if anything was changed
	#if (!$securepin1 && !$adminpass1 && $adminuserold eq $adminuser) {
	#	$error = $SL{'ADMIN.SAVE_ERR_NOTHING_TO_CHANGE'};
	#	&error;
	#}
	
	##
	## AT THIS STAGE, ALL REQUIRED FIELDS ARE VALIDATED
	##
	
	##
	## User wants to change the username but NOT the password
	##
	if ($adminuser && !$adminpass1) {
	
		# Save Username/Password for Webarea
		#$output = qx(/usr/bin/htpasswd -c -b $lbhomedir/config/system/htusers.dat $adminuser $quoted_adminpassold);
		$output = qx(sudo $lbssbindir/credentialshandler.pl changewebuipasswd '$adminuser' '$adminpassold');
		my $exitcode  = $? >> 8;
		if ($exitcode != 0) {
			chomp ($output);
			$error .= "credentialshandler.pl changewebuipasswd adminuser adminpass1 Error: $output Exitcode: $exitcode<br>";
		} else {
			$maintemplate->param("WEBOK", 1);
		} 

	}
	
	##
	## User wants to change the password (and maybe also the username):
	##
	if ($adminpass1) {
		# Save Username/Password for System
		$output = qx(sudo $lbssbindir/credentialshandler.pl changepasswd 'loxberry' '$adminpassold' '$adminpass1');
		$exitcode  = $? >> 8;
		if ($exitcode != 0) {
			chomp ($output);
			$error .= "credentialshandler.pl changepasswd loxberry adminpass1 Error: $output Exitcode: $exitcode<br>";
		} else {
			$maintemplate->param("ADMINOK", 1);
			# Save Username/Password for Webarea
			$output = qx(sudo $lbssbindir/credentialshandler.pl changewebuipasswd '$adminuser' '$adminpass1');
			my $exitcode  = $? >> 8;
			if ($exitcode != 0) {
				chomp ($output);
				$error .= "credentialshandler.pl changewebuipasswd adminuser adminpass1 Error: $output Exitcode: $exitcode<br>";
			} else {
				$maintemplate->param("WEBOK", 1);
			}	
		}
	}

	##
	## User wants to change the SecurePIN:
	##
	if ($securepin1) {
		$output = qx(sudo $lbhomedir/sbin/credentialshandler.pl changesecurepin '$securepinold' '$securepin1');
		my $exitcode  = $? >> 8;
		if ($exitcode ne 0) {
			chomp ($output);
			$error .= "credentialshandler.pl changesecurepin Error: $output Errorcode: $exitcode<br>";
		} else {
			$maintemplate->param("SECUREPINOK", 1);
		}
	}
	
	##
	## Overview of new passwords:
	##
	if ($adminpass1 && $wraperror ne 1) {
		$creditwebadmin = "$SL{'ADMIN.SAVE_OK_WEB_ADMIN_AREA'}\t$adminuser / $adminpass1\r\n";
		$creditconsole = "$SL{'ADMIN.SAVE_OK_COL_SSH'}\tloxberry / $adminpass1\r\n";
		$maintemplate->param( "ADMINPASS", $adminpass1 );
	} else {
		$creditwebadmin = "$SL{'ADMIN.SAVE_OK_WEB_ADMIN_AREA'}\t$adminuser / $adminpassold\r\n";
		$creditconsole = "$SL{'ADMIN.SAVE_OK_COL_SSH'}\tloxberry / $adminpassold\r\n";
		$maintemplate->param( "ADMINPASS", $adminpassold );
	}
	if ($securepin1) {
		$creditsecurepin = "$SL{'ADMIN.SAVE_OK_COL_SECUREPIN'}\t$securepin1\r\n";
		$maintemplate->param( "SECUREPIN", $securepin1 );
	} else {
		$creditsecurepin = "$SL{'ADMIN.SAVE_OK_COL_SECUREPIN'}\t$securepinold\r\n";
		$maintemplate->param( "SECUREPIN", $securepinold );
	}

	my $credentialstxt = "$SL{'ADMIN.SAVE_OK_INFO'}\r\n" .  
		"\r\n" .
		$creditwebadmin .
		$creditconsole .
		$creditsecurepin;

	# $credentialstxt=encode_base64($credentialstxt);
	$credentialstxt=URI::Escape::uri_escape($credentialstxt);
	
	$maintemplate->param( "ADMINUSER", $adminuser );
	$maintemplate->param( "CREDENTIALSTXT", $credentialstxt);
	
	$maintemplate->param( "ERRORS", $error);
	$maintemplate->param( "NEXTURL", "/admin/system/admin.cgi");

	$template_title = $SL{'COMMON.LOXBERRY_MAIN_TITLE'} . ": " . $SL{'ADMIN.WIDGETLABEL'};
	print STDERR "admin.cgi: Send OUTPUT and exit\n";
	LoxBerry::Web::lbheader($template_title, $helpurl, $helptemplate);
	print $maintemplate->output();
	LoxBerry::Web::lbfooter();
	exit;

}

exit;


#####################################################
# 
# Subroutines
#
#####################################################

#####################################################
# Error
#####################################################

sub error {

$template_title = $SL{'COMMON.LOXBERRY_MAIN_TITLE'} . ": " . $SL{'ADMIN.WIDGETLABEL'};

	my $errtemplate = HTML::Template->new(
				filename => "$lbstemplatedir/error.html",
				global_vars => 1,
				loop_context_vars => 1,
				die_on_bad_params=> 0,
				%htmltemplate_options,
				# associate => $cfg,
				);
	print STDERR "admin.cgi: Sub ERROR called with message $error.\n";
	$errtemplate->param( "ERROR", $error);
	LoxBerry::System::readlanguage($errtemplate);
	LoxBerry::Web::head();
	LoxBerry::Web::pagestart();
	print $errtemplate->output();
	LoxBerry::Web::pageend();
	LoxBerry::Web::foot();
	exit;
}
