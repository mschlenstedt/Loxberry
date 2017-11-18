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

use CGI::Carp qw(fatalsToBrowser);
use CGI qw/:standard/;
use CGI;
use Config::Simple;
use File::HomeDir;
use File::Path qw(make_path remove_tree);
#use warnings;
#use strict;
#no strict "refs"; # we need it for template system

##########################################################################
# Variables
##########################################################################

our $cfg;
our $pcfg;
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
our $saveformdata;
our $installfolder;
our $languagefile;
our $version;
our $error;
our $uploadfile;
our $output;
our $message;
our $do;
our $nexturl;
our $filesize;
our $max_filesize;
our $allowed_filetypes;
our $tempfile;
our $tempfolder;
our $unzipbin;
our @data;
our @fields;
our $home = File::HomeDir->my_home;
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
$version = "0.0.2";

$cfg             = new Config::Simple("$home/config/system/general.cfg");
$sversion        = $cfg->param("BASE.VERSION");
$installfolder   = $cfg->param("BASE.INSTALLFOLDER");
$lang            = $cfg->param("BASE.LANG");
$unzipbin        = $cfg->param("BINARIES.UNZIP");
$chmodbin        = $cfg->param("BINARIES.CHMOD");
$rebootbin       = $cfg->param("BINARIES.REBOOT");

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
$answer       = $query{'answer'};

# Everything from Forms
$saveformdata = param('saveformdata');

# Filter
quotemeta($query{'lang'});
quotemeta($saveformdata);
quotemeta($do);

$saveformdata          =~ tr/0-1//cd;
$saveformdata          = substr($saveformdata,0,1);
$query{'lang'}         =~ tr/a-z//cd;
$query{'lang'}         =  substr($query{'lang'},0,2);

##########################################################################
# Language Settings
##########################################################################

# Override settings with URL param
if ($query{'lang'}) {
  $lang = $query{'lang'};
}

# Standard is german
if ($lang eq "") {
  $lang = "de";
}

# If there's no language phrases file for choosed language, use german as default
if (!-e "$installfolder/templates/system/$lang/language.dat") {
  $lang = "de";
}

# Read translations / phrases
$languagefile = "$installfolder/templates/system/$lang/language.dat";
$phrases = new Config::Simple($languagefile);
# $phrases->import_names('T');
#Config::Simple->import_from($languagefile, \%T);
#print STDERR "Language TEST: " . $T::SECUPDATE_RADIO_DAILY . "\n";
#print STDERR "Language TEST phrases: " . $phrases->param('SECUPDATE_RADIO_DAILY') . "\n";


##########################################################################
# Main program
##########################################################################

#########################################################################
# What should we do
#########################################################################

# Menu
if (!$do || $do eq "form") {
  &form;
}

# Installation
elsif ($do eq "install") {
  &install;
}

else {
  &form;
}

exit;

#####################################################
# Form / Menu
#####################################################

sub form {

print "Content-Type: text/html\n\n";

our $unattended_val = get_unattended_upgrades_days();
our $unattended_reboot_bool = get_unattended_upgrades_autoreboot();

our $cgi = new CGI;
our %labels = ('0'=> $phrases->param('SECUPDATE_RADIO_OFF'),
					 '1'=> $phrases->param('SECUPDATE_RADIO_DAILY'),
					 '7'=> $phrases->param('SECUPDATE_RADIO_WEEKLY'),
					 '30'=> $phrases->param('SECUPDATE_RADIO_MONTHLY'));
				 
our $update_radio = $cgi->radio_group(
        -name    => 'option-secupdates',
        -values  => ['0', '1', '7', '30'],
        -labels  => \%labels,
		-default => $unattended_val,
    );

our $update_reboot_checkbox = $cgi->checkbox( -name => 'updates-autoreboot',
											  -checked => $unattended_reboot_bool,
											  #-checked => 1,
											  #-value => '1',
											  -label => $phrases->param('SECUPDATE_REBOOT_ENABLED')
	);

$template_title = $phrases->param('TXT0000') . ": " . $phrases->param('TXT0103');
$help = "updates";

# Print Template
&header;
open(F,"$installfolder/templates/system/$lang/updates_menu.html") || die "Missing template system/$lang/updates_menu.html";
  while (<F>) {
    $_ =~ s/<!--\$(.*?)-->/${$1}/g;
	# $_ =~ s/<!--\$(.*?)-->/${$1}/g;
    print $_;
  }
close(F);
&footer;

exit;

}

#####################################################
# Install
#####################################################

