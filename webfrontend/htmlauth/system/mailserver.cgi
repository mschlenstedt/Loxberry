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
use CGI::Carp qw(fatalsToBrowser);
use CGI;
use warnings;
use strict;

##########################################################################
# Variables
##########################################################################

my $helpurl = "http://www.loxwiki.eu/display/LOXBERRY/LoxBerry";
my $helptemplate = "help_mailserver.html";

our $cfg;
our $mcfg;
our $lang;
our $template_title;
our $helplink;
our $email;
our $smtpserver;
our $smtpport;
our $smtpcrypt;
our $smtpauth;
our $smtpuser;
our $smtppass;
our $mailbin;

##########################################################################
# Read Settings
##########################################################################

# Version of this script
my $version = "0.3.2.2";
my $cgi = CGI->new;
$cgi->import_names('R');
$cfg                = new Config::Simple("$lbhomedir/config/system/general.cfg");
$mailbin            = $cfg->param("BINARIES.MAIL");

$mcfg               = new Config::Simple("$lbhomedir/config/system/mail.cfg");
$email              = $mcfg->param("SMTP.EMAIL");
$smtpserver         = $mcfg->param("SMTP.SMTPSERVER");
$smtpport           = $mcfg->param("SMTP.PORT");
$smtpcrypt          = $mcfg->param("SMTP.CRYPT");
$smtpauth           = $mcfg->param("SMTP.AUTH");
$smtpuser           = $mcfg->param("SMTP.SMTPUSER");
$smtppass           = $mcfg->param("SMTP.SMTPPASS");


#########################################################################
# Parameter
#########################################################################

# Everything from URL

##########################################################################
# Language Settings
##########################################################################
$lang = lblanguage();

##########################################################################
# Main program
##########################################################################

#########################################################################
# What should we do
#########################################################################

# Prevent 'only used once' warnings from Perl
$R::saveformdata if 0;
$R::do if 0;


if (!$R::saveformdata || $R::do eq "form") 
{
  &form;
} else {
  &save;
}

exit;

#####################################################
# Form
#####################################################

sub form 
{
	my $maintemplate = HTML::Template->new(
		filename => "$lbstemplatedir/mailserver.html",
		global_vars => 1,
		loop_context_vars => 1,
		die_on_bad_params=> 0,
		associate => $cfg,
		%htmltemplate_options,
		# debug => 1,
		);

	my %SL = LoxBerry::System::readlanguage($maintemplate);

	$maintemplate->param("FORM", 1);
	$maintemplate->param( "LBHOSTNAME", lbhostname());
	$maintemplate->param( "LANG", $lang);
	$maintemplate->param ( "SELFURL", $ENV{REQUEST_URI});
	$maintemplate->param ( 	"EMAIL" => $email, 
							"SMTPSERVER" => $smtpserver,
							"SMTPPORT" => $smtpport,
							"SMTPUSER" => $smtpuser,
							"SMTPPASS" => $smtppass
							);
	
	# Defaults for template
	if ($smtpcrypt) {
	  $maintemplate->param( "CHECKED1", 'checked="checked"');
	}
	if ($smtpauth) {
	  $maintemplate->param(  "CHECKED2", 'checked="checked"');
	}
	
	# Print Template
	$template_title = $SL{'COMMON.LOXBERRY_MAIN_TITLE'} . ": " . $SL{'MAILSERVER.WIDGETLABEL'};
	LoxBerry::Web::head();
	LoxBerry::Web::pagestart($template_title, $helplink, $helptemplate);
	print $maintemplate->output();
	LoxBerry::Web::pageend();
	LoxBerry::Web::foot();
	
	exit;

}

#####################################################
# Save
#####################################################

