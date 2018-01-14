#!/usr/bin/perl

# Copyright 2016-2017 Michael Schlenstedt, michael@loxberry.de
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

my $helpurl = "http://www.loxwiki.eu/display/LOXBERRY/LoxBerry";
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
our $helptext;
our $helplink;
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

##########################################################################
# Read Settings
##########################################################################

# Version of this script
my $version = "0.3.3.1";

$cfg                = new Config::Simple("$lbsconfigdir/general.cfg");

my $maintemplate = HTML::Template->new(
			filename => "$lbstemplatedir/admin.html",
			global_vars => 1,
			loop_context_vars => 1,
			die_on_bad_params=> 0,
			associate => $cfg,
			%htmltemplate_options,
			#debug => 1,
			);

my %SL = LoxBerry::System::readlanguage($maintemplate);

#########################################################################
# Parameter
#########################################################################

my $cgi = CGI->new;
$cgi->import_names('R');

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
if (!$R::saveformdata || $R::do eq "form") {
  print STDERR "FORM called\n";
  $maintemplate->param("FORM", 1);
  &form;
} else {
  print STDERR "SAVE called\n";
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
	LoxBerry::Web::head();
	LoxBerry::Web::pagestart($template_title, $helplink, $helptemplate);

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

$adminuser            = trim($R::adminuser);
$adminpass1           = $R::adminpass1;
$adminpass2           = $R::adminpass2;
$adminpassold         = $R::adminpassold;
$securepin1           = $R::securepin1;
$securepin2           = $R::securepin2;
$securepinold         = $R::securepinold;

# First we have to do server-side form validation
if (!$adminuser) {
	$error = $SL{'ADMIN.SAVE_ERR_EMPTY_USER'};
	&error;
} elsif (!$adminpassold && $adminpass1) {
	$error = $SL{'ADMIN.SAVE_ERR_EMPTY_PASS'};
	&error;
} elsif (!$securepinold) {
	$error = $SL{'ADMIN.SAVE_ERR_EMPTY_SECUREPIN'};
	&error;
} elsif ($adminpass1 ne $adminpass2) {
	$error = $SL{'ADMIN.SAVE_ERR_PASS_NOT_IDENTICAL'};
	&error;
} elsif ($securepin1 ne $securepin2) {
	$error = $SL{'ADMIN.SAVE_ERR_SECUREPIN_NOT_IDENTICAL'};
	&error;
} elsif (!$securepin1 && !$adminpass1) {
	$error = $SL{'ADMIN.SAVE_ERR_NOTHING_TO_CHANGE'};
	&error;
}

# Check if SecurePIN is correct
open (my $fh, "<", "$lbsconfigdir/securepin.dat");
  my $pinsaved = <$fh>;
close ($fh);

if (crypt($securepinold, $pinsaved) ne $pinsaved) {
	$error = $SL{'ADMIN.SAVE_ERR_SECUREPIN_WRONG'};
	&error;
}

# First try if default password is still valid:
if ($adminpass1) {
	$nodefaultpwd = 0;
	$output = qx(LANG="en_GB.UTF-8" $lbhomedir/sbin/setloxberrypasswd.exp loxberry $adminpass1 2>&1);
	if ($? ne 0) {
  		print STDERR "setloxberrypasswd.exp adminpass1 ne 0\n";
  		$nodefaultpwd = 1;
	} else {
		$maintemplate->param("ADMINOK", 1);
	}	

	# If default password isn't valid anymore:
	if ($nodefaultpwd) {
	  $output = qx(LANG="en_GB.UTF-8" $lbhomedir/sbin/setloxberrypasswd.exp $adminpassold $adminpass1);
	  if ($? ne 0) {
	  print STDERR "setloxberrypasswd.exp adminpassold ne 0 - ERROR\n";
	    $error = $SL{'ADMIN.SAVE_OK_WRONG_PASSWORD'};
	    &error;
	    exit;
	  } else {
		$maintemplate->param("ADMINOK", 1);
	  }	
	}

	# Try to set new SAMBA passwords for user "loxberry"

	## First try if default password is still valid:
	$output = qx(LANG="en_GB.UTF-8" $lbhomedir/sbin/setloxberrypasswdsmb.exp loxberry $adminpass1);
	## If default password isn't valid anymore:
	$output = qx(LANG="en_GB.UTF-8" $lbhomedir/sbin/setloxberrypasswdsmb.exp $adminpassold $adminpass1);

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
}

# Save Username/Password for Webarea
if ($adminpass1) {
	$output = qx(/usr/bin/htpasswd -b $lbhomedir/config/system/htusers.dat $adminuser $adminpass1);
	# For Apache: /usr/bin/htpasswd -n -b -B -C 5 $adminuser $adminpass1
	#open(F,">$lbhomedir/config/system/htusers.dat") || die "Missing file: config/system/htusers.dat";
	# flock(F,2);
	# print F "$adminpasscrypted";
	# flock(F,8);
	#close(F);
} else {
	$output = qx(/usr/bin/htpasswd -b $lbhomedir/config/system/htusers.dat $adminuser $adminpassold);
	# For Apache: /usr/bin/htpasswd -n -b -B -C 5 $adminuser $adminpass1
	#open(F,">$lbhomedir/config/system/htusers.dat") || die "Missing file: config/system/htusers.dat";
	# flock(F,2);
	# print F "$adminpasscrypted";
	# flock(F,8);
	#close(F);
}

if ($securepin1) {
	$output = qx { sudo --non-interactive $lbhomedir/sbin/setsecurepin.pl $securepinold $securepin1 };
	my $exitcode  = $? >> 8;
	if ($exitcode != 0) {
		$error = $SL{'ADMIN.SAVE_ERR_GENERAL'} . "setsecurepin.pl Errorcode $exitcode";
		&error;
	} else {
		$maintemplate->param("SECUREPINOK", 1);
		print STDERR "setsecurepin.pl securepin1 = 0 - OK\n";
	}
}

if ($adminpass1) {
	$creditwebadmin = "$SL{'ADMIN.SAVE_OK_WEB_ADMIN_AREA'}\t$adminuser / $adminpass1\r\n";
	$creditconsole = "$SL{'ADMIN.SAVE_OK_WEB_ADMIN_AREA'}\t$adminuser / $adminpass1\r\n";
} else {
	$creditwebadmin = "";
	$creditconsole = "";
}
if ($securepin1) {
	$creditsecurepin = "$SL{'ADMIN.SAVE_OK_COL_SECUREPIN'}\t\t\t$securepin1\r\n";
} else {
	$creditsecurepin = "";
}

my $credentialstxt = "$SL{'ADMIN.SAVE_OK_INFO'}\r\n" .  
	"\r\n" .
	$creditwebadmin .
	$creditconsole .
	$creditsecurepin;

$credentialstxt=encode_base64($credentialstxt);

$maintemplate->param( "ADMINUSER", $adminuser );
$maintemplate->param( "ADMINPASS1", $adminpass1 );
$maintemplate->param( "SECUREPIN1", $securepin1 );
$maintemplate->param( "CREDENTIALSTXT", $credentialstxt);
$maintemplate->param( "NEXTURL", "/admin/system/index.cgi?form=system");

$template_title = $SL{'COMMON.LOXBERRY_MAIN_TITLE'} . ": " . $SL{'ADMIN.WIDGETLABEL'};
print STDERR "admin.cgi OUTPUT\n";
LoxBerry::Web::lbheader($template_title, $helplink, $helptemplate);
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
	print STDERR "admin.cgi: sub error called with message $error.\n";
	$errtemplate->param( "ERROR", $error);
	LoxBerry::System::readlanguage($errtemplate);
	LoxBerry::Web::head();
	LoxBerry::Web::pagestart();
	print $errtemplate->output();
	LoxBerry::Web::pageend();
	LoxBerry::Web::foot();
	exit;
}

