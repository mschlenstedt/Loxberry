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
our $version;
our $error;
our $saveformdata;
our $adminuser;
our $adminpass1;
our $adminpass2;
our $adminpassold;
our $output;
our $adminpasscrypted;
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

##########################################################################
# Read Settings
##########################################################################

# Version of this script
$version = "0.3.1-dev1";

$cfg                = new Config::Simple("$lbsconfigdir/general.cfg");
#$installfolder   = $cfg->param("BASE.INSTALLFOLDER");
#$lang            = $cfg->param("BASE.LANG");

my $maintemplate = HTML::Template->new(
			filename => "$lbstemplatedir/admin.html",
			global_vars => 1,
			loop_context_vars => 1,
			die_on_bad_params=> 0,
			associate => $cfg,
			# debug => 1,
			);

LoxBerry::Web::readlanguage($maintemplate);

#########################################################################
# Parameter
#########################################################################

# Everything from URL
foreach (split(/&/,$ENV{'QUERY_STRING'})){
  ($namef,$value) = split(/=/,$_,2);
  $namef =~ tr/+/ /;
  $namef =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/eg;
  $value =~ tr/+/ /;
  $value =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/eg;
  $query{$namef} = $value;
}

# And this one we really want to use
$do           = $query{'do'};

# Everything from Forms
$saveformdata         = param('saveformdata');
$saveformdata          =~ tr/0-1//cd;
$saveformdata          = substr($saveformdata,0,1);
$query{'lang'}         =~ tr/a-z//cd;
$query{'lang'}         =  substr($query{'lang'},0,2);

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
if (!$saveformdata || $do eq "form") {
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

$adminuser            = trim(param('adminuser'));
$adminpass1           = param('adminpass1');
$adminpass2           = param('adminpass2');
$adminpassold         = param('adminpassold');

# First we have to do server-side form validation
if (!$adminuser) {
	$error = $SL{'ADMIN.SAVE_ERR_EMPTY_USER'};
	&error;
} elsif (!$adminpass1 || !$adminpass2) {
	$error = $SL{'ADMIN.SAVE_ERR_EMPTY_PASS'};
	&error;
} elsif ($adminpass1 ne $adminpass2) {
	$error = $SL{'ADMIN.SAVE_ERR_PASS_NOT_IDENTICAL'};
	&error;
}

# Try to set new UNIX passwords for user "loxberry"

# First try if default password is still valid:
$nodefaultpwd = 0;
$output = qx(LANG="en_GB.UTF-8" $lbhomedir/sbin/setloxberrypasswd.exp loxberry $adminpass1);
if ($? ne 0) {
  print STDERR "setloxberrypasswd.exp adminpass1 ne 0\n";
  $nodefaultpwd = 1;
}

# If default password isn't valid anymore:
if ($nodefaultpwd) {
  $output = qx(LANG="en_GB.UTF-8" $lbhomedir/sbin/setloxberrypasswd.exp $adminpassold $adminpass1);
  if ($? ne 0) {
  print STDERR "setloxberrypasswd.exp adminpassold ne 0 - ERROR\n";
    $error = $SL{'ADMIN.SAVE_OK_WRONG_PASSWORD'};
    &error;
    exit;
  }
}

# Try to set new SAMBA passwords for user "loxberry"

## First try if default password is still valid:
$output = qx(LANG="en_GB.UTF-8" $lbhomedir/sbin/setloxberrypasswdsmb.exp loxberry $adminpass1);
## If default password isn't valid anymore:
$output = qx(LANG="en_GB.UTF-8" $lbhomedir/sbin/setloxberrypasswdsmb.exp $adminpassold $adminpass1);

# Save Username/Password for Webarea
$adminpasscrypted = qx(/usr/bin/htpasswd -n -b -B -C 5 $adminuser $adminpass1);
open(F,">$lbhomedir/config/system/htusers.dat") || die "Missing file: config/system/htusers.dat";
 flock(F,2);
 print F "$adminpasscrypted";
 flock(F,8);
close(F);

# Set MYSQL Password
# This only works if the initial password is still valid
# (password: "loxberry")
# Use eval {} here in case somthing went wrong
$sqlerr = 0;
$dsn = "DBI:mysql:database=mysql";
eval {$dbh = DBI->connect($dsn, 'root', $adminpassold )};
$sqlerr = 1 if $@;
eval {$sth = $dbh->prepare("UPDATE mysql.user SET password=Password('$adminpass1') WHERE User='root' AND Host='localhost'")};
$sqlerr = 1 if $@;
eval {$sth->execute()};
$sqlerr = 1 if $@;
eval {$sth = $dbh->prepare("FLUSH PRIVILEGES")};
$sqlerr = 1 if $@;
eval {$sth->execute()};
$sqlerr = 1 if $@;
eval {$sth->finish()};
$sqlerr = 1 if $@;
eval {$dbh->{AutoCommit} = 0};
$sqlerr = 1 if $@;
eval {$dbh->commit};
$sqlerr = 1 if $@;
if ($sqlerr eq 0) {
  $maintemplate->param("SQLOK", 1);
  print STDERR "sqlerr eq 0 - OK\n";
  }

my $credentialstxt = "$SL{'ADMIN.SAVE_OK_INFO'}\r\n" .  
		"\r\n" .
		"$SL{'ADMIN.SAVE_OK_WEB_ADMIN_AREA'}\t$adminuser / $adminpass1\r\n" .
		"$SL{'ADMIN.SAVE_OK_COL_SSH'}\t\tloxberry / $adminpass1\r\n" . 
		"$SL{'ADMIN.SAVE_OK_COL_MYSQL'}\t\troot / $adminpass1\r\n";

$credentialstxt=encode_base64($credentialstxt);
$maintemplate->param( "ADMINUSER", $adminuser );
$maintemplate->param( "ADMINPASS1", $adminpass1 );
$maintemplate->param( "CREDENTIALSTXT", $credentialstxt);
$maintemplate->param( "NEXTURL", "/admin/index.cgi");

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
				# associate => $cfg,
				);
	print STDERR "admin.cgi: sub error called with message $error.\n";
	$errtemplate->param( "ERROR", $error);
	LoxBerry::Web::readlanguage($errtemplate);
	LoxBerry::Web::head();
	LoxBerry::Web::pagestart();
	print $errtemplate->output();
	LoxBerry::Web::pageend();
	LoxBerry::Web::foot();
	exit;
}