sub install {

# Should we proceed the upgrade?
if ($answer eq "yes") {

  # Check for needed upgrade files
  if (!-f "/tmp/upgrade/upgrade.sh" || !-f "/tmp/upgrade/VERSION") {
    $error = $phrase->param("TXT0106");
    &error;
    exit;
  }

  # Copy and clean
  $output = qx(rm -rf $home/data/system/upgrade/*);
  $output = qx(cp -r /tmp/upgrade/* $home/data/system/upgrade);
  $output = qx(rm -rf /tmp/upgrade);
  $output = qx($chmodbin 755 $home/data/system/upgrade/upgrade.sh);
  
  print "Content-Type: text/html\n\n";

  $template_title = $phrase->param("TXT0000") . " - " . $phrase->param("TXT0103");
  $help = "updates";

  $message = $phrase->param("TXT0108");
  $nexturl = "/admin/index.cgi";

  # Print Template
  &header;
  open(F,"$installfolder/templates/system/$lang/success.html") || die "Missing template system/$lang/success.html";
    while (<F>) {
      $_ =~ s/<!--\$(.*?)-->/${$1}/g;
      print $_;
    }
  close(F);
  &footer;

  # Reboot
  # Without the following workaround
  # the script cannot be executed as
  # background process via CGI
  my $pid = fork();
  die "Fork failed: $!" if !defined $pid;
  if ($pid == 0) {
    # do this in the child
    open STDIN, "</dev/null";
    open STDOUT, ">/dev/null";
    open STDERR, ">/dev/null";
    system("sleep 5 && sudo $rebootbin &");
  }

  exit;
 
}

# Prepare Upgrade
$uploadfile = param('uploadfile');
my $origname = $uploadfile;

# Choose time() as new temp. filename (to avoid overwriting)
$tempfile = &generate(10);
$tempfolder = $tempfile;

# Filter
#quotemeta($uploadfile);

# allowed file endings (use | to seperate more than one)
$allowed_filetypes = "zip";

# Max filesize (KB)
$max_filesize = 100000;

# Filter Backslashes
$uploadfile =~ s/.*[\/\\](.*)/$1/;

# Filesize
$filesize = -s $uploadfile;
$filesize /= 1000;

# If it's larger than allowed...
if ($filesize > $max_filesize) {
  $error = $phrase->param("TXT0104");
  &error;
  exit;
}

# Test if filetype is allowed
if($uploadfile !~ /^.+\.($allowed_filetypes)/) {
  $error = $phrase->param("TXT0046");
  &error;
  exit;
}

# Remove old files and Create upload folder
$output = qx(rm -rf /tmp/upgrade);
make_path("/tmp/upgrade" , {chmod => 0777});

# We are careful, so test if file and/or dir already exists
if (-e "/tmp/upgrade/$tempfile.zip") {
  $error = $phrase->param("TXT0047");
  &error;
  exit;
} else {
  # Write Uploadfile
  $openerr = 0;
  open UPLOADFILE, ">/tmp/upgrade/$tempfile.zip" or ($openerr = 1);
  binmode $uploadfile;
  while ( <$uploadfile> ) {
    print UPLOADFILE;
  }
  close UPLOADFILE;
  if ($openerr) {
    $error = $phrase->param("TXT0047");
    &error;
    exit;
  } 
}

# UnZipping
$output = qx($unzipbin -d /tmp/upgrade /tmp/upgrade/$tempfile.zip);
if ($? ne 0) {
  $error = $phrase->param("TXT0105");
  &error;
  exit;
} 

# Check for needed upgrade files
if (!-f "/tmp/upgrade/upgrade.sh" || !-f "/tmp/upgrade/VERSION") {
  $error = $phrase->param("TXT0106");
  &error;
  exit;
}

# Read Version of upgrade
open(F,"</tmp/upgrade/VERSION");
$uversion = <F>;
chomp ($uversion);
close(F);

# Check if upgrade is newer than system
@uvfields = split /\./, $uversion;
@svfields = split /\./, $sversion;

# Older
if (@uvfields[0] < @svfields[0]) {
  $error = $phrase->param("TXT0107");
  &error;
  exit;
}

# Older
if (@uvfields[1] < @svfields[1] && @uvfields[0] == @svfields[0]) {
  $error = $phrase->param("TXT0107");
  &error;
  exit;
}

# Older or equal
if (@uvfields[2] <= @svfields[2] && @uvfields[1] == @svfields[1] && @uvfields[0] == @svfields[0]) {
  $error = $phrase->param("TXT0107");
  &error;
  exit;
}

# Header
print "Content-Type: text/html\n\n";

$template_title = $phrase->param("TXT0000") . ": " . $phrase->param("TXT0103");
$help = "updates";

$nexturl = "/admin/index.cgi";

# Print Template
&header;
open(F,"$installfolder/templates/system/$lang/upgrade_install.html") || die "Missing template system/$lang/upgrade_install.html";
  while (<F>) {
    $_ =~ s/<!--\$(.*?)-->/${$1}/g;
    print $_;
  }
close(F);
&footer;


exit;

# End sub
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

$template_title = $phrase->param("TXT0000") . " - " . $phrase->param("TXT0043");
$help = "plugin";

print "Content-Type: text/html\n\n";

&header;
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

sub header {

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
				$queryresult =~ s/[\$"#@~!&*()\[\];.,:?^ `\\\/]+//g;
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
				print STDERR "AUTOREBOOT QUERYRESULT: " . $queryresult . "\n";
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




###################################################################
# Returns a value if string2 is the at the beginning of string 1
###################################################################

sub begins_with
{	
		
    return substr($_[0], 0, length($_[1])) eq $_[1];
}		
			