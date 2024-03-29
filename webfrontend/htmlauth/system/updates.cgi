#!/usr/bin/perl

# Copyright 2017-2020 Michael Schlenstedt, michael@loxberry.de
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
use LoxBerry::System::General;
use LoxBerry::Web;
use LoxBerry::Log;
use Time::Piece;


use CGI::Carp qw(fatalsToBrowser);
#use CGI qw/:standard/;
use CGI;
# use Config::Simple;
# use File::HomeDir;
# use File::Path qw(make_path remove_tree);
use warnings;
use strict;

##########################################################################
# Variables
##########################################################################

my $helpurl = "https://wiki.loxberry.de/konfiguration/widget_help/widget_updates";
my $helptemplate = "help_updates.html";
my $lbulogfiledir = "$lbslogdir/loxberryupdate";
my $lbuchecklogfiledir = "$lbhomedir/log/system_tmpfs/loxberryupdate";

		
my $cfg;
my $template_title;

our $namef;
our $value;
our %query;
our $helplink;
our $error;
our $uploadfile;
our $output;
our $do;
our $filesize;
our $max_filesize;
our $allowed_filetypes;
our $tempfile;
our $tempfolder;
our $unzipbin;
our $chmodbin;
our $answer;
our $sversion;
our $uversion;
our @svfields;
our @uvfields;
our $rebootbin;

##########################################################################
# Read Settings
##########################################################################

# Version of this script
my $version = "3.0.0.0";

my $bins = LoxBerry::System::get_binaries();
$sversion = LoxBerry::System::lbversion();

# $cfg             = new Config::Simple("$lbsconfigdir/general.cfg");
my $jsonobj = LoxBerry::System::General->new();
my $cfg = $jsonobj->open();

$unzipbin        = $bins->{UNZIP};
$chmodbin        = $bins->{CHMOD};
$rebootbin       = $bins->{REBOOT};

#########################################################################
# Initialize LoxBerry::Log logfile
#########################################################################

my $log = LoxBerry::Log->new(
		package => 'LoxBerry Update',
		name => 'updates.cgi',
		logdir => "$lbslogdir",
		loglevel => 7,
		stderr => 1,
		nofile => 1,
);

LOGSTART "updates.cgi called";

#########################################################################
# Parameter
#########################################################################

# Import form parameters to the namespace R
my $cgi = CGI->new;
$cgi->import_names('R');
if ($R::lang) {
	# Nice feature: We override language detection of LoxBerry::Web
	$LoxBerry::Web::lang = substr($R::lang, 0, 2);
}

# Remove 'only used once' warnings
$R::do if 0;
$R::answer if 0;


my $lang = lblanguage();

our $maintemplate = HTML::Template->new(
				filename => "$lbstemplatedir/updates.html",
				global_vars => 1,
				loop_context_vars => 1,
				die_on_bad_params=> 0,
				associate => $jsonobj,
				%htmltemplate_options,
				);

our %SL = LoxBerry::System::readlanguage($maintemplate);

our %navbar;
 
$navbar{1}{Name} = $SL{'UPDATES.WIDGETLABEL_LOXBERRYUPDATE'};
$navbar{1}{URL} = $cgi->url(-relative=>1) . "?do=lbupdate";
$navbar{1}{Notify_Package} = 'updates';
$navbar{1}{Notify_Name} = 'check';

$navbar{2}{Name} = $SL{'UPDATES.WIDGETLABEL_UPDATES'};
$navbar{2}{URL} = $cgi->url(-relative=>1) . "?do=form";
 
$navbar{3}{Name} = $SL{'UPDATES.WIDGETLABEL_LOXBERRYUPDATEHISTORY'};
$navbar{3}{URL} = $cgi->url(-relative=>1) . "?do=lbuhistory";
$navbar{3}{Notify_Package} = 'updates';
$navbar{3}{Notify_Name} = 'update';

# And this one we really want to use
$do = $R::do;
$answer = $R::answer;

##########################################################################
# Main program
##########################################################################

#########################################################################
# What should we do
#########################################################################

# Menu
if ($do eq "form") {
  print STDERR "updates.cgi: FORM is called\n";
  $navbar{2}{active} = 1;
  &form;
}

elsif (!$do || $do eq "lbupdate") {
	$navbar{1}{active} = 1;
	print STDERR "updates.cgi LBUPDATES is called\n";
	&lbupdates;
}

elsif ($do eq "lbuhistory") {
	$navbar{3}{active} = 1;
	print STDERR "updates.cgi LBUHISTORY is called\n";
	&lbuhistory;
}

