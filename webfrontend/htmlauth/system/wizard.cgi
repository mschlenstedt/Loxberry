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

use LoxBerry::Web;

use CGI qw/:standard/;
use LWP::UserAgent;
use CGI::Session;
use File::Copy;
use DBI;
use URI::Escape;
#use HTML::Entities;

use warnings;
use strict;

##########################################################################
# Variables
##########################################################################

my $sessiondir = '/tmp';
my %SL;
my $maintemplate;

our $cfg;
our $phrase;
our $namef;
our $value;
our %query;
our $lang;
my  $url;
my  $ua;
my  $response;
our $step;
our $sid;
our $template_title;
our $help;
our @help;
our $helptext;
our $helplink;
our $installfolder;
our $languagefile;
our $session;
our $version;
our $error;
our $saveformdata;
our $checked1;
our $checked2;
our $checked3;
our $checked4;
my $urlstatus;
my $urlstatuscode;
our $adminuser;
our $adminpass1;
our $adminpass2;
our $miniserverip1;
our $miniserverport1;
our $miniserveruser1;
our $miniserverkennwort1;
our $netzwerkanschluss;
our $netzwerkssid;
our $netzwerkschluessel;
our $netzwerkadressen;
our $netzwerkipadresse;
our $netzwerkipmaske;
our $netzwerkgateway;
our $netzwerknameserver;
our @lines;
our $timezonelist;
our $zeitserver;
our $ntpserverurl;
our $zeitzone;
our $rootnewpassword;
our $output;
our $adminpasscrypted;
our $salt;
our $e;
our $loxberrypasswdhtml;
our $rootpasswdhtml;
our $mysqlpasswdhtml;
our $dsn;
our $dbh;
our $sth;
our $sqlerr;
our $useclouddns1;
our $miniservercloudurl1;
our $miniservercloudurlftpport1;
our $curlbin;
our $grepbin;
our $awkbin;
our $miniservernote1;
our $miniserverfoldername1;
our $clouddnsaddress;

my $helplink = "http://www.loxwiki.eu/display/LOXBERRY/LoxBerry";
my $helptemplate = "help_myloxberry.html";
my $template_title;


##########################################################################
# Read Settings
##########################################################################

# Version of this script
$version = "1.0.0.1";

my $sversion = LoxBerry::System::lbversion();
my $lang = lblanguage();

$cfg             = new Config::Simple("$lbsconfigdir/general.cfg");
#$installfolder   = $cfg->param("BASE.INSTALLFOLDER");
#$lang            = $cfg->param("BASE.LANG");
#$clouddnsaddress = $cfg->param("BASE.CLOUDDNS");
#$curlbin         = $cfg->param("BINARIES.CURL");
#$grepbin         = $cfg->param("BINARIES.GREP");
#$awkbin          = $cfg->param("BINARIES.AWK");

#########################################################################
# Parameter
#########################################################################

# Import form parameters to the namespace R
my $cgi = CGI->new;
$cgi->import_names('R');
# Example: Parameter lang is now $R::lang

# # Everything from URL
# foreach (split(/&/,$ENV{'QUERY_STRING'})){
  # ($namef,$value) = split(/=/,$_,2);
  # $namef =~ tr/+/ /;
  # $namef =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/eg;
  # $value =~ tr/+/ /;
  # $value =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/eg;
  # $query{$namef} = $value;
# }

# And this one we really want to use
# $step           = $cgi->url_param("currentstep");
# $sid            = $cgi->url_param("sid");

$step           = $R::currentstep;
$sid            = $R::sid;


print STDERR "Step $step SID $sid\n";

if ($R::btnsubmit) {
	$step++;
} elsif ($R::btnback) {
	$step--;
}
$step = 1 if (! $step || $step < 1);

# Everything from Forms
$saveformdata         				= param('saveformdata');
$adminuser            				= param('adminuser');
$adminpass1           				= param('adminpass1');
$adminpass2           				= param('adminpass2');
$miniserverip1        				= param('miniserverip1');
$miniserverport1      				= param('miniserverport1');
$miniserveruser1      				= uri_escape(param('miniserveruser1'));
$miniserverkennwort1  				= uri_escape(param('miniserverkennwort1'));
$useclouddns1         				= param('useclouddns1');
$miniservercloudurl1  				= param('miniservercloudurl1');
$miniservercloudurlftpport1  			= param('miniservercloudurlftpport1');
$miniservernote1      				= param('miniservernote1');
$miniserverfoldername1      			= param('miniserverfoldername1');
$netzwerkanschluss    				= param('netzwerkanschluss');
$netzwerkssid         				= param('netzwerkssid');
$netzwerkschluessel   				= param('netzwerkschluessel');
$netzwerkadressen     				= param('netzwerkadressen');
$netzwerkipadresse    				= param('netzwerkipadresse');
$netzwerkipmaske      				= param('netzwerkipmaske');
$netzwerkgateway      				= param('netzwerkgateway');
$netzwerknameserver   				= param('netzwerknameserver');
$zeitserver           				= param('zeitserver');
$ntpserverurl         				= param('ntpserverurl');
$zeitzone             				= param('zeitzone');

# $step                  =~ tr/0-9//cd;
# $step                  = substr($step,0,1);
# $saveformdata          =~ tr/0-1//cd;
# $saveformdata          = substr($saveformdata,0,1);
# $sid                   =~ tr/a-z0-9//cd;
# $query{'lang'}         =~ tr/a-z//cd;
# $query{'lang'}         =  substr($query{'lang'},0,2);

