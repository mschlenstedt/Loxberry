#!/usr/bin/perl

# Copyright 2016 Michael Schlenstedt, michael@loxberry.de
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
use CGI qw/:standard/;
use Config::Simple;
use File::Path qw(make_path remove_tree);
#use warnings;
#use strict;
#no strict "refs"; # we need it for template system

##########################################################################
# Variables
##########################################################################

my $helpurl = "http://www.loxwiki.eu/display/LOXBERRY/LoxBerry";
my $helptemplate = "help_plugininstall.html";

my $error;


##########################################################################
# Read Settings
##########################################################################

# Version of this script
my $version = "0.1.0";

my $cfg			= new Config::Simple("$lbsconfigdir/general.cfg");
#$installfolder   = $cfg->param("BASE.INSTALLFOLDER");
#$lang            = $cfg->param("BASE.LANG");
#$unzipbin        = $cfg->param("BINARIES.UNZIP");
#$bashbin         = $cfg->param("BINARIES.BASH");
#$aptbin          = $cfg->param("BINARIES.APT");
#$sudobin         = $cfg->param("BINARIES.SUDO");
#$chmodbin        = $cfg->param("BINARIES.CHMOD");


#########################################################################
# Parameter
#########################################################################

# Everything from URL
my %query;
my $namef;
my $value;
foreach (split(/&/,$ENV{'QUERY_STRING'})){
  ($namef,$value) = split(/=/,$_,2);
  $namef =~ tr/+/ /;
  $namef =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/eg;
  $value =~ tr/+/ /;
  $value =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/eg;
  $query{$namef} = $value;
}

# And this one we really want to use
my $do           = $query{'do'};
my $answer       = $query{'answer'};
my $pid          = $query{'pid'};

# Everything from Forms
my $saveformdata = param('saveformdata');
my $securepin = param('securepin');

# Filter
$saveformdata = quotemeta($saveformdata);
$do = quotemeta($do);

$saveformdata          =~ tr/0-1//cd;
$saveformdata          = substr($saveformdata,0,1);


##########################################################################
# Language Settings
##########################################################################

my %SL = LoxBerry::System::readlanguage($maintemplate);

my $lang = lblanguage();
$maintemplate->param( "LBHOSTNAME", lbhostname());
$maintemplate->param( "LANG", $lang);
$maintemplate->param ( "SELFURL", $ENV{REQUEST_URI});


##########################################################################
# Cleaning
##########################################################################

# Clean up old files
system("rm -r -f /tmp/uploads/");


#########################################################################
# What should we do
#########################################################################

# Menu
if (!$do || $do eq "form") {
  print STDERR "FORM called\n";
  $maintemplate->param("FORM", 1);
  &form;
}

# Installation
elsif ($do eq "install") {
  print STDERR "INSTALL called\n";
  $maintemplate->param("INSTALL", 1);
  &install;
}

# UnInstallation
elsif ($do eq "uninstall") {
  print STDERR "UINSTALL called\n";
  $maintemplate->param("UINSTALL", 1);
  &uninstall;
}

else {
  print STDERR "FORM called\n";
  $maintemplate->param("FORM", 1);
  &form;
}

exit;


#####################################################
# Form / Menu
#####################################################

