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
use LoxBerry::Log;
use LoxBerry::JSON;
use CGI::Carp qw(fatalsToBrowser);
use CGI;
use warnings;
use strict;

##########################################################################
# Variables
##########################################################################

my $helpurl = "http://www.loxwiki.eu/display/LOXBERRY/LoxBerry";
my $helptemplate = "help_mailserver.html";

#our $cfg;
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

my $mailobj;
my $mcfg;

my %response;
$response{error} = -1;
$response{message} = "Unspecified error";

##########################################################################
# Read Settings
##########################################################################

# Version of this script
my $version = "1.4.0.1";
my $cgi = CGI->new;
$cgi->import_names('R');

#$cfg                = new Config::Simple("$lbhomedir/config/system/general.cfg");

# $mcfg               = new Config::Simple("$lbhomedir/config/system/mail.cfg");
# $email              = $mcfg->param("SMTP.EMAIL");
# $smtpserver         = $mcfg->param("SMTP.SMTPSERVER");
# $smtpport           = $mcfg->param("SMTP.PORT");
# $smtpcrypt          = $mcfg->param("SMTP.CRYPT");
# $smtpauth           = $mcfg->param("SMTP.AUTH");
# $smtpuser           = $mcfg->param("SMTP.SMTPUSER");
# $smtppass           = $mcfg->param("SMTP.SMTPPASS");


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
# $R::saveformdata if 0;
$R::action if 0;
$R::value if 0;
$R::activate_mail if 0;
$R::secpin if 0;

my $action = $R::action;
my $value = $R::value;

if ($action eq 'getmailcfg') { change_mailcfg("getmailcfg", $R::secpin);}
elsif ($action eq 'setmailcfg') { change_mailcfg("setmailcfg"); }
elsif ($action eq 'MAIL_SYSTEM_INFOS') { change_mailcfg("MAIL_SYSTEM_INFOS", $value);}
elsif ($action eq 'MAIL_SYSTEM_ERRORS') { change_mailcfg("MAIL_SYSTEM_ERRORS", $value);}
elsif ($action eq 'MAIL_PLUGIN_INFOS') { change_mailcfg("MAIL_PLUGIN_INFOS", $value);}
elsif ($action eq 'MAIL_PLUGIN_ERRORS') { change_mailcfg("MAIL_PLUGIN_ERRORS", $value);}

# If not ajax, it must be the form
&form;

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
		#associate => $cfg,
		%htmltemplate_options,
		# debug => 1,
		);

	my %SL = LoxBerry::System::readlanguage($maintemplate);

	$maintemplate->param("FORM", 1);
	$maintemplate->param( "LBHOSTNAME", lbhostname());
	$maintemplate->param( "LANG", $lang);
	# $maintemplate->param ( "SELFURL", $ENV{REQUEST_URI});
	# $maintemplate->param ( 	"EMAIL" => $email, 
							# "SMTPSERVER" => $smtpserver,
							# "SMTPPORT" => $smtpport,
							# "SMTPUSER" => $smtpuser,
							# "SMTPPASS" => $smtppass
							# );
	
	# Defaults for template
	# if ($smtpcrypt) {
	  # $maintemplate->param( "CHECKED1", 'checked="checked"');
	# }
	# if ($smtpauth) {
	  # $maintemplate->param(  "CHECKED2", 'checked="checked"');
	# }
	
	# if (is_enabled($mcfg->param("NOTIFICATION.MAIL_SYSTEM_INFOS"))) {
		# $maintemplate->param("MAIL_SYSTEM_INFOS", 'checked');
	# }
	# if (is_enabled($mcfg->param("NOTIFICATION.MAIL_SYSTEM_ERRORS"))) {
		# $maintemplate->param("MAIL_SYSTEM_ERRORS", 'checked');
	# }
	# if (is_enabled($mcfg->param("NOTIFICATION.MAIL_PLUGIN_INFOS"))) {
		# $maintemplate->param("MAIL_PLUGIN_INFOS", 'checked');
	# }
	# if (is_enabled($mcfg->param("NOTIFICATION.MAIL_PLUGIN_ERRORS"))) {
		# $maintemplate->param("MAIL_PLUGIN_ERRORS", 'checked');
	# }
	
	# Print Template
	$template_title = $SL{'COMMON.LOXBERRY_MAIN_TITLE'} . ": " . $SL{'MAILSERVER.WIDGETLABEL'};
	LoxBerry::Web::head();
	LoxBerry::Web::pagestart($template_title, $helplink, $helptemplate);
	print LoxBerry::Log::get_notifications_html("mailserver");
	print $maintemplate->output();
	LoxBerry::Web::pageend();
	LoxBerry::Web::foot();
	
	exit;

}