##########################################################################
# Session
##########################################################################

# Create new Session if none exists, else use existing one
if (!$sid) {
  $session = new CGI::Session("driver:File", undef, {Directory=>$sessiondir});
  $sid = $session->id();
} else {
  $session = new CGI::Session("driver:File", $sid, {Directory=>$sessiondir});
  $sid = $session->id();
}

# Sessions are valid for 24 hour
$session->expire('+24h');    # expire after 24 hour

$session->save_param($cgi);

##########################################################################
# Language Settings
##########################################################################



# # If there's no language phrases file for choosed language, use german as default
# if (!-e "$installfolder/templates/system/$lang/language.dat") {
  # $lang = "de";
# }

# # Read translations / phrases
# $languagefile = "$installfolder/templates/system/$lang/language.dat";
# $phrase = new Config::Simple($languagefile);

##########################################################################
# Main program
##########################################################################

#########################################################################
# What should we do
#########################################################################

# Step 1 or beginning
if ($step eq "1" || !$step) {
  $step = 1;
  &welcome;
  exit;
}

if ($step eq "2") {
   $step = 2;
   &admin;
}

if ($step eq "3") {
   $step = 3;
   &admin_save;
}

if ($step eq "4") {
	$step = 4;
	&nextsteps;
}

# if ($step eq "3") {
  # &step3;
# }

# if ($step eq "4") {
  # &step4;
# }

# if ($step eq "5") {
  # &step5;
# }

# if ($step eq "6") {
  # &step6;
# }

# if ($step eq "7") {
  # &step7;
# }


# On any doubts: Call welcome
&welcome;
exit;

#####################################################
# Step 1 Welcome
# Welcome Message
#####################################################
sub welcome
{
		
	
	inittemplate("wizard/welcome.html");
	
	my @values = LoxBerry::Web::iso_languages(1, 'values');
	my %labels = LoxBerry::Web::iso_languages(1, 'labels');
	my $langselector_popup = $cgi->popup_menu( 
			-name => 'languageselector',
			id => 'languageselector',
			-labels => \%labels,
			#-attributes => \%labels,
			-values => \@values,
			-default => $lang,
		);
	$maintemplate->param('LANGSELECTOR', $langselector_popup);
	
	$template_title = "Step 1 - Welcome to LoxBerry";
	LoxBerry::Web::head($template_title);
	$template_title .= " <span class='hint'>V$sversion</span>";
	LoxBerry::Web::pagestart($template_title, $helplink, $helptemplate);
	
	print $maintemplate->output();
	LoxBerry::Web::lbfooter();
	exit;

}

#####################################################
# Step 2 admin
# User settings
#####################################################
sub admin
{

	$template_title = "Step 2 - Admin Settings";
	
	inittemplate("admin.html");
	$maintemplate->param( 'ERROR', $error);
	my $adminuserold = $ENV{REMOTE_USER};
	$maintemplate->param("ADMINUSEROLD" , $adminuserold);
	
	my $changedcredentials;
	
	# IMMED: SecurePIN does not match
	if (LoxBerry::System::check_securepin("0000")) {
		$changedcredentials = 1;
	}

	# IMMED: Check Password
	$output = qx(sudo $lbhomedir/sbin/credentialshandler.pl checkpasswd loxberry "loxberry");
	my $exitcode  = $? >> 8;
	if ($exitcode == 1) {
		$changedcredentials = 1;
	}
	
	if ($changedcredentials && $R::btnsubmit) {
		$step++;
		$maintemplate->param("STEP" , $step);
		$maintemplate->param("WIZARD_SKIPADMIN" , $changedcredentials);
		$maintemplate->param("FORM" , undef);
	} elsif ($changedcredentials && $R::btnback) {
		$step = 1;
		&welcome;
		exit;
	}
	LoxBerry::Web::head($template_title);
	$template_title .= " <span class='hint'>V$sversion</span>";
	LoxBerry::Web::pagestart($template_title, $helplink, $helptemplate);
	
	print $maintemplate->output();
	LoxBerry::Web::lbfooter();
	exit;



}