sub form {

	my $maintemplate = HTML::Template->new(
		filename => "$lbstemplatedir/plugininstall.html",
		global_vars => 1,
		loop_context_vars => 1,
		die_on_bad_params=> 0,
		associate => $cfg,
		%htmltemplate_options,
		debug => 1,
	);


#open(F,"<$installfolder/data/system/plugindatabase.dat");
#  @data = <F>;
#  foreach (@data){
#    s/[\n\r]//g;
#    # Comments
#    if ($_ =~ /^\s*#.*/) {
#      print F "$_\n";
#      next;
#    }
#    @fields = split(/\|/);
#    $pmd5checksum = @fields[0];
#    $pname = @fields[4];
#    $btn1 = $phrase->param("TXT0101");
#    $btn2 = $phrase->param("TXT0102");
#    $ptablerows = $ptablerows . "<tr><th>$i</th><td>@fields[6]</td><td>@fields[3]</td><td>@fields[1]</td>";
#    $ptablerows = $ptablerows . "<td><a data-role=\"button\" data-inline=\"true\" data-icon=\"info\" data-mini=\"true\" href=\"/admin/system/tools/logfile.cgi?logfile=system/plugininstall/$pname.log&header=html&format=template\" target=\"_blank\">$btn1</a>&nbsp;";
#    $ptablerows = $ptablerows . "<a data-role=\"button\" data-inline=\"true\" data-icon=\"delete\" data-mini=\"true\" href=\"/admin/system/plugininstall.cgi?do=uninstall&pid=$pmd5checksum\">$btn2</a></td></tr>\n";
#    $i++;
#  }
#close (F);

	# Print Template
	$template_title = $SL{'COMMON.LOXBERRY_MAIN_TITLE'} . ": " . $SL{'PLUGININSTALL.WIDGETLABEL'};
	LoxBerry::Web::head();
	LoxBerry::Web::pagestart($template_title, $helplink, $helptemplate);

	print $maintemplate->output();
	undef $maintemplate;

	LoxBerry::Web::pageend();
	LoxBerry::Web::foot();

	exit;

}

#####################################################
# Uninstall
#####################################################

sub uninstall {

  exit;

}


#####################################################
# Install
#####################################################

sub install {

	my $maintemplate = HTML::Template->new(
		filename => "$lbstemplatedir/plugininstall_log.html",
		global_vars => 1,
		loop_context_vars => 1,
		die_on_bad_params=> 0,
		associate => $cfg,
		%htmltemplate_options,
		debug => 1,
	);

	# Check if SecurePIN is correct
	if ( LoxBerry::System::check_securepin($securepin) ) {
		print STDERR "The entered securepin is wrong.";
		$error = $SL{'PLUGININSTALL.UI_INSTALL_ERR_SECUREPIN_WRONG'};
		&error;
	}

	my $uploadfile = param('uploadfile');
	print STDERR "The upload file is $uploadfile.\n";

	# Randomly file naming
	my $tempfile = &generate(10);

	# Filter
	#quotemeta($uploadfile);

	# allowed file endings (use | to seperate more than one)
	my $allowed_filetypes = "zip";

	# Max filesize (KB)
	my $max_filesize = 50000;

	# Filter Backslashes
	$uploadfile =~ s/.*[\/\\](.*)/$1/;

	# Filesize
	my $filesize = -s $uploadfile;
	$filesize /= 1000;
	print STDERR "The upload file is $filesize.\n";

	# If it's larger than allowed...
	if ($filesize > $max_filesize) {
		$error = $SL{'PLUGININSTALL.UI_INSTALL_ERR_MAX_FILESIZE'};
		&error;
	}

	# Test if filetype is allowed
	if($uploadfile !~ /^.+\.($allowed_filetypes)/) {
		$error = $SL{'PLUGININSTALL.UI_INSTALL_ERR_WRONG_FILETYPE'};
		&error;
	}

		$error = "Stopping";
		&error;

	# Without the following workaround
	# the script cannot be executed as
	# background process via CGI
	my $pid = fork();
	die "Fork failed: $!" if !defined $pid;

	if ($pid == 0) {
		# do this in the child
		open STDIN, "</dev/null";
		open STDOUT, ">$logfile";
		#open STDERR, ">$logfile";
		open STDERR, ">/dev/null";

	} # End Child process

exit;


} # End sub


#####################################################
# Error
#####################################################

sub error {

	$template_title = $SL{'COMMON.LOXBERRY_MAIN_TITLE'} . ": " . $SL{'PLUGININSTALL.WIDGETLABEL'};

	my $errtemplate = HTML::Template->new(
		filename => "$lbstemplatedir/error.html",
		global_vars => 1,
		loop_context_vars => 1,
		die_on_bad_params=> 0,
		%htmltemplate_options,
		# associate => $cfg,
	);

	print STDERR "plugininstall.cgi: sub error called with message $error.\n";
	$errtemplate->param( "ERROR", $error);

	LoxBerry::System::readlanguage($errtemplate);

	LoxBerry::Web::head();
	LoxBerry::Web::pagestart();

	print $errtemplate->output();

	LoxBerry::Web::pageend();
	LoxBerry::Web::foot();

	exit;

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