else {
 $navbar{1}{active} = 1;
  print STDERR "updates.cgi: FORM is called\n";
  &lbinstall;
}

exit;

#####################################################
# Form / Menu
#####################################################

sub form {

	# TMPL_IF use "form"
	$maintemplate->param( "form", 1);
	 
	$maintemplate->param ("SELFURL", $ENV{REQUEST_URI});


	our $unattended_val = get_unattended_upgrades_days();
	our $unattended_reboot_bool = get_unattended_upgrades_autoreboot();

	print STDERR "OFF: $SL{'UPDATES.SECUPDATE_RADIO_OFF'}\n";

	our $cgi = new CGI;
	our %labels = (		'0'=>  $SL{'UPDATES.SECUPDATE_RADIO_OFF'},
						'1'=> $SL{'UPDATES.SECUPDATE_RADIO_DAILY'},
						'7'=> $SL{'UPDATES.SECUPDATE_RADIO_WEEKLY'},
						'30'=> $SL{'UPDATES.SECUPDATE_RADIO_MONTHLY'});
					 
	our $update_radio = $cgi->radio_group(
			-name 	 => 'option-secupdates',
			-values  => ['0', '1', '7', '30'],
			-labels  => \%labels,
			-default => $unattended_val,
		);
	$maintemplate->param("UPDATE_RADIO", $update_radio);
		
	our $update_reboot_checkbox = $cgi->checkbox( -name => 'updates-autoreboot',
												  -checked => $unattended_reboot_bool,
												  #-checked => 1,
												  #-value => '1',
												  -label => $SL{'UPDATES.SECUPDATE_REBOOT_ENABLED'}
		);
	$maintemplate->param("UPDATE_REBOOT_CHECKBOX", $update_reboot_checkbox);
		
	$template_title = $SL{'COMMON.LOXBERRY_MAIN_TITLE'} . ": " . $SL{'UPDATES.WIDGETLABEL'};

	# Print Template
	LoxBerry::Web::lbheader($template_title, $helplink, $helptemplate);
	print $maintemplate->output();
	LoxBerry::Web::lbfooter();
	exit;

}


#####################################################
# LoxBerry Update Page
#####################################################

sub lbupdates
{

	# TMPL_IF use "lbupdate"
	$maintemplate->param( "lbupdate", 1);
	$template_title = $SL{'COMMON.LOXBERRY_MAIN_TITLE'} . ": " . $SL{'UPDATES.WIDGETLABEL'};

	# Releasetype
	our %labels = (		'release'=>  $SL{'UPDATES.LBU_SEL_RELTYPE_RELEASE'},
						'prerelease'=> $SL{'UPDATES.LBU_SEL_RELTYPE_PRERELEASE'},
						'latest' => $SL{'UPDATES.LBU_SEL_RELTYPE_LATEST'},
						);
					 
	our $releasetype_radio = $cgi->radio_group(
			-name      => 'option-releasetype',
			-values  => ['release', 'prerelease', 'latest'],
			-labels  => \%labels,
			-default => $cfg->{Update}->{Releasetype}
		);
	$maintemplate->param("RELEASETYPE_RADIO", $releasetype_radio);
	
	%labels = (		'install'=> $SL{'UPDATES.LBU_SEL_INSTALLTYPE_INSTALL'},
						'notify'=> $SL{'UPDATES.LBU_SEL_INSTALLTYPE_NOTIFY'},
						'disable'=>  $SL{'UPDATES.LBU_SEL_INSTALLTYPE_DISABLE'},
						);
					 
	our $installtype_radio = $cgi->radio_group(
			-name    => 'option-installtype',
			-values  => ['install', 'notify', 'disable'],
			-labels  => \%labels,
			-default => $cfg->{Update}->{Installtype}
		);
	$maintemplate->param("INSTALLTYPE_RADIO", $installtype_radio);
	
	%labels = (		'1'=> $SL{'UPDATES.LBU_SEL_INSTALLTIME_DAILY'},
						'7'=> $SL{'UPDATES.LBU_SEL_INSTALLTIME_WEEKLY'},
						'30'=> $SL{'UPDATES.LBU_SEL_INSTALLTIME_MONTHLY'});
					 
	our $installtime_radio = $cgi->radio_group(
			-name    => 'option-installtime',
			-values  => ['1', '7', '30'],
			-labels  => \%labels,
			-default => $cfg->{Update}->{Interval}
		);
	$maintemplate->param("INSTALLTIME_RADIO", $installtime_radio);
	
	$maintemplate->param("LBVERSION", $sversion);
	
	# Print Template
	LoxBerry::Web::lbheader($template_title, $helplink, $helptemplate);
	print LoxBerry::Log::get_notifications_html('updates', 'check');
	print $maintemplate->output();
	LoxBerry::Web::lbfooter();

}