#####################################################
# Step 3 Show Passwords
# 
#####################################################
sub admin_save
{

	
	inittemplate("admin.html");
	my $adminuserold = $ENV{REMOTE_USER};
	$maintemplate->param("ADMINUSEROLD" , $adminuserold);
	$maintemplate->param("FORM" , 0);
	$maintemplate->param("SAVE" , 1);
	
	###############################################
	# All THE CREDENTIALS SETTING NEEDS TO BE HERE
	###############################################
	
	# Using session data:
	my $s = $session->dataref();
	print STDERR "Session test: " . $s->{adminuser} . "\n";
	
	##############################################
	# Slightly modified code from admin.cgi
	
	undef $error;
	
	# Validate username
	if ($s->{adminuser} ne $s->{adminuserold}) {
		# Username changed
		$_ = $adminuser;
		if (! m/^([A-Za-z0-9]|_-){3,20}$/) {
			$error = $SL{'ADMIN.MSG_VAL_USERNAME_ERROR'};
		}
	}
	
	# Validate passwords
	if ($s->{adminpass1} || $s->{adminpass2}) {
		$_ = $s->{adminpass1};
		if (! m/^(?=loxberry$)|^(((?=.*[a-zA-Z0-9\-\_\,\.\;\:\!\?\&\(\)\?\+\%\=])(?=.*[A-Z])(?=.*[0-9])(?=.*[a-z])[a-zA-Z0-9\-\_\,\.\;\:\!\?\&\(\)\?\+\%\=]{4,64}$)|^(){0})$/ ) {
			$error = $SL{'ADMIN.MSG_VAL_PASSWORD_ERROR'};
		}
		if ($s->{adminpass1} ne $s->{adminpass2}) {
			$error = $SL{'ADMIN.MSG_VAL_PASSWORD_DIFFERENT'};
		}
	}

	##############################################

	if ($error) {
		# If errors exist, re-load step 2
		&admin;
		exit;
	}
	
	###############################################
	
	my $exitcode;
	
	##
	## User wants to change the password (and maybe also the username):
	##
	if ($s->{adminpass1}) {
		$output = qx(LANG="en_GB.UTF-8" $lbhomedir/sbin/setloxberrypasswd.exp loxberry $s->{adminpass1});
		$exitcode  = $? >> 8;
		if ($exitcode ne 0) {
			print STDERR "setloxberrypasswd.exp adminpassold Exitcode $exitcode\n";
			$error .= " setloxberrypasswd.exp adminpassold Exitcode $exitcode<br>";
			# &error;
			# exit;
		} else {
			$maintemplate->param("ADMINOK", 1);
		}	

		# Try to set new SAMBA passwords for user "loxberry"

		## If default password isn't valid anymore:
		$output = qx(LANG="en_GB.UTF-8" $lbhomedir/sbin/setloxberrypasswdsmb.exp loxberry $s->{adminpass1} );
		$exitcode  = $? >> 8;
		if ($exitcode ne 0) {
			print STDERR "setloxberrypasswdsmb.exp adminpassold Exitcode $exitcode\n";
			$error .= " setloxberrypasswdsmb.exp adminpassold Exitcode $exitcode<br>";
		} else {
			$maintemplate->param("SAMBAOK", 1);
		}	

		# Save Username/Password for Webarea
		$output = qx(/usr/bin/htpasswd -c -b $lbhomedir/config/system/htusers.dat $s->{adminuser} $s->{adminpass1} );
		$exitcode  = $? >> 8;
		if ($exitcode != 0) {
			$error .= "htpasswd htusers.dat adminuser adminpass1 Exitcode $exitcode<br>";
			# &error;
		} else {
			$maintemplate->param("WEBOK", 1);
		} 
		
	}

	# Set Secure PIN
	my $securepin1 = 1000 + int(rand(8999));
	$output = qx(sudo $lbhomedir/sbin/credentialshandler.pl changesecurepin 0000 $securepin1);
	$exitcode  = $? >> 8;
		if ($exitcode != 0) {
			$error .= "credentialshandler.pl changesecurepin 0000 $securepin1 Exitcode $exitcode<br>";
		} else {
			$maintemplate->param("SECUREPINOK", 1);
		} 
		
	# Set root password
	my $rootnewpassword = generate();
	$output = qx(LANG="en_GB.UTF-8" $lbhomedir/sbin/setrootpasswd.exp loxberry $rootnewpassword);
	$exitcode  = $? >> 8;
		if ($exitcode != 0) {
			$error .= "setrootpasswd.exp loxberry <password> Exitcode $exitcode<br>";
		} else {
			$maintemplate->param("ROOTPASSOK", 1);
		} 
	
	################################################
	
	my $creditwebadmin;
	my $creditconsole;
	my $creditsecurepin;
	my $creditroot;
	
	
	
	
	if ($maintemplate->param("ADMINOK")) {
		$creditwebadmin = "$SL{'ADMIN.SAVE_OK_WEB_ADMIN_AREA'}\t$s->{adminuser} / $s->{adminpass1}\r\n";
		$creditconsole = "$SL{'ADMIN.SAVE_OK_COL_SSH'}\tloxberry / $s->{adminpass1}\r\n";
		$maintemplate->param( "ADMINPASS", $s->{adminpass1} );
	} else {
		$creditwebadmin = "$SL{'ADMIN.SAVE_OK_WEB_ADMIN_AREA'}\t$s->{adminuser} / loxberry\r\n";
		$creditconsole = "$SL{'ADMIN.SAVE_OK_COL_SSH'}\tloxberry / loxberry\r\n";
		$maintemplate->param( "ADMINPASS", "loxberry" );
	}
	if ($maintemplate->param("SECUREPINOK")) {
		$creditsecurepin = "$SL{'ADMIN.SAVE_OK_COL_SECUREPIN'}\t$securepin1\r\n";
		$maintemplate->param( "SECUREPIN", $securepin1 );
	} else {
		$creditsecurepin = "$SL{'ADMIN.SAVE_OK_COL_SECUREPIN'}\t0000\r\n";
		$maintemplate->param( "SECUREPIN", "0000" );
	}
	if ($maintemplate->param("ROOTPASSOK")) {
		$creditroot = "$SL{'ADMIN.SAVE_OK_ROOT_USER'}\t$rootnewpassword\r\n";
		$maintemplate->param( "ROOTPASS", $rootnewpassword );
	} else {
		$creditroot = "$SL{'ADMIN.SAVE_OK_ROOT_USER'}\tloxberry\r\n";
		$maintemplate->param( "ROOTPASS", "loxberry" );
	}
	
	
	
	my $credentialstxt = "$SL{'ADMIN.SAVE_OK_INFO'}\r\n" .  
		"\r\n" .
		$creditwebadmin .
		$creditconsole .
		$creditsecurepin . 
		$creditroot;

	$credentialstxt=encode_base64($credentialstxt);

	$maintemplate->param( "ADMINUSER", $adminuser );
	$maintemplate->param( "CREDENTIALSTXT", $credentialstxt);
	
	$maintemplate->param( "ERRORS", $error);
	$maintemplate->param( "NEXTURL", "/admin/system/index.cgi?form=system");

	$template_title = $SL{'COMMON.LOXBERRY_MAIN_TITLE'} . ": " . $SL{'ADMIN.WIDGETLABEL'};
	
	
	###############################################
	
	$template_title = "Step 3 - Archive your credentials";
	LoxBerry::Web::head($template_title);
	$template_title .= " <span class='hint'>V$sversion</span>";
	LoxBerry::Web::pagestart($template_title, $helplink, $helptemplate);
	print $maintemplate->output();
	LoxBerry::Web::lbfooter();
	exit;

}


