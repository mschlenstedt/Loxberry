#!/usr/bin/perl

# Copyright 2016-2019 Michael Schlenstedt, michael@loxberry.de
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
use CGI::Carp qw(fatalsToBrowser);
use CGI;
use Config::Simple;
use File::Path qw(make_path remove_tree);
use warnings;
use strict;

##########################################################################
# Variables
##########################################################################

my $helplink = "https://www.loxwiki.eu/x/UIgKAw";
my $helptemplate = "help_plugininstall.html";
my $template_title;
my $resp;
my $error;

my @plugins = LoxBerry::System::get_plugins();


##########################################################################
# Read Settings
##########################################################################

# Version of this script
my $version = "2.2.1.1";
my $bins = LoxBerry::System::get_binaries();

#########################################################################
# Parameter
#########################################################################

# Params from CGI
my $cgi = CGI->new;
#$cgi->import_names('R');

# Check if this is a file upload (needs to come first!)
my $upload_fh = $cgi->upload('uploadfile');

# And this one we really want to use
my $do = $cgi->param('do');
my $pid = $cgi->param('pid');
my $answer = $cgi->param('answer');
my $url = $cgi->param('url');
my $saveformdata = $cgi->param('saveformdata');
my $securepin = $cgi->param('securepin');

if ( defined $saveformdata and $saveformdata eq "1" ) {
	$do = "install";
}

my $maintemplate = HTML::Template->new(
      filename => "$lbstemplatedir/plugininstall.html",
      global_vars => 1,
      loop_context_vars => 1,
      die_on_bad_params=> 0,
      %htmltemplate_options,
      #debug => 1,
);
$maintemplate->param("SELFURL", $ENV{REQUEST_URI});
$maintemplate->param("PLUGINS" => \@plugins);


##########################################################################
# Language Settings
##########################################################################

my %SL = LoxBerry::System::readlanguage($maintemplate);
my $lang = lblanguage();


#########################################################################
# What should we do
#########################################################################

$template_title = $SL{'COMMON.LOXBERRY_MAIN_TITLE'} . ": " . $SL{'PLUGININSTALL.WIDGETLABEL'};

# Menu
if (!$do || $do eq "form") {
  #print STDERR "Calling subfunction FORM\n";
  &form;
}

# Installation
elsif ($do eq "install") {
  #print STDERR "Calling subfunction INSTALL\n";
  &install;
}

# UnInstallation
elsif ($do eq "uninstall") {
  #print STDERR "Calling subfunction UNINSTALL\n";
  &uninstall;
}

else {
  #print STDERR "Calling subfunction FORM (default)\n";
  $maintemplate->param("FORM", 1);
  &form;
}

exit;


#####################################################
# Form / Menu
#####################################################

sub form {
	
	# Create tmp dirs
	if (!-e "$lbsdatadir/tmp/uploads") {
		make_path("$lbsdatadir/tmp/uploads" , {chmod => 0755, owner=>'loxberry', group=>'loxberry'});
	}

	# Check for running autoupdates/installations...
	my $status = LoxBerry::System::lock();
	if ($status) {
		#print STDERR "Running Autoupdates/Installations: $status\n";
		$maintemplate->param("LOCK", 1);
	} else {
		# Clean up old files
		system("rm -r -f $lbsdatadir/tmp/uploads/*");
  		$maintemplate->param("FORM", 1);
	}

	if ($url) {
  		$maintemplate->param("ARCHIVEURL", "$url");
	}

	# Print Template
	LoxBerry::Web::head();
	LoxBerry::Web::pagestart($template_title, $helplink, $helptemplate);

	if (!$url) {
		print LoxBerry::Log::get_notifications_html('plugininstall');
	}

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

	if (!$answer) {
		#print STDERR "Asking for uninstallation.";
		$maintemplate->param("QUESTION", 1);
		foreach my $plugin (@plugins) {
			if ($plugin->{PLUGINDB_MD5_CHECKSUM} eq $pid) {
				$maintemplate->param("UNINSTALL_QUESTION", $SL{'PLUGININSTALL.UI_MSG_UNINSTALL_QUESTION'} . " <b>" . $plugin->{PLUGINDB_TITLE} . "</b>?");
				last;
			}
		}
	} else {
		# Clean up old files
		system("rm -r -f $lbsdatadir/tmp/uploads/* > /dev/null 2>&1");
		# Uninstallation
		#print STDERR "Doing uninstallation of $pid.";
		$maintemplate->param("UNINSTALL", 1);
		system ("sudo $lbhomedir/sbin/plugininstall.pl action=uninstall pid=$pid > /dev/null 2>&1");
	}
	
	# Print Template
	LoxBerry::Web::head();
	LoxBerry::Web::pagestart($template_title, $helplink, $helptemplate);

	print $maintemplate->output();
	undef $maintemplate;

	LoxBerry::Web::pageend();
	LoxBerry::Web::foot();

  exit;

}


#####################################################
# Install
#####################################################