###################################################################
# change mail configuration (mail.json) (AJAX)
###################################################################
sub change_mailcfg
{
	my ($key, $val) = @_;
	if (!$key) {
		return undef;
	}
	
	my $mailfile = $lbsconfigdir . "/mail.json";
	
	$mailobj = LoxBerry::JSON->new();
	$mcfg = $mailobj->open(filename => $mailfile);
	
	if($key eq "getmailcfg" and defined $val) {
		exit if(checksecpin($val));
		$response{error} = 0;
		$response{customresponse} = 1;
		$response{output} = encode_json($mcfg);
	} 
	elsif($key eq "setmailcfg") {
		eval {
			save();
		};
		my %SL = LoxBerry::System::readlanguage();
		if ($@) {
			$response{error} = 1;
			$response{message} = 'MAILSERVER.SAVE_ERROR';
			$response{reason} = $!;
		} else {
			$response{error} = 0;
			$response{message} = 'MAILSERVER.SAVE_SUCCESS';
		}
	}
	elsif (!$val) {
		# Delete key
		delete $mcfg->{NOTIFICATION}->{$key};
		$mailobj->write() or return undef;
		$response{error} = 0;
		$response{message} = "mail.json: $key deleted";
	} elsif ($mcfg->{NOTIFICATION}->{$key} ne $val) {
		$mcfg->{NOTIFICATION}->{$key} = $val;
		$mailobj->write() or return undef;
		$response{error} = 0;
		$response{message} = "mail.json: $key changed to $val";
	}
	
	jsonresponse();
}



#####################################################
# Save (AJAX)
#####################################################

sub save 
{

	my $bins = LoxBerry::System::get_binaries();
	$mailbin = $bins->{MAIL};

	my %SL = LoxBerry::System::readlanguage();

	
	

	
	# Write configuration file(s)
	# $mcfg->param("SMTP.ISCONFIGURED", "1");
	# $mcfg->param("SMTP.EMAIL", "$R::email");
	# $mcfg->param("SMTP.SMTPSERVER", "$R::smtpserver");
	# $mcfg->param("SMTP.PORT", "$R::smtpport");
	# $mcfg->param("SMTP.CRYPT", "$R::smtpcrypt");
	# $mcfg->param("SMTP.AUTH", "$R::smtpauth");
	# $mcfg->param("SMTP.SMTPUSER", "\"$R::smtpuser\"");
	# $mcfg->param("SMTP.SMTPPASS", "\"$R::smtppass\"");
	# $mcfg->save();

	# $mcfg->{SMTP}->{ISCONFIGURED} = $R::
		
	$mcfg->{SMTP}->{ACTIVATE_MAIL} = is_enabled($R::activate_mail) ? 1 : 0;
	$mcfg->{SMTP}->{AUTH} = is_enabled($R::smtpauth) ? 1 : 0;
	$mcfg->{SMTP}->{CRYPT} = is_enabled($R::smtpcrypt) ? 1 : 0;
	$mcfg->{SMTP}->{SMTPSERVER} = $R::smtpserver;
	$mcfg->{SMTP}->{PORT} = $R::smtpport;
	$mcfg->{SMTP}->{EMAIL} = $R::email;
	$mcfg->{SMTP}->{SMTPUSER} = $R::smtpuser;
	$mcfg->{SMTP}->{SMTPPASS} = $R::smtppass;
	
	$mailobj->write();
	
	
	

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

	# $maintemplate->param( "MESSAGE", $SL{'MAILSERVER.SAVESUCCESS'});
	# $maintemplate->param( "NEXTURL", "/admin/system/index.cgi?form=system");

	# # Print Template
	# $template_title = $SL{'COMMON.LOXBERRY_MAIN_TITLE'} . ": " . $SL{'ADMIN.WIDGETLABEL'};
	# LoxBerry::Web::lbheader($template_title, $helplink, $helptemplate);
	# print $maintemplate->output();
	# undef $maintemplate;			
	# LoxBerry::Web::lbfooter();
		
	return;

}


sub jsonresponse {

	if($response{error} == -1) {
		print $cgi->header(
			-type => 'application/json',
			-charset => 'utf-8',
			-status => '500 Internal Server Error',
		);	
	} else {
		print $cgi->header(
			-type => 'application/json',
			-charset => 'utf-8',
			-status => '200 OK',
		);	
	}

	if (!$response{customresponse}) {
		print encode_json(\%response);
	} else {
		print $response{output};
	}
	exit($response{error});

}


sub checksecpin
{
	my ($secpin) = @_;
	my $checkres = LoxBerry::System::check_securepin($secpin);
	if ( $checkres and $checkres == 1 ) {
		$response{message} = "The entered SecurePIN is wrong. Please try again.";
		$response{error} = 1;
    } elsif ( $checkres and $checkres == 2) {
		$response{message} = "Your SecurePIN file could not be opened.";
		$response{error} = 2;
	} else {
    		$response{message} = "You have entered the correct SecurePIN.";
			$response{error} = 0;
	}

	return $response{error};

}