#####################################################
# Step 4 Next steps and donate
# 
#####################################################
sub nextsteps
{
		
	
	inittemplate("wizard/finish.html");
	
	$template_title = "Step 4 - What next";
	LoxBerry::Web::head($template_title);
	$template_title .= " <span class='hint'>V$sversion</span>";
	LoxBerry::Web::pagestart($template_title, $helplink, $helptemplate);
	print $maintemplate->output();
	LoxBerry::Web::lbfooter();
	exit;

}

# #####################################################
# # Step 0
# # Welcome Message
# #####################################################

# sub step0 {

# $step++;

# print "Content-Type: text/html\n\n";

# $template_title = $phrase->param("TXT0000") . " - " . $phrase->param("TXT0017");
# $help = "setup00";

# # Print Template
# &lbheader;
# open(F,"$installfolder/templates/system/$lang/setup/setup.step00.html") || die "Missing template system/$lang/setup/setup.step00.html";
  # while (<F>) {
    # $_ =~ s/<!--\$(.*?)-->/${$1}/g;
    # print $_;
  # }
# close(F);
# &footer;

# exit;

# }

# #####################################################
# # Step 1
# # Admin Account
# #####################################################

# sub step1 {

# # Store submitted data in session file
# # Nothing todo here (first form)

# # Read data from Session file
# $adminuser   = $session->param("adminuser");
# $adminpass1  = $session->param("adminpass1");
# $adminpass2  = $session->param("adminpass1");

# # Filter
# quotemeta($adminuser);
# quotemeta($adminpass1);
# quotemeta($adminpass2);

# $step++;

# print "Content-Type: text/html\n\n";

# $template_title = $phrase->param("TXT0000") . " - " . $phrase->param("TXT0017") . ": " . $phrase->param("TXT0018");
# $help = "setup01";

# # Print Template
# &lbheader;
# open(F,"$installfolder/templates/system/$lang/setup/setup.step01.html") || die "Missing template system/$lang/asistant/setup.step01.html";
  # while (<F>) {
    # $_ =~ s/<!--\$(.*?)-->/${$1}/g;
    # print $_;
  # }
# close(F);
# &footer;

# exit;

# }

# #####################################################
# # Step 2
# # Miniserver
# #####################################################

# sub step2 {

# # Store submitted data in session file
# if ($saveformdata) {
  # $session->param("adminuser", $adminuser);
  # $session->param("adminpass1", $adminpass1);
# }

# # Read data from Session file
# $miniserverip1       				= $session->param("miniserverip1");
# $miniserverport1     				= $session->param("miniserverport1");
# $miniserveruser1     				= uri_unescape($session->param("miniserveruser1"));
# $miniserverkennwort1 				= uri_unescape($session->param("miniserverkennwort1"));
# $useclouddns1        				= $session->param("useclouddns1");
# $miniservercloudurl1 				= $session->param("miniservercloudurl1");
# $miniservercloudurlftpport1 		= $session->param("miniservercloudurlftpport1");
# $miniservernote1     				= $session->param("miniservernote1");
# $miniserverfoldername1  			= $session->param("miniserverfoldername1");

# # Filter
# quotemeta($miniserverip1);
# quotemeta($miniserverport1);
# quotemeta($miniserveruser1);
# quotemeta($miniserverkennwort1);
# quotemeta($useclouddns1);
# quotemeta($miniservercloudurl1);
# quotemeta($miniservercloudurlftpport1);
# quotemeta($miniservernote1);
# quotemeta($miniserverfoldername1);

# # Default values
# if (!$miniserverport1) {$miniserverport1 = "80";}

# $step++;

# print "Content-Type: text/html\n\n";

# $template_title = $phrase->param("TXT0000") . " - " . $phrase->param("TXT0017") . ": " . $phrase->param("TXT0019");
# $help = "setup02";

# # Print Template
# &lbheader;
# open(F,"$installfolder/templates/system/$lang/setup/setup.step02.html") || die "Missing template system/$lang/setup/setup.step02.html";
  # while (<F>) {
    # $_ =~ s/<!--\$(.*?)-->/${$1}/g;
    # print $_;
  # }
# close(F);
# &footer;

# exit;

# }

# #####################################################
# # Step 3
# # Netzwerk
# #####################################################

# sub step3 {