#####################################################
# LoxBerry Update History
#####################################################

sub lbuhistory
{
	LOGDEB "lbuhistory -->";
	# TMPL_IF use "lbuhistory"
	$maintemplate->param( "lbuhistory", 1);
	# my %SL = LoxBerry::System::readlanguage($maintemplate);
	$template_title = $SL{'COMMON.LOXBERRY_MAIN_TITLE'} . ": " . $SL{'UPDATES.WIDGETLABEL'};

	$maintemplate->param("UPDATELOGS_HTML", loglist_html( PACKAGE => 'LoxBerry Update', NAME => 'update' ));
	$maintemplate->param("UPDATECHECKLOGS_HTML", loglist_html( PACKAGE => 'LoxBerry Update', NAME => 'check' ));
	
	
	# Print Template
	LoxBerry::Web::lbheader($template_title, $helplink, $helptemplate);
	print LoxBerry::Log::get_notifications_html('updates', 'update');
	print $maintemplate->output();
	LoxBerry::Web::lbfooter();

	
}

#####################################################
# 
# Subroutines
#
#####################################################

#####################################################
# Error
#####################################################

sub error {

	$template_title = $SL{'COMMON.LOXBERRY_MAIN_TITLE'} . ": " . $SL{'UPDATES.WIDGETLABEL'};
	
	my $maintemplate = HTML::Template->new(
				filename => "$lbstemplatedir/error.html",
				global_vars => 1,
				loop_context_vars => 1,
				die_on_bad_params=> 0,
				# associate => $cfg,
				%htmltemplate_options,
				);
	$maintemplate->param( "ERROR", $error);
	LoxBerry::System::readlanguage($maintemplate);
	LoxBerry::Web::head();
	LoxBerry::Web::pagestart();
	print $maintemplate->output();
	LoxBerry::Web::pageend();
	LoxBerry::Web::foot();
	exit;

}

#####################################################
# Random
#####################################################

sub generate 
{
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

#####################################################
# Check if folder is empty
#####################################################

sub is_folder_empty {
  my $dirname = shift;
  opendir(my $dh, $dirname); 
  return scalar(grep { $_ ne "." && $_ ne ".." } readdir($dh)) == 0;
}

###################################################################
# Returns the current days of unattended-upgrades
###################################################################

sub get_unattended_upgrades_days
{
	my $aptfile = "/etc/apt/apt.conf.d/02periodic";
	if (!-f $aptfile) {
		return 0; 
	}
	open(FILE, $aptfile) || die "File not found";
	my @lines = <FILE>;
	close(FILE);

	my $querystring;
	my $queryresult;
	
	foreach(@lines) {
		if (begins_with($_, "APT::Periodic::Unattended-Upgrade"))
			{   my ($querystring, $queryresult) = split / /;
				$queryresult =~ s/\R//g;
				$queryresult =~ s/[\$"#@~!&*()\[\];.,:?^ `\\\/]+//g; #" Highlighting fix for Ultra Edit
				return $queryresult;
			}
	}
return 0;
}

###################################################################
# Returns if unattended-upgrades is set to automatically reboot
###################################################################

sub get_unattended_upgrades_autoreboot
{
	my $aptfile = "/etc/apt/apt.conf.d/50unattended-upgrades";
	if (!-f $aptfile) {
		return 0; 
	}
	open(FILE, $aptfile) || die "File not found";
	my @lines = <FILE>;
	close(FILE);

	my $querystring;
	my $queryresult;
	
	foreach(@lines) {
		if (begins_with($_, "Unattended-Upgrade::Automatic-Reboot-WithUsers "))
			{   my ($querystring, $queryresult) = split / /;
				# print STDERR "AUTOREBOOT QUERYRESULT: " . $queryresult . "\n";
				$queryresult =~ s/\R//g;
				#print STDERR "AUTOREBOOT QUERYRESULT: " . $queryresult . "\n";
				$queryresult =~ s/[\$"#@~!&*()\[\];.,:?^ `\\\/]+//g;
				#print STDERR "AUTOREBOOT QUERYRESULT: #" . $queryresult . "#\n";
				return $queryresult eq 'true' ? 1 : 0;
				#print STDERR "AUTOREBOOT RETURNVAL: " . $returnval . "\n";
				#return $returnval;
			}
	}
return 0;
}