sub save 
{

	my $maintemplate = HTML::Template->new(
		filename => "$lbstemplatedir/success.html",
		global_vars => 1,
		loop_context_vars => 1,
		die_on_bad_params=> 0,
		associate => $cfg,
		%htmltemplate_options, 
		# debug => 1,
		);
	
	my %SL = LoxBerry::System::readlanguage($maintemplate);

	# print STDERR "SAVE called\n";
	$maintemplate->param("SAVE", 1);
	$maintemplate->param( "LBHOSTNAME", lbhostname());
	$maintemplate->param( "LANG", $lang);
	$maintemplate->param ( "SELFURL", $ENV{REQUEST_URI});
	
	# # Everything from Forms
	# $email        = param('email');
	# $smtpserver   = param('smtpserver');
	# $smtpport     = param('smtpport');
	# $smtpcrypt    = param('smtpcrypt');
	# $smtpauth     = param('smtpauth');
	# $smtpuser     = param('smtpuser');
	# $smtppass     = param('smtppass');

	# Prevent warnings 'only used once'
	$R::email if (0);
	$R::smtpserver if (0);
	$R::smtpport if (0);
	$R::smtpcrypt if (0);
	$R::smtpauth if (0);
	$R::smtpuser if (0);
	$R::smtppass if (0);
	
	# Write configuration file(s)
	$mcfg->param("SMTP.ISCONFIGURED", "1");
	$mcfg->param("SMTP.EMAIL", "$R::email");
	$mcfg->param("SMTP.SMTPSERVER", "$R::smtpserver");
	$mcfg->param("SMTP.PORT", "$R::smtpport");
	$mcfg->param("SMTP.CRYPT", "$R::smtpcrypt");
	$mcfg->param("SMTP.AUTH", "$R::smtpauth");
	$mcfg->param("SMTP.SMTPUSER", "$R::smtpuser");
	$mcfg->param("SMTP.SMTPPASS", "$R::smtppass");
	$mcfg->save();



	# Activate new configuration

	# Create temporary SSMTP Config file
	open(F,">/tmp/tempssmtpconf.dat") || die "Cannot open /tmp/tempssmtpconf.dat";
	print F <<ENDFILE;
#
# Config file for sSMTP sendmail
#
# The person who gets all mail for userids < 1000
# Make this empty to disable rewriting.
ENDFILE

	print F "root=$R::email\n\n";

	print F <<ENDFILE;
# The place where the mail goes. The actual machine name is required no
# MX records are consulted. Commonly mailhosts are named mail.domain.com
ENDFILE
	print F "mailhub=$R::smtpserver\:$R::smtpport\n\n";

	if ($R::smtpauth) {
		print F "# Authentication\n";
		print F "AuthUser=$R::smtpuser\n";
		print F "AuthPass=$R::smtppass\n\n";
	}

	if ($R::smtpcrypt) {
		print F "# Use encryption\n";
		print F "UseTLS=YES\n";
		print F "UseSTARTTLS=YES\n\n";
	} else {
		print F "# Dont use encryption\n";
		print F "UseTLS=NO\n";
		print F "UseSTARTTLS=NO\n\n";
	}

	print F <<ENDFILE;
# Where will the mail seem to come from?
#rewriteDomain=

# The full hostname
hostname=loxberry.local

# Are users allowed to set their own From: address?
# YES - Allow the user to specify their own From: address
# NO - Use the system gen
FromLineOverride=YES
ENDFILE
	close(F);

	# Install temporary ssmtp config file
	my $result = qx($lbhomedir/sbin/createssmtpconf.sh start 2>/dev/null);

	$result = qx(echo "$SL{'MAILSERVER.TESTMAIL_CONTENT'}" | $mailbin -a "From: $email" -s "$SL{'MAILSERVER.TESTMAIL_SUBJECT'}" -v $email 2>&1);

	# Delete old temporary config file
	if (-e "/tmp/tempssmtpconf.dat" && -f "/tmp/tempssmtpconf.dat" && !-l "/tmp/tempssmtpconf.dat" && -T "/tmp/tempssmtpconf.dat") {
	  unlink ("/tmp/tempssmtpconf.dat");
	}

	$maintemplate->param( "MESSAGE", $SL{'MAILSERVER.SAVESUCCESS'});
	$maintemplate->param( "NEXTURL", "/admin/system/index.cgi?form=system");

	# Print Template
	$template_title = $SL{'COMMON.LOXBERRY_MAIN_TITLE'} . ": " . $SL{'ADMIN.WIDGETLABEL'};
	LoxBerry::Web::lbheader($template_title, $helplink, $helptemplate);
	print $maintemplate->output();
	undef $maintemplate;			
	LoxBerry::Web::lbfooter();
		
	exit;

}

exit;