# # Store submitted data in session file
# if ($saveformdata) {
  
  # $miniserveruser1 = uri_escape($miniserveruser1);
  # $miniserverkennwort1 = uri_escape($miniserverkennwort1);
  
  # $session->param("miniserverip1", $miniserverip1);
  # $session->param("miniserverport1", $miniserverport1);
  # $session->param("miniserveruser1", $miniserveruser1);
  # $session->param("miniserverkennwort1", $miniserverkennwort1);
  # $session->param("useclouddns1", $useclouddns1);
  # $session->param("miniservercloudurl1", $miniservercloudurl1);
  # $session->param("miniservercloudurlftpport1", $miniservercloudurlftpport1);
  # $session->param("miniservernote1", $miniservernote1);
  # $session->param("miniserverfoldername1", $miniserverfoldername1);

 
  
  # # Test if Miniserver is reachable
  # if ( $useclouddns1 eq "on" || $useclouddns1 eq "checked" || $useclouddns1 eq "true" || $useclouddns1 eq "1" )
  # {
   # $useclouddns1 = "1";
   # our $dns_info = `$curlbin -I http://$clouddnsaddress/$miniservercloudurl1 --connect-timeout 5 -m 5 2>/dev/null |$grepbin Location |$awkbin -F/ '{print \$3}'`;
   # my @dns_info_pieces = split /:/, $dns_info;
   # if ($dns_info_pieces[1])
   # {
    # $dns_info_pieces[1] =~ s/^\s+|\s+$//g;
   # }
   # else
   # {
    # $dns_info_pieces[1] = 80;
   # }
   # if ($dns_info_pieces[0])
   # {
    # $dns_info_pieces[0] =~ s/^\s+|\s+$//g;
   # }
   # else
   # {
    # $dns_info_pieces[0] = "[DNS-Error]"; 
   # }
  # $url = "http://$miniserveruser1:$miniserverkennwort1\@$dns_info_pieces[0]\:$dns_info_pieces[1]/dev/cfg/version";
  # }
  # else
  # {
  # $url = "http://$miniserveruser1:$miniserverkennwort1\@$miniserverip1\:$miniserverport1/dev/cfg/version";
  # }
  # $ua = LWP::UserAgent->new;
  # $ua->timeout(1);
  # local $SIG{ALRM} = sub { die };
  # eval {
    # alarm(1);
    # $response = $ua->get($url);
    # $urlstatus = $response->status_line;
  # };
  # alarm(0);

  # # Error if we can't login
  # $urlstatuscode = substr($urlstatus,0,3);
  # if ($urlstatuscode ne "200") {
    # $error = $phrase->param("TXT0003");
    # &error;
    # exit;
  # }

# }
  
# # Read data from Session file
# $netzwerkanschluss  = $session->param("netzwerkanschluss");
# $netzwerkssid       = $session->param("netzwerkssid");
# $netzwerkschluessel = $session->param("netzwerkschluessel");
# $netzwerkadressen   = $session->param("netzwerkadressen");
# $netzwerkipadresse  = $session->param("netzwerkipadresse");
# $netzwerkipmaske    = $session->param("netzwerkipmaske");
# $netzwerkgateway    = $session->param("netzwerkgateway");
# $netzwerknameserver = $session->param("netzwerknameserver");

# # Filter
# quotemeta($netzwerkanschluss);
# quotemeta($netzwerkssid);
# quotemeta($netzwerkschluessel);
# quotemeta($netzwerkadressen);
# quotemeta($netzwerkipadresse);
# quotemeta($netzwerkipmaske);
# quotemeta($netzwerkgateway); 
# quotemeta($netzwerknameserver);

# # Defaults for template
# if ($netzwerkanschluss eq "wlan0") {
  # $checked2 = "checked\=\"checked\"";
# } else {
  # $checked1 = "checked\=\"checked\"";
# }

# if ($netzwerkadressen eq "manual") {
  # $checked4 = "checked\=\"checked\"";
# } else {
  # $checked3 = "checked\=\"checked\"";
# }

# $step++;

# print "Content-Type: text/html\n\n";

# $template_title = $phrase->param("TXT0000") . " - " . $phrase->param("TXT0017") . ": " . $phrase->param("TXT0020");
# $help = "setup03";

# # Print Template
# &lbheader;
# open(F,"$installfolder/templates/system/$lang/setup/setup.step03.html") || die "Missing template system/$lang/setup/setup.step03.html";
  # while (<F>) {
    # $_ =~ s/<!--\$(.*?)-->/${$1}/g;
    # print $_;
  # }
# close(F);
# &footer;

# exit;

# }

# #####################################################
# # Step 4
# # Timeserver
# #####################################################

# sub step4 {

# # Store submitted data in session file
# if ($saveformdata) {
   # $session->param("netzwerkanschluss", $netzwerkanschluss);
   # $session->param("netzwerkssid", $netzwerkssid);
   # $session->param("netzwerkschluessel", $netzwerkschluessel);
   # $session->param("netzwerkadressen", $netzwerkadressen);
   # $session->param("netzwerkipadresse", $netzwerkipadresse);
   # $session->param("netzwerkipmaske", $netzwerkipmaske);
   # $session->param("netzwerkgateway", $netzwerkgateway);
   # $session->param("netzwerknameserver", $netzwerknameserver);
# }
  
# # Read data from Session file
# $zeitserver   = $session->param("zeitserver");
# $ntpserverurl = $session->param("ntpserverurl");
# $zeitzone     = $session->param("zeitzone");

# # Filter
# quotemeta($zeitserver);
# quotemeta($ntpserverurl);
# quotemeta($zeitzone);

