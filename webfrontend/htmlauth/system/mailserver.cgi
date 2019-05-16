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
use LoxBerry::JSON;
#use CGI::Carp qw(fatalsToBrowser);
use CGI;
use warnings;
use strict;

##########################################################################
# Variables
##########################################################################

my $helpurl = "https://www.loxwiki.eu/x/j4gKAw";
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
my %SL;
my $action="";
my $value="";
my %response;
$response{error} = -1;
$response{message} = "Unspecified error";

##########################################################################
# Read Settings
##########################################################################

# Version of this script
my $version = "1.4.2.1";
my $cgi = CGI->new;
$cgi->import_names('R');

##########################################################################
# Language Settings
##########################################################################
$lang = lblanguage();

##########################################################################
# Main program
##########################################################################

# Prevent 'only used once' warnings from Perl
# $R::saveformdata if 0;
$R::action if 0;
$R::value if 0;
$R::activate_mail if 0;
$R::secpin if 0;
$R::smptport if 0;
%LoxBerry::Web::htmltemplate_options if 0;

$action = $R::action if $R::action;
$value = $R::value if $R::value;

if ($action eq 'getmailcfg') { change_mailcfg("getmailcfg", $R::secpin);}
elsif ($action eq 'setmailcfg') { change_mailcfg("setmailcfg"); }
elsif ($action eq 'MAIL_SYSTEM_INFOS') { change_mailcfg("MAIL_SYSTEM_INFOS", $value);}
elsif ($action eq 'MAIL_SYSTEM_ERRORS') { change_mailcfg("MAIL_SYSTEM_ERRORS", $value);}
elsif ($action eq 'MAIL_PLUGIN_INFOS') { change_mailcfg("MAIL_PLUGIN_INFOS", $value);}
elsif ($action eq 'MAIL_PLUGIN_ERRORS') { change_mailcfg("MAIL_PLUGIN_ERRORS", $value);}
elsif ($action eq 'testmail') { testmail_button(); }


require LoxBerry::Web;
require LoxBerry::Log;


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
		%LoxBerry::Web::htmltemplate_options,
		# debug => 1,
		);

	%SL = LoxBerry::System::readlanguage($maintemplate);

	$maintemplate->param("FORM", 1);
	$maintemplate->param( "LBHOSTNAME", lbhostname());
	$maintemplate->param( "LANG", $lang);

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
	
	# %SL = LoxBerry::System::readlanguage();

	
	$mailobj = LoxBerry::JSON->new();
	$mcfg = $mailobj->open(filename => $mailfile);
	
	if($key eq "getmailcfg") {
		my $resp = checksecpin($val);
		if($resp == 0) {
			$response{error} = 0;
			$response{customresponse} = 1;
			$response{output} = to_json($mcfg);
		}
	} 
	elsif($key eq "setmailcfg") {
		#eval {
			save();
		#};
		if ($@) {
			$response{error} = 1;
			$response{message} = "Error: $!";
		} else {
			$response{error} = 0;
			$response{message} = "Successfully saved.";
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
	
	%SL = LoxBerry::System::readlanguage();
	
	$mcfg->{SMTP}->{ACTIVATE_MAIL} = is_enabled($R::activate_mail) ? 1 : 0;
	$mcfg->{SMTP}->{AUTH} = is_enabled($R::smtpauth) ? 1 : 0;
	$mcfg->{SMTP}->{CRYPT} = is_enabled($R::smtpcrypt) ? 1 : 0;
	$mcfg->{SMTP}->{SMTPSERVER} = $R::smtpserver;
	$mcfg->{SMTP}->{PORT} = $R::smtpport;
	$mcfg->{SMTP}->{EMAIL} = $R::email;
	$mcfg->{SMTP}->{SMTPUSER} = $R::smtpuser;
	$mcfg->{SMTP}->{SMTPPASS} = $R::smtppass;
	
	$mailobj->write();
	
	# Delete values if email is disabled
	if (! $mcfg->{SMTP}->{ACTIVATE_MAIL}) {
		$R::smtpserver = "";
		$R::smptport = "";
		$R::email = "";
		$R::smtpuser = "";
		$R::smtppass = "";
	}

	# Activate new configuration
	
	createtmpconfig();
	installtmpconfig();
	sendtestmail() if (is_enabled($mcfg->{SMTP}->{ACTIVATE_MAIL}));
	cleanuptmpconfig();
		
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
		print to_json(\%response);
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
		$response{message} = "SecurePIN wrong"; #$SL{'SECUREPIN.ERROR_WRONG'};
		$response{error} = 1;
    } elsif ( $checkres and $checkres == 2) {
		$response{message} = "Cannot open SecurePIN file"; # $SL{'SECUREPIN.ERROR_OPEN'};
		$response{error} = 2;
    } elsif ( $checkres and $checkres == 3) {
		$response{message} = "SecurePIN is LOCKED"; # $SL{'SECUREPIN.ERROR_LOCKED'};
		$response{error} = 3;
	} else {
    		$response{message} = "SecurePIN is correct."; # $SL{'SECUREPIN.SUCCESS'};
			$response{error} = 0;
	}

	return $response{error};

}

