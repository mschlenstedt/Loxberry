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
my $version = "1.5.0.3";
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
	my $msmtprcfile = $lbhomedir . "/system/msmtp/msmtprc";
	
	# %SL = LoxBerry::System::readlanguage();
	$mailobj = LoxBerry::JSON->new();
	$mcfg = $mailobj->open(filename => $mailfile);
	
	# Read msmtp config
	my @msmtprckeys;
	if (-e $msmtprcfile) {
		open(my $fh, '<', $msmtprcfile);
		while (<$fh>) {
			chomp;                  # no newline
			s/#.*//;                # no comments
			s/^\s+//;               # no leading white
			s/\s+$//;               # no trailing white
			next unless length;     # anything left?
			my ($var, $value) = split(/\s+/, $_, 2);
			$var = uc ($var); # UPPERCASE
			push (@msmtprckeys, $var);
			$mcfg->{SMTP}->{$var} = $value;
			print STDERR "Read config: $var: $mcfg->{SMTP}->{$var}\n";
		} 
	}
	
	if($key eq "getmailcfg") {
		my $resp = checksecpin($val);
		if($resp == 0) {
			$response{error} = 0;
			$response{customresponse} = 1;
			$response{output} = to_json($mcfg);
		}
	} 

	elsif($key eq "setmailcfg") {
		eval { 
			save();
		};
		if ($@) {
			$response{error} = 1;
			$response{message} = "Error: $@";
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
	
	# Clear hash and safe only values who should be safed in LB config
	delete $mcfg->{SMTP};
	$mcfg->{SMTP}->{ACTIVATE_MAIL} = is_enabled($R::activate_mail) ? 1 : 0;
	$mcfg->{SMTP}->{ISCONFIGURED} = $mcfg->{SMTP}->{ACTIVATE_MAIL};
#	$mcfg->{SMTP}->{AUTH} = is_enabled($R::smtpauth) ? 1 : 0;
#	$mcfg->{SMTP}->{CRYPT} = is_enabled($R::smtpcrypt) ? 1 : 0;
#	$mcfg->{SMTP}->{SMTPSERVER} = $R::smtpserver;
#	$mcfg->{SMTP}->{PORT} = $R::smtpport;
	$mcfg->{SMTP}->{EMAIL} = $R::email;
#	$mcfg->{SMTP}->{SMTPUSER} = $R::smtpuser;
#	$mcfg->{SMTP}->{SMTPPASS} = $R::smtppass;
	
	# Validy check
	if($mcfg->{SMTP}->{ACTIVATE_MAIL}) {
		die("Email address missing\n") if (!$R::email);
		die("SMTP Server missing\n") if (!$R::smtpserver);
		die("SMTP Port missing\n") if (!$R::smtpport);
		if(is_enabled($R::smtpauth)) {
			die("SMTP User missing\n") if (!$R::smtpuser);
			die("SMTP Password missing\n") if (!$R::smtppass);
		}
	}
	
	$mailobj->write();
	
	# Delete values if email is disabled
	if (! $mcfg->{SMTP}->{ACTIVATE_MAIL}) {
		system( "sudo $lbhomedir/sbin/setmail disable > /dev/null 2>&1" );
		unlink ("$lbhomedir/system/msmtp/msmtprc") or die();
		$R::smtpserver = "";
		$R::smptport = "";
		$R::email = "";
		$R::smtpuser = "";
		$R::smtppass = "";
	# Activate new configuration
	} else {
		createtmpconfig();
		installtmpconfig();
		sendtestmail() if (is_enabled($mcfg->{SMTP}->{ACTIVATE_MAIL}));
		cleanuptmpconfig();
		system( "sudo $lbhomedir/sbin/setmail enable > /dev/null 2>&1" );
		open(F,">$lbhomedir/system/msmtp/aliases");
		flock(F,2);
		print F "root: $R::email\n";
		print F "loxberry: $R::email\n";
		print F "default: $R::email\n";
		flock(F,8);
		close(F);
	}

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
	
	# Create temporary SSMTP Config file
	open(F,">/tmp/tempmsmtprc.dat") || die "Cannot open /tmp/tempmsmtprc.dat";
	flock(F,2);
	#print F "root=$R::email\n\n";
	print F "aliases $lbhomedir/system/msmtp/aliases\n";
	print F "logfile $lbhomedir/log/system_tmpfs/mail.log\n";
	print F "from $R::email\n";
	print F "host $R::smtpserver\n";
	print F "port $R::smtpport\n";

	if ($R::smtpauth) {
		print F "auth on\n";
		print F "user $R::smtpuser\n";
		print F "password $R::smtppass\n";
	} else {
		print F "auth off\n";
	}

	if ($R::smtpcrypt) {
		print F "tls on\n";
		print F "tls_trust_file /etc/ssl/certs/ca-certificates.crt\n"
	} else {
		print F "tls off\n";
	}
	flock(F,8);
	close(F);

}

sub installtmpconfig
{

	require File::Copy;
	
	# Install temporary ssmtp config file
	#my $result = qx($lbhomedir/sbin/createssmtpconf.sh start 2>/dev/null);

	if ( -e "/tmp/tempmsmtprc.dat" and -e "$lbhomedir/system/msmtp/msmtprc" ) {
		# Backup old file
		File::Copy::move ("$lbhomedir/system/msmtp/msmtprc", "$lbhomedir/system/msmtp/msmtprc.bkp");
		chmod 0600, "$lbhomedir/system/msmtp/msmtprc.bkp";
	}
	
	if ( -e "/tmp/tempmsmtprc.dat" ) {
		# Copy new file
		chmod 0600, "/tmp/tempmsmtprc.dat";
		File::Copy::copy ("/tmp/tempmsmtprc.dat", "$lbhomedir/system/msmtp/msmtprc");
		chmod 0600, "$lbhomedir/system/msmtp/msmtprc";
		unlink "/tmp/tempmsmtprc.dat";
		system( "sudo $lbhomedir/sbin/setmail enable > /dev/null 2>&1" );
	}
		
}

sub restoressmtpconfig
{
	
	require File::Copy;
	
	# ReInstall original ssmtp config file
	# my $result = qx($lbssbindir/createssmtpconf.sh stop 2>/dev/null);

	if ( -e "$lbhomedir/system/msmtp/msmtprc.bkp" and -e "$lbhomedir/system/msmtp/msmtprc" ) {
		# Re-Create old file
		File::Copy::move ("$lbhomedir/system/msmtp/msmtprc.bkp", "$lbhomedir/system/msmtp/msmtprc");
		chmod 0600, "$lbhomedir/system/msmtp/msmtprc";
	}

	my $mailfile = $lbsconfigdir . "/mail.json";
	
	$mailobj = LoxBerry::JSON->new();
	$mcfg = $mailobj->open(filename => $mailfile);

	if (!$mcfg->{SMTP}->{ACTIVATE_MAIL}) {
		system( "sudo $lbhomedir/sbin/setmail disable > /dev/null 2>&1" );
		unlink ( "$lbhomedir/system/msmtp/msmtprc" );
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
	if (-e "/tmp/tempmsmtprc.dat" && -f "/tmp/tempmsmtprc.dat" && !-l "/tmp/tempmsmtprc.dat" && -T "/tmp/tempmsmtprc.dat") {
		unlink ("/tmp/tempmsmtprc.dat");
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