# # Defaults for template
# if ($zeitserver eq "ntp") {
  # $checked2 = "checked\=\"checked\"";
# } else {
  # $checked1 = "checked\=\"checked\"";
# }

# $step++;

# # Prepare Timezones
# open(F,"<$installfolder/templates/system/timezones.dat") || die "Missing template system/timezones.dat";
 # flock(F,2);
 # @lines = <F>;
 # flock(F,8);
# close(F);
# foreach (@lines){
  # s/[\n\r]//g;
  # if ($zeitzone eq $_) {
    # $timezonelist = "$timezonelist<option selected=\"selected\" value=\"$_\">$_</option>\n";
  # } else {
    # $timezonelist = "$timezonelist<option value=\"$_\">$_</option>\n";
  # }
# }

# print "Content-Type: text/html\n\n";
# $template_title = $phrase->param("TXT0000") . " - " . $phrase->param("TXT0017") . ": " . $phrase->param("TXT0021");
# $help = "setup04";

# # Print Template
# &lbheader;
# open(F,"$installfolder/templates/system/$lang/setup/setup.step04.html") || die "Missing template system/$lang/setup/setup.step04.html";
  # while (<F>) {
    # $_ =~ s/<!--\$(.*?)-->/${$1}/g;
    # print $_;
  # }
# close(F);
# &footer;

# exit;

# }

# #####################################################
# # Step 5
# # Pre-Installation
# #####################################################

# sub step5 {

# # Store submitted data in session file
# if ($saveformdata) {
   # $session->param("zeitserver", $zeitserver);
   # $session->param("ntpserverurl", $ntpserverurl);
   # $session->param("zeitzone", $zeitzone);
# }
  
# $step++;

# print "Content-Type: text/html\n\n";
# $template_title = $phrase->param("TXT0000") . " - " . $phrase->param("TXT0017") . ": " . $phrase->param("TXT0022");
# $help = "setup05";

# # Print Template
# &lbheader;
# open(F,"$installfolder/templates/system/$lang/setup/setup.step05.html") || die "Missing template system/$lang/setup/setup.step05.html";
  # while (<F>) {
    # $_ =~ s/<!--\$(.*?)-->/${$1}/g;
    # print $_;
  # }
# close(F);
# &footer;

# exit;

# }

# #####################################################
# # Step 6
# # Do Installation
# #####################################################

# sub step6 {

# # Read data from Session file
# $adminuser           				= $session->param("adminuser");
# $adminpass1          				= $session->param("adminpass1");
# $adminpass2          				= $session->param("adminpass1");
# $miniserverip1       				= $session->param("miniserverip1");
# $miniserverport1     				= $session->param("miniserverport1");
# $miniserveruser1     				= $session->param("miniserveruser1");
# $miniserverkennwort1 				= $session->param("miniserverkennwort1");
# $miniservernote1     				= $session->param("miniservernote1");
# $miniserverfoldername1   			= $session->param("miniserverfoldername1");
# $miniservercloudurl1 				= $session->param("miniservercloudurl1");
# $miniservercloudurlftpport1 			= $session->param("miniservercloudurlftpport1");
# $useclouddns1        				= $session->param("useclouddns1");
# $netzwerkanschluss   				= $session->param("netzwerkanschluss");
# $netzwerkssid        				= $session->param("netzwerkssid");
# $netzwerkschluessel  				= $session->param("netzwerkschluessel");
# $netzwerkadressen    				= $session->param("netzwerkadressen");
# $netzwerkipadresse   				= $session->param("netzwerkipadresse");
# $netzwerkipmaske     				= $session->param("netzwerkipmaske");
# $netzwerkgateway     				= $session->param("netzwerkgateway");
# $netzwerknameserver  				= $session->param("netzwerknameserver");
# $zeitserver          				= $session->param("zeitserver");
# $ntpserverurl        				= $session->param("ntpserverurl");
# $zeitzone            				= $session->param("zeitzone");

# # Filter
# quotemeta($adminuser);
# quotemeta($adminpass1);
# quotemeta($adminpass2);
# quotemeta($miniserverip1);
# quotemeta($miniserverport1);
# quotemeta($miniserveruser1);
# quotemeta($miniserverkennwort1);
# quotemeta($miniservernote1);
# quotemeta($miniserverfoldername1);
# quotemeta($miniservercloudurl1);
# quotemeta($miniservercloudurlftpport1);
# quotemeta($useclouddns1);
# quotemeta($netzwerkanschluss);
# quotemeta($netzwerkssid);
# quotemeta($netzwerkschluessel);
# quotemeta($netzwerkadressen);
# quotemeta($netzwerkipadresse);
# quotemeta($netzwerkipmaske);
# quotemeta($netzwerkgateway); 
# quotemeta($netzwerknameserver);
# quotemeta($zeitserver);
# quotemeta($ntpserverurl);
# quotemeta($zeitzone);

# # Clean Vars
# if (!$useclouddns1) {
  # $useclouddns1 = "0";
# } else {
  # $useclouddns1 = "1";
# }

# $step++;