sub install {
	
	my $uploadfile;
	my $uploadfilename;
	my $uploadpath = "$lbsdatadir/tmp/uploads";
	
	
	system("rm -r -f $uploadpath/*");

	# Check if SecurePIN is correct
	my $checkresult = LoxBerry::System::check_securepin($securepin);
	if ( defined $checkresult and $checkresult == 3 ) {
		#print STDERR "The securepin currently is locked.";
		$error = $SL{'PLUGININSTALL.UI_INSTALL_ERR_SECUREPIN_LOCKED'};
		&error;
	} elsif ( defined $checkresult and $checkresult == 2 ) {
		$error = "Internal error. Could not open securepin data file.";
		&error;
	} elsif ( defined $checkresult and $checkresult == 1 ) {
		#print STDERR "The entered securepin is wrong.";
		$error = $SL{'PLUGININSTALL.UI_INSTALL_ERR_SECUREPIN_WRONG'};
		&error;
	}

	my $archiveurl = $cgi->param('archiveurl');
	
	# Randomly file naming
	my $tempfile = generate(10);

	#
	# If there's no URL given, check the upload file
	#
	if (!$archiveurl) {
		# allowed file endings (use | to seperate more than one)
		my $allowed_filetypes = "zip";

		# Max filesize (KB)
		my $max_filesize = 150000;

		# Using CGI to fetch the upload
		$uploadfile = $cgi->tmpFileName($upload_fh);
		$uploadfilename = $cgi->param('uploadfile');
		# print STDERR "Upload filename is $uploadfile\n";
		# print STDERR "Upload given filename is " . $cgi->param('uploadfile') . "\n";
		
		# Filesize
		my $filesize = -s $uploadfile;
		$filesize /= 1000;
		#print STDERR "The upload file is $filesize.\n";

		# If it's larger than allowed...
		if ($filesize > $max_filesize) {
			$error = $SL{'PLUGININSTALL.UI_INSTALL_ERR_MAX_FILESIZE'};
			&error;
		}

		# Test if filetype is allowed
		if($uploadfilename !~ /^.+\.($allowed_filetypes)/) {
			$error = $SL{'PLUGININSTALL.UI_INSTALL_ERR_WRONG_FILETYPE'};
			&error;
		}

		# Copy CGI's temp file to LoxBerry's temp directory
		require File::Copy;
		File::Copy::copy( $uploadfile, "$uploadpath/$tempfile.zip" );

	}

	my $logtemplate = HTML::Template->new(
		filename => "$lbstemplatedir/plugininstall_log.html",
		global_vars => 1,
		loop_context_vars => 1,
		die_on_bad_params=> 0,
		# associate => $cfg,
		%htmltemplate_options,
#		debug => 1,
	);
	my %SL = LoxBerry::System::readlanguage($logtemplate);
	$logtemplate->param( "LOGFILE", "$tempfile.log");
	$logtemplate->param( "STATUSFILE", "$tempfile.status");

	
	# Print Template
	$template_title = $SL{'COMMON.LOXBERRY_MAIN_TITLE'} . ": " . $SL{'PLUGININSTALL.WIDGETLABEL'};
	LoxBerry::Web::head();
	LoxBerry::Web::pagestart($template_title, $helplink, $helptemplate);

	print $logtemplate->output();
	undef $logtemplate;

	LoxBerry::Web::pageend();
	LoxBerry::Web::foot();
	
	# Without the following workaround
	# the script cannot be executed as
	# background process via CGI
	my $pid = fork();
	die "Fork failed: $!" if !defined $pid;

	if ($pid == 0) {

		my $logfile = "/tmp/$tempfile.log";
		my $openerr;
		
		# do this in the child
		open STDIN, "</dev/null";
		open STDOUT, ">$logfile";
		#open STDERR, ">$logfile";
		open STDERR, ">/dev/null";

		if ($archiveurl) {
			print "<INFO> Downloading $archiveurl ...\n";
			$resp = `$bins->{CURL} -q --connect-timeout 10 --max-time 60 --retry 5 -LfksSo $lbsdatadir/tmp/uploads/$tempfile.zip $archiveurl  2>&1`;
		} else {
			# File is already there
		}

		# Do the installation
		system ("sudo $lbhomedir/sbin/plugininstall.pl action=install file=$lbsdatadir/tmp/uploads/$tempfile.zip pin=$securepin tempfile=$tempfile cgi=1 >> $logfile 2>&1");

	} # End Child process

exit;


} # End sub


#####################################################
# Error
#####################################################

sub error {

	system("rm /var/lock/plugininstall.lock");

	$template_title = $SL{'COMMON.LOXBERRY_MAIN_TITLE'} . ": " . $SL{'PLUGININSTALL.WIDGETLABEL'};

	my $errtemplate = HTML::Template->new(
		filename => "$lbstemplatedir/error.html",
		global_vars => 1,
		loop_context_vars => 1,
		die_on_bad_params=> 0,
		%htmltemplate_options,
		# associate => $cfg,
	);

	print STDERR "plugininstall.cgi: Sub ERROR called with message $error.\n";
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
	my ($e) = @_;
	my($zufall,@words,$more);

	if($e =~ /^\d+$/){
		$more = $e;
	} else {
		$more = "10";
	}

	@words = qw(A B C D E F G H I J K L M N O P Q R S T U V W X Y Z a b c d e f g h i j k l m n o p q r s t u v w x y z 0 1 2 3 4 5 6 7 8 9);

	foreach (1..$more){
		$zufall .= $words[int rand($#words+1)];
	}

	return($zufall);
}