sub createtmpconfig
{
	
	# my $flock;
	
	# Create temporary SSMTP Config file
	open(F,">/tmp/tempssmtpconf.dat") || die "Cannot open /tmp/tempssmtpconf.dat";
	flock(F,2);
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

}

sub installtmpconfig
{

	require File::Copy;
	
	# Install temporary ssmtp config file
	#my $result = qx($lbhomedir/sbin/createssmtpconf.sh start 2>/dev/null);

	if ( -e "/tmp/tempssmtpconf.dat" and -e "$lbhomedir/system/ssmtp/ssmtp.conf" ) {
		# Backup old file
		File::Copy::move ("$lbhomedir/system/ssmtp/ssmtp.conf", "$lbhomedir/system/ssmtp/ssmtp.conf.bkp");
		chmod 0600, "$lbhomedir/system/ssmtp/ssmtp.conf.bkp";
	}
	
	if ( -e "/tmp/tempssmtpconf.dat" ) {
		# Copy new file
		chmod 0600, "/tmp/tempssmtpconf.dat";
		File::Copy::copy ("/tmp/tempssmtpconf.dat", "$lbhomedir/system/ssmtp/ssmtp.conf");
		chmod 0600, "$lbhomedir/system/ssmtp/ssmtp.conf";
		unlink "/tmp/tempssmtpconf.dat";
	}
		
}

sub restoressmtpconfig
{
	
	require File::Copy;
	
	# ReInstall original ssmtp config file
	# my $result = qx($lbssbindir/createssmtpconf.sh stop 2>/dev/null);

	if ( -e "$lbhomedir/system/ssmtp/ssmtp.conf.bkp" and -e "$lbhomedir/system/ssmtp/ssmtp.conf" ) {
		# Re-Create old file
		File::Copy::move ("$lbhomedir/system/ssmtp/ssmtp.conf.bkp", "$lbhomedir/system/ssmtp/ssmtp.conf");
		chmod 0600, "$lbhomedir/system/ssmtp/ssmtp.conf";
	}
	
}

sub sendtestmail
{

	my $bins = LoxBerry::System::get_binaries();
	$mailbin = $bins->{MAIL};

	
	
	#my $result = qx(echo "$SL{'MAILSERVER.TESTMAIL_CONTENT'}" | $mailbin -a "From: $R::email" -s "$SL{'MAILSERVER.TESTMAIL_SUBJECT'}" -v $R::email 2>&1);

	my $friendlyname = trim(LoxBerry::System::lbfriendlyname());
	my $hostname = LoxBerry::System::lbhostname();
	$friendlyname = defined $friendlyname ? $friendlyname : $hostname;
	$friendlyname .= " LoxBerry";

	require MIME::Base64;

	my $subject = $SL{'MAILSERVER.TESTMAIL_SUBJECT'};
	$subject= "=?utf-8?b?".MIME::Base64::encode($subject, "")."?=";
	my $headerfrom = "From: =?utf-8?b?". MIME::Base64::encode($friendlyname, "") . "?= <" . $R::email . ">";
	my $contenttype = 'Content-Type: text/plain; charset="UTF-8"';
	my $message = $SL{'MAILSERVER.TESTMAIL_CONTENT'};

	# Send test mail
	my $result = qx(echo "$message" | $mailbin -a "$headerfrom" -a "$contenttype" -s "$subject" -v $R::email 2>&1);

	return $result;
	
}

sub cleanuptmpconfig
{
	
	# Delete old temporary config file
	if (-e "/tmp/tempssmtpconf.dat" && -f "/tmp/tempssmtpconf.dat" && !-l "/tmp/tempssmtpconf.dat" && -T "/tmp/tempssmtpconf.dat") {
	  unlink ("/tmp/tempssmtpconf.dat");
	}

}

sub testmail_htmlout
{
	my ($result) = @_; 
	my $lf = 0;
	# Output
	print "Content-type: text/html; charset=utf-8\n\n";

	$result =~ s/\n/<br>/g if (!$lf);
	print '<p>' . $SL{'MAILSERVER.MSG_TEST_INTRO'} . '</p>';
	print '<div style="font-size:80%;  font-family: "Lucida Console", "Lucida Sans Typewriter", monaco, "Bitstream Vera Sans Mono", monospace;">';
	print $result;
	print "</div>";

}


sub testmail_button
{

	%SL = LoxBerry::System::readlanguage();

	createtmpconfig();
	installtmpconfig();
	my $result = sendtestmail();
	testmail_htmlout($result);
	restoressmtpconfig();
	cleanuptmpconfig();	
	exit;
	
}