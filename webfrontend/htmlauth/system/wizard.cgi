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
use MIME::Base64;

#use HTML::Entities;

use warnings;
use strict;

##########################################################################
# Variables
##########################################################################

my $sessiondir = '/tmp';
my %SL;
my $maintemplate;

my $step;
my $sid;
my $session;
my $error;

my $helplink = "http://www.loxwiki.eu/display/LOXBERRY/LoxBerry";
my $helptemplate = "help_myloxberry.html";
my $template_title;


##########################################################################
# Read Settings
##########################################################################

# Version of this script
my $version = "1.0.0.2";

my $sversion = LoxBerry::System::lbversion();
my $lang = lblanguage();

# $cfg = new Config::Simple("$lbsconfigdir/general.cfg");

##########################################################################
# Create file to indicate that wizard was executed
##########################################################################

my $wizardfile = "$lbsdatadir/wizard.dat";
if (! -e $wizardfile) {
	open(my $fh, '>', $wizardfile);
	print $fh "Wizard started at " . currtime() . "\n";
	close $fh;
}

#########################################################################
# Parameter
#########################################################################

# Import form parameters to the namespace R
my $cgi = CGI->new;
$cgi->import_names('R');
# Example: Parameter lang is now $R::lang

# Avoid warnings 'only used once'
$R::currentstep if (0);
$R::sid if (0);

$step = $R::currentstep;
$sid = $R::sid;

# print STDERR "Step $step SID $sid\n";