# # Write configuration file(s)
# $cfg->param("BASE.STARTSETUP", "0");
# $cfg->param("BASE.LANG", "$lang");
# $cfg->param("BASE.MINISERVERS", "1");
# $cfg->param("MINISERVER1.PORT", "$miniserverport1");
# $cfg->param("MINISERVER1.PASS", "$miniserverkennwort1");
# $cfg->param("MINISERVER1.ADMIN", "$miniserveruser1");
# $cfg->param("MINISERVER1.IPADDRESS", "$miniserverip1");
# $cfg->param("MINISERVER1.USECLOUDDNS", "$useclouddns1");
# $cfg->param("MINISERVER1.NOTE", "$miniservernote1");
# $cfg->param("MINISERVER1.NAME", "$miniserverfoldername1");
# $cfg->param("MINISERVER1.CLOUDURL", "$miniservercloudurl1");
# $cfg->param("MINISERVER1.CLOUDURLFTPPORT", "$miniservercloudurlftpport1");
# $cfg->param("TIMESERVER.SERVER", "$ntpserverurl");
# $cfg->param("TIMESERVER.METHOD", "$zeitserver");
# $cfg->param("TIMESERVER.ZONE", "$zeitzone");
# $cfg->param("NETWORK.INTERFACE", "$netzwerkanschluss");
# $cfg->param("NETWORK.SSID", "$netzwerkssid");
# $cfg->param("NETWORK.TYPE", "$netzwerkadressen");
# $cfg->param("NETWORK.IPADDRESS", "$netzwerkipadresse");
# $cfg->param("NETWORK.MASK", "$netzwerkipmaske");
# $cfg->param("NETWORK.GATEWAY", "$netzwerkgateway");
# $cfg->param("NETWORK.DNS", "$netzwerknameserver");
# $cfg->save();

# # Save Username/Password for Webarea
# $adminpasscrypted = qx(/usr/bin/htpasswd -n -b -B -C 5 $adminuser $adminpass1);
# open(F,">$installfolder/config/system/htusers.dat.new") || die "Missing file: config/system/htusers.dat.new";
 # flock(F,2);
 # print F "$adminpasscrypted";
 # flock(F,8);
# close(F);

# # Try to set new passwords for user "root" and "loxberry"
# # This only works if the initial password is still valid
# # (password: "loxberry")

# # Root
# $rootnewpassword = generate();
# $output = qx(LANG="en_GB.UTF-8" $installfolder/sbin/setrootpasswd.exp loxberry $rootnewpassword);
# if ($? eq 0) {
  # $rootpasswdhtml = "<tr><td><b>" . $phrase->param("TXT0026") . "</b></td><td>" . $phrase->param("TXT0023") . " <b>root</b></td><td>" . $phrase->param("TXT0024") . " <b>$rootnewpassword</b></td></tr>";
# }

# # Loxberry UNIX
# $output = qx(LANG="en_GB.UTF-8" $installfolder/sbin/setloxberrypasswd.exp loxberry $adminpass1);
# if ($? eq 0) {
  # $loxberrypasswdhtml = "<tr><td><b>" . $phrase->param("TXT0025") . "</b></td><td>" . $phrase->param("TXT0023") . " <b>loxberry</b></td><td>" . $phrase->param("TXT0024") . " <b>$adminpass1</b></td></tr>";
# }

# # Loxberry SAMBA
# $output = qx(LANG="en_GB.UTF-8" $installfolder/sbin/setloxberrypasswdsmb.exp loxberry $adminpass1);

# # Set MYSQL Password
# # This only works if the initial password is still valid
# # (password: "loxberry")
# # Use eval {} here in case somthing went wrong
# $sqlerr = 0;
# $dsn = "DBI:mysql:database=mysql";
# eval {$dbh = DBI->connect($dsn, 'root', 'loxberry' )};
# $sqlerr = 1 if $@;
# eval {$sth = $dbh->prepare("UPDATE mysql.user SET password=Password('$adminpass1') WHERE User='root' AND Host='localhost'")};
# $sqlerr = 1 if $@;
# eval {$sth->execute()};
# $sqlerr = 1 if $@;
# eval {$sth = $dbh->prepare("FLUSH PRIVILEGES")};
# $sqlerr = 1 if $@;
# eval {$sth->execute()};
# $sqlerr = 1 if $@;
# eval {$sth->finish()};
# $sqlerr = 1 if $@;
# eval {$dbh->{AutoCommit} = 0};
# $sqlerr = 1 if $@;
# eval {$dbh->commit};
# $sqlerr = 1 if $@;
# if ($sqlerr eq 0) {
  # $mysqlpasswdhtml = "<tr><td><b>" . $phrase->param("TXT0042") . "</b></td><td>" . $phrase->param("TXT0023") . " <b>root</b></td><td>" . $phrase->param("TXT0024") . " <b>$adminpass1</b></td></tr>";
# }


# # Set Timezone and sync for the very first time
# $output = qx(sudo $installfolder/sbin/setdatetime.pl);

# # Set network options
# # Wireless
# if ($netzwerkanschluss eq "wlan0") {

  # # Manual / Static
  # if ($netzwerkadressen eq "manual") {
    # open(F1,"$installfolder/system/network/interfaces.wlan_static") || die "Missing file: $installfolder/system/network/interfaces.wlan_static";
     # open(F2,">$installfolder/system/network/interfaces") || die "Missing file: $installfolder/system/network/interfaces";
      # flock(F2,2);
      # while (<F1>) {
        # $_ =~ s/<!--\$(.*?)-->/${$1}/g;
        # print F2 $_;
      # }
      # flock(F2,8);
     # close(F2);
    # close(F1);

  # # DHCP
  # } else {
    # open(F1,"$installfolder/system/network/interfaces.wlan_dhcp") || die "Missing file: $installfolder/system/network/interfaces.wlan_dhcp";
     # open(F2,">$installfolder/system/network/interfaces") || die "Missing file: $installfolder/system/network/interfaces";
      # flock(F2,2);
      # while (<F1>) {
        # $_ =~ s/<!--\$(.*?)-->/${$1}/g;
        # print F2 $_;
      # }
      # flock(F2,8);
     # close(F2);
    # close(F1);
  # }

