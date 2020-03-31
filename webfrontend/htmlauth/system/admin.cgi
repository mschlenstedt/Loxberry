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
print STDERR "Execute admin.cgi\n#################\n";
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

my $helpurl = "https://www.loxwiki.eu/x/-oYKAw";
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
my $version = "2.0.1.1";

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
  print STDERR "Calling subfunction FORM\n";
  $maintemplate->param("FORM", 1);
  &form;
} else {
  print STDERR "Calling subfunction SAVE\n";
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
	$adminuser            = trim($R::adminuser);
	$adminpass1           = $R::adminpass1;
	$adminpass2           = $R::adminpass2;
	$adminpassold         = $R::adminpassold;
	$securepin1           = $R::securepin1;
	$securepin2           = $R::securepin2;
	$securepinold         = $R::securepinold;

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
	$quoted_adminpassold = quotemeta($R::adminpassold);
	$quoted_adminpass1 = quotemeta($R::adminpass1);
	$output = qx(sudo $lbhomedir/sbin/credentialshandler.pl checkpasswd loxberry $quoted_adminpassold);
	$exitcode  = $? >> 8;
	print STDERR "credentialshandler.pl Exitcode ".$exitcode."\n";
	if ($exitcode == 1) {
		$error = $SL{'ADMIN.SAVE_OK_WRONG_PASSWORD'};
		&error;
	} elsif ($exitcode != 0) {	
		$error = $SL{'ADMIN.SAVE_ERR_GENERAL'} . "credentialshandler.pl checkpasswd Errorcode $exitcode";
		&error;
	}
	
	##
	## AT THIS STAGE, USER HAS SUCCESSFULLY AUTHENTICATED WITH PASSWORD AND SECUREPIN
	##
	
	# Validate username
	if ($adminuser ne $adminuserold) {
		# Username changed
		$_ = $adminuser;
		if (! m/^([A-Za-z0-9]|_-){3,20}$/) {
			$error = $SL{'ADMIN.MSG_VAL_USERNAME_ERROR'};
			&error;
		}
	}
	
	# Validate passwords
	if ($adminpass1 || $adminpass2) {
		$_ = $adminpass1;
		if (! m/^(?=loxberry$)|^(((?=.*[a-zA-Z0-9\-\_\,\.\;\:\!\?\&\(\)\?\+\%\=])(?=.*[A-Z])(?=.*[0-9])(?=.*[a-z])[a-zA-Z0-9\-\_\,\.\;\:\!\?\&\(\)\?\+\%\=]{4,64}$)|^(){0})$/ ) {
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
	if (!$securepin1 && !$adminpass1 && $adminuserold eq $adminuser) {
		$error = $SL{'ADMIN.SAVE_ERR_NOTHING_TO_CHANGE'};
		&error;
	}
	
	##
	## AT THIS STAGE, ALL REQUIRED FIELDS ARE VALIDATED
	##
	
	##
	## User wants to change the username but NOT the password
	##
	if ($adminuser && !$adminpass1) {
	
		# Save Username/Password for Webarea
		$output = qx(/usr/bin/htpasswd -c -b $lbhomedir/config/system/htusers.dat $adminuser $quoted_adminpassold);
		my $exitcode  = $? >> 8;
		if ($exitcode != 0) {
			$error .= "htpasswd htusers.dat adminuser adminpass1 Exitcode $exitcode<br>";
			# &error;
		} else {
			$maintemplate->param("WEBOK", 1);
		} 

	}
	
	##
	## User wants to change the password (and maybe also the username):
	##
	if ($adminpass1) {
		$output = qx(LANG="en_GB.UTF-8" $lbhomedir/sbin/setloxberrypasswd.exp "$adminpassold" "$adminpass1");
		$exitcode  = $? >> 8;
		print STDERR "setloxberrypasswd.exp Exitcode ".$exitcode."\n";
		if ($exitcode eq 1) {
			print STDERR "setloxberrypasswd.exp: ".$SL{'ADMIN.SAVE_ERR_PASS_IDENTICAL'}."\n";
			$error .= $SL{'ADMIN.SAVE_ERR_PASS_IDENTICAL'}."<br>";
			# &error;
			# exit;
		}
		elsif ($exitcode eq 2) {
			print STDERR "setloxberrypasswd.exp: ".$SL{'ADMIN.SAVE_ERR_PASS_WRAPPED'}."\n";
			$error .= $SL{'ADMIN.SAVE_ERR_PASS_WRAPPED'}."<br>";
			$wraperror = 1;
			# &error;
			# exit;
		}
		elsif ($exitcode eq 3) {
			print STDERR "setloxberrypasswd.exp: ".$SL{'ADMIN.SAVE_ERR_PASS_TOO_SIMILAR'}."\n";
			$error .= $SL{'ADMIN.SAVE_ERR_PASS_TOO_SIMILAR'}."<br>";
			$wraperror = 1;
			# &error;
			# exit;
		}
		elsif ($exitcode eq 4) {
			print STDERR "setloxberrypasswd.exp: ".$SL{'ADMIN.SAVE_ERR_PASS_TOO_SHORT'}."\n";
			$error .= $SL{'ADMIN.SAVE_ERR_PASS_TOO_SHORT'}."<br>";
			$wraperror = 1;
			# &error;
			# exit;
		}
		elsif ($exitcode eq 5) {
			print STDERR "setloxberrypasswd.exp: ".$SL{'ADMIN.SAVE_ERR_PASS_GENERAL_ERROR'}."\n";
			$error .= $SL{'ADMIN.SAVE_ERR_PASS_GENERAL_ERROR'}."<br>";
			$wraperror = 1;
			# &error;
			# exit;
		}
		elsif ($exitcode ne 0) {
			print STDERR "setloxberrypasswd.exp: adminpassold Exitcode $exitcode\n";
			$error .= " setloxberrypasswd.exp: adminpassold Exitcode $exitcode<br>";
			# &error;
			# exit;
		} else {
			$maintemplate->param("ADMINOK", 1);
		}	
		if ($wraperror ne 1) {
			
			# Try to set new SAMBA passwords for user "loxberry"
	
			## First try if default password is still valid:
			# $output = qx(LANG="en_GB.UTF-8" $lbhomedir/sbin/setloxberrypasswdsmb.exp loxberry $adminpass1);
			## If default password isn't valid anymore:
			$output = qx(LANG="en_GB.UTF-8" $lbhomedir/sbin/setloxberrypasswdsmb.exp $quoted_adminpassold $quoted_adminpass1);
			$exitcode  = $? >> 8;
			if ($exitcode ne 0) {
				print STDERR "setloxberrypasswdsmb.exp: adminpassold Exitcode $exitcode\n";
				$error .= " setloxberrypasswdsmb.exp: adminpassold Exitcode $exitcode<br>";
				# &error;
				# exit;
			} else {
				$maintemplate->param("SAMBAOK", 1);
			}	
	
			# Set MYSQL Password
			# This only works if the initial password is still valid
			# (password: "loxberry")
			# Use eval {} here in case somthing went wrong
			#$sqlerr = 0;
			#$dsn = "DBI:mysql:database=mysql";
			#eval {$dbh = DBI->connect($dsn, 'root', $adminpassold )};
			#$sqlerr = 1 if $@;
			#eval {$sth = $dbh->prepare("UPDATE mysql.user SET password=Password('$adminpass1') WHERE User='root' AND Host='localhost'")};
			#$sqlerr = 1 if $@;
			#eval {$sth->execute()};
			#$sqlerr = 1 if $@;
			#eval {$sth = $dbh->prepare("FLUSH PRIVILEGES")};
			#$sqlerr = 1 if $@;
			#eval {$sth->execute()};
			#$sqlerr = 1 if $@;
			#eval {$sth->finish()};
			#$sqlerr = 1 if $@;
			#eval {$dbh->{AutoCommit} = 0};
			#$sqlerr = 1 if $@;
			#eval {$dbh->commit};
			#$sqlerr = 1 if $@;
			#if ($sqlerr eq 0) {
			#  $maintemplate->param("SQLOK", 1);
			#  print STDERR "sqlerr eq 0 - OK\n";
			#}
	
			# Save Username/Password for Webarea
			$output = qx(/usr/bin/htpasswd -c -b $lbhomedir/config/system/htusers.dat $adminuser $quoted_adminpass1);
			my $exitcode  = $? >> 8;
			if ($exitcode != 0) {
				$error .= "htpasswd htusers.dat adminuser adminpass1 Exitcode $exitcode<br>";
				# &error;
			} else {
				$maintemplate->param("WEBOK", 1);
			} 
		}
	}

	##
	## User wants to change the SecurePIN:
	##
	if ($securepin1) {
		$output = qx(sudo $lbhomedir/sbin/credentialshandler.pl changesecurepin $securepinold $securepin1);
		my $exitcode  = $? >> 8;
		if ($exitcode ne 0) {
			$error .= "credentialshandler.pl changesecurepin Errorcode $exitcode<br>";
			#&error;
		} else {
			$maintemplate->param("SECUREPINOK", 1);
			print STDERR "credentialshandler.pl: changesecurepin securepin1 = 0 - OK\n";
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
	$maintemplate->param( "NEXTURL", "/admin/system/index.cgi?form=system");

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