if ($R::btnsubmit) {
	$step++;
} elsif ($R::btnback) {
	$step--;
}
$step = 1 if (! $step || $step < 1);

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
	
	$template_title = $SL{'WIZARD.TITLE_STEP1'};
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

	
	inittemplate("admin.html");
	$template_title = $SL{'WIZARD.TITLE_STEP2'};
	
	$maintemplate->param( 'ERROR', $error);
	my $adminuserold = $ENV{REMOTE_USER};
	$maintemplate->param("ADMINUSEROLD" , $adminuserold);
	
	my $changedcredentials;
	my $output;
	
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
	# print STDERR "Session test: " . $s->{adminuser} . "\n";
	
	##############################################
	# Slightly modified code from admin.cgi
	
	undef $error;
	
	# Validate username
	if ($s->{adminuser} ne $s->{adminuserold}) {
		# Username changed
		$_ = $s->{adminuser};
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
	my $adminok;
	my $sambaok;
	my $webok;
	my $securepinok;
	my $rootpassok;
	my $output;
	our $wraperror = 0;	
	##
	## User wants to change the password (and maybe also the username):
	##
#	print STDERR "adminuser: " . $s->{adminuser} . "\n";
#	print STDERR "adminpass1: " . $s->{adminpass1} . "\n";
	
	if ($s->{adminpass1}) {
		$output = qx(LANG="en_GB.UTF-8" $lbhomedir/sbin/setloxberrypasswd.exp loxberry $s->{adminpass1});
		$exitcode  = $? >> 8;
		if ($exitcode eq 1) {
			print STDERR "setloxberrypasswd.exp".$SL{'ADMIN.SAVE_ERR_PASS_IDENTICAL'}."\n";
			$error .= $SL{'ADMIN.SAVE_ERR_PASS_IDENTICAL'}."<br>";
			# &error;
			# exit;
		}
		elsif ($exitcode eq 2) {
			print STDERR "setloxberrypasswd.exp".$SL{'ADMIN.SAVE_ERR_PASS_WRAPPED'}."\n";
			$error .= $SL{'ADMIN.SAVE_ERR_PASS_WRAPPED'}."<br>";
			$wraperror = 1;
			# &error;
			# exit;
		}
		elsif ($exitcode ne 0) {
			print STDERR "setloxberrypasswd.exp adminpassold Exitcode $exitcode\n";
			$error .= " setloxberrypasswd.exp adminpassold Exitcode $exitcode<br>";
			# &error;
			# exit;
		} else {
			$maintemplate->param("ADMINOK", 1);
			$adminok = 1;
		}	

		if ($wraperror ne 1) {
		
			# Try to set new SAMBA passwords for user "loxberry"
	
			## If default password isn't valid anymore:
			$output = qx(LANG="en_GB.UTF-8" $lbhomedir/sbin/setloxberrypasswdsmb.exp loxberry $s->{adminpass1} );
			$exitcode  = $? >> 8;
			if ($exitcode ne 0) {
				print STDERR "setloxberrypasswdsmb.exp adminpassold Exitcode $exitcode\n";
				$error .= " setloxberrypasswdsmb.exp adminpassold Exitcode $exitcode<br>";
			} else {
				$maintemplate->param("SAMBAOK", 1);
				$sambaok = 1;
			}	
	
			# Save Username/Password for Webarea
			$output = qx(/usr/bin/htpasswd -c -b $lbhomedir/config/system/htusers.dat $s->{adminuser} $s->{adminpass1} );
			$exitcode  = $? >> 8;
			if ($exitcode != 0) {
				$error .= "htpasswd htusers.dat adminuser adminpass1 Exitcode $exitcode<br>";
				# &error;
			} else {
				$maintemplate->param("WEBOK", 1);
				$webok = 1;
			} 
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
			$securepinok = 1;
		} 
		
	# Set root password
	my $rootnewpassword = generate();
	$output = qx(LANG="en_GB.UTF-8" $lbhomedir/sbin/setrootpasswd.exp loxberry $rootnewpassword);
	$exitcode  = $? >> 8;
		if ($exitcode ne 0) {
			$error .= $SL{'WIZARD.ERROR_CANNOT_CHANGE_ROOT'} . "<br>";
		} else {
			$maintemplate->param("ROOTPASSOK", 1);
			$rootpassok = 1;
		} 
	
	################################################
	
	my $creditwebadmin;
	my $creditconsole;
	my $creditsecurepin;
	my $creditroot;
	
	if ($adminok && $wraperror ne 1) {
		$creditwebadmin = "$SL{'ADMIN.SAVE_OK_WEB_ADMIN_AREA'}\t$s->{adminuser} / $s->{adminpass1}\r\n";
		$creditconsole = "$SL{'ADMIN.SAVE_OK_COL_SSH'}\tloxberry / $s->{adminpass1}\r\n";
		$maintemplate->param( "ADMINPASS", $s->{adminpass1} );
	} else {
		$creditwebadmin = "$SL{'ADMIN.SAVE_OK_WEB_ADMIN_AREA'}\t$s->{adminuser} / loxberry\r\n";
		$creditconsole = "$SL{'ADMIN.SAVE_OK_COL_SSH'}\tloxberry / loxberry\r\n";
		$maintemplate->param( "ADMINPASS", "loxberry" );
	}
	if ($securepinok) {
		$creditsecurepin = "$SL{'ADMIN.SAVE_OK_COL_SECUREPIN'}\t$securepin1\r\n";
		$maintemplate->param( "SECUREPIN", $securepin1 );
	} else {
		$creditsecurepin = "$SL{'ADMIN.SAVE_OK_COL_SECUREPIN'}\t0000\r\n";
		$maintemplate->param( "SECUREPIN", "0000" );
	}
	if ($rootpassok) {
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

	$maintemplate->param( "ADMINUSER", $s->{adminuser} );
	$maintemplate->param( "CREDENTIALSTXT", $credentialstxt);
	
	$maintemplate->param( "ERRORS", $error);
	$maintemplate->param( "NEXTURL", "/admin/system/index.cgi?form=system");

	$template_title = $SL{'COMMON.LOXBERRY_MAIN_TITLE'} . ": " . $SL{'ADMIN.WIDGETLABEL'};
	
	
	###############################################
	
	$template_title = $SL{'WIZARD.TITLE_STEP3'};
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
	
	$template_title = $SL{'WIZARD.TITLE_STEP4'};
	LoxBerry::Web::head($template_title);
	$template_title .= " <span class='hint'>V$sversion</span>";
	LoxBerry::Web::pagestart($template_title, $helplink, $helptemplate);
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
	# print STDERR "selfurl: $selfurl\n";
	
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
# Random
#####################################################

sub generate {
        my ($e) = @_;
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