# # Ethernet
# } else {

  # # Manual / Static
  # if ($netzwerkadressen eq "manual") {
    # open(F1,"$installfolder/system/network/interfaces.eth_static") || die "Missing file: $installfolder/system/network/interfaces.eth_static";
     # open(F2,">$installfolder/system/network/interfaces") || die "Missing file: $installfolder/system/network/interfaces";
      # flock(F2,2);
      # while (<F1>) {
        # $_ =~ s/<!--\$(.*?)-->/${$1}/g;
        # print F2 $_;
      # }
      # flock(F2,8);
     # close(F2);
    # close(F1);

  # # DHCP
  # } else {
    # open(F1,"$installfolder/system/network/interfaces.eth_dhcp") || die "Missing file: $installfolder/system/network/interfaces.eth_dhcp";
     # open(F2,">$installfolder/system/network/interfaces") || die "Missing file: $installfolder/system/network/interfaces";
      # flock(F2,2);
      # while (<F1>) {
        # $_ =~ s/<!--\$(.*?)-->/${$1}/g;
        # print F2 $_;
      # }
      # flock(F2,8);
     # close(F2);
    # close(F1);
  # }
# }

# print "Content-Type: text/html\n\n";
# $template_title = $phrase->param("TXT0000") . " - " . $phrase->param("TXT0017") . ": " . $phrase->param("TXT0022");
# $help = "setup06";

# # Print Template
# &lbheader;
# open(F,"$installfolder/templates/system/$lang/setup/setup.step06.html") || die "Missing template system/$lang/setup/setup.step06.html";
  # while (<F>) {
    # $_ =~ s/<!--\$(.*?)-->/${$1}/g;
    # print $_;
  # }
# close(F);
# &footer;

# exit;

# }



exit;


#####################################################
# 
# Subroutines
#
#####################################################

#####################################################
# Init template
#####################################################
sub inittemplate
{
	my ($templname) = @_;
	$maintemplate = HTML::Template->new(
				filename => "$lbstemplatedir/$templname",
				global_vars => 1,
				loop_context_vars => 1,
				die_on_bad_params=> 0,
				associate => $session,
				);

	%SL = LoxBerry::System::readlanguage($maintemplate);
	
	my $selfurl = $cgi->self_url;
	my $querypos = index($selfurl, '?');
	$selfurl = substr($selfurl, 0, $querypos) if ($querypos != -1);
	print STDERR "selfurl: $selfurl\n";
	
	$maintemplate->param( 'WIZARD', 1);
	$maintemplate->param( 'STEP', $step );
	$maintemplate->param( 'PREVSTEPNR', $step-1 );
	$maintemplate->param( 'NEXTSTEPNR', $step+1 );
	$maintemplate->param( 'SID', $sid );
	$maintemplate->param( 'SELFURL', $selfurl );
	$maintemplate->param( 'LANG', lblanguage() );
	$maintemplate->param( 'FORM', 1 );
	$maintemplate->param( 'VERSION', LoxBerry::System::lbversion());

}

#####################################################
# Error
#####################################################

sub error {

$template_title = $phrase->param("TXT0000") . " - " . $phrase->param("TXT0028");
$help = "setup00";

print "Content-Type: text/html\n\n";

&lbheader;
open(F,"$installfolder/templates/system/$lang/error.html") || die "Missing template system/$lang/error.html";
    while (<F>) {
      $_ =~ s/<!--\$(.*?)-->/${$1}/g;
      print $_;
    }
close(F);
&footer;

exit;

}

#####################################################
# Header
#####################################################

sub lbheader {

  # create help page
  $helplink = "http://www.loxwiki.eu:80/x/o4CO";
  open(F,"$installfolder/templates/system/$lang/help/$help.html") || die "Missing template system/$lang/help/$help.html";
    @help = <F>;
    foreach (@help){
      s/[\n\r]/ /g;
      $helptext = $helptext . $_;
    }
  close(F);

  open(F,"$installfolder/templates/system/$lang/header.html") || die "Missing template system/$lang/header.html";
    while (<F>) {
      $_ =~ s/<!--\$(.*?)-->/${$1}/g;
      print $_;
    }
  close(F);

}

#####################################################
# Footer
#####################################################

sub footer {

  open(F,"$installfolder/templates/system/$lang/footer.html") || die "Missing template system/$lang/footer.html";
    while (<F>) {
      $_ =~ s/<!--\$(.*?)-->/${$1}/g;
      print $_;
    }
  close(F);

}

#####################################################
# Random
#####################################################

sub generate {
        local($e) = @_;
        my($zufall,@words,$more);

        if($e =~ /^\d+$/){
                $more = $e;
        }else{
                $more = "10";
        }

        @words = qw(A B C D E F G H I J K L M N O P Q R S T U V W X Y Z a b c d e f g h i j k l m n o p q r s t u v w x y z 0 1 2 3 4 5 6 7 8 9);

        foreach (1..$more){
                $zufall .= $words[int rand($#words+1)];
        }

        return($zufall);
}
