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
use Config::Simple;
use File::HomeDir;
use File::Path qw(make_path remove_tree);
use Digest::MD5 qw(md5_hex);
use Encode qw(encode_utf8);
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
our $saveformdata;
our $uploadfile;
our $output;
our $message;
our $e;
our $do;
our $nexturl;
our $filesize;
our $max_filesize;
our $allowed_filetypes;
our $tempfile;
our $tempfolder;
our $unzipbin;
our $pauthorname;
our $pauthoremail;
our $pversion;
our $pname;
our $ptitle;
our $pfolder;
our $pinterface;
our $logfile;
our $logfileurl;
our $statusfile;
our $statusfileurl;
our $openerr;
our @data;
our @data1;
our @fields;
our $pmd5checksum;
our $isupgrade;
our @names;
our @folders;
our $exists;
our $i;
our $i1;
our $bashbin;
our $home = File::HomeDir->my_home;
our $aptbin;
our $sudobin;
our $chmodbin;
our $ptablerows;
our $answer;
our $pid;
our @tsets;
our $startpsection;
our $btn1;
our $btn2;

##########################################################################
# Read Settings
##########################################################################

# Version of this script
$version = "0.0.6";

$cfg             = new Config::Simple("$home/config/system/general.cfg");
$installfolder   = $cfg->param("BASE.INSTALLFOLDER");
$lang            = $cfg->param("BASE.LANG");
$unzipbin        = $cfg->param("BINARIES.UNZIP");
$bashbin         = $cfg->param("BINARIES.BASH");
$aptbin          = $cfg->param("BINARIES.APT");
$sudobin         = $cfg->param("BINARIES.SUDO");
$chmodbin        = $cfg->param("BINARIES.CHMOD");

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
$pid          = $query{'pid'};

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
$phrase = new Config::Simple($languagefile);

##########################################################################
# Main program
##########################################################################

# Clean up old files
system("rm -r -f /tmp/uploads/");

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

# Installation
elsif ($do eq "uninstall") {
  &uninstall;
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

$template_title = $phrase->param("TXT0000") . ": " . $phrase->param("TXT0043");
$help = "plugin";

# Create table rows for each Plugin entry
$ptablerows = "";
$i = 1;
open(F,"<$installfolder/data/system/plugindatabase.dat");
  @data = <F>;
  foreach (@data){
    s/[\n\r]//g;
    # Comments
    if ($_ =~ /^\s*#.*/) {
      print F "$_\n";
      next;
    }
    @fields = split(/\|/);
    $pmd5checksum = @fields[0];
    $pname = @fields[4];
    $btn1 = $phrase->param("TXT0101");
    $btn2 = $phrase->param("TXT0102");
    $ptablerows = $ptablerows . "<tr><th>$i</th><td>@fields[6]</td><td>@fields[3]</td><td>@fields[1]</td>";
    $ptablerows = $ptablerows . "<td><a data-role=\"button\" data-inline=\"true\" data-icon=\"info\" data-mini=\"true\" href=\"/admin/system/tools/logfile.cgi?logfile=system/plugininstall/$pname.log&header=html&format=template\" target=\"_blank\">$btn1</a>&nbsp;";
    $ptablerows = $ptablerows . "<a data-role=\"button\" data-inline=\"true\" data-icon=\"delete\" data-mini=\"true\" href=\"/admin/system/plugininstall.cgi?do=uninstall&pid=$pmd5checksum\">$btn2</a></td></tr>\n";
    $i++;
  }
close (F);

# Print Template
&header;
open(F,"$installfolder/templates/system/$lang/plugininstall_menu.html") || die "Missing template system/$lang/plugininstall_menu.html";
  while (<F>) {
    $_ =~ s/<!--\$(.*?)-->/${$1}/g;
    print $_;
  }
close(F);
&footer;

exit;

}

#####################################################
# Uninstall
#####################################################

sub uninstall {

# Question: Are you sure?
if ($answer ne "yes") {

  # Search for Plugin
  open(F,"<$installfolder/data/system/plugindatabase.dat");
    @data = <F>;
    foreach (@data){
      s/[\n\r]//g;
      # Comments
      if ($_ =~ /^\s*#.*/) {
        print F "$_\n";
        next;
      }
      @fields = split(/\|/);
      if ($pid eq @fields[0]) {
        $ptitle = @fields[6];
      }
    }
  close (F);

  if (!$ptitle) {
    $error = $phrase->param("TXT0096");
    &error;
    exit;
  }

  # Print Template
  print "Content-Type: text/html\n\n";

  $template_title = $phrase->param("TXT0000") . ": " . $phrase->param("TXT0043");
  $help = "plugin";

  # Print Template
  &header;
  open(F,"$installfolder/templates/system/$lang/plugininstall_uninstall.html") || die "Missing template system/$lang/plugininstall_uninstall.html";
    while (<F>) {
      $_ =~ s/<!--\$(.*?)-->/${$1}/g;
      print $_;
    }
  close(F);
  &footer;

  exit;

}

# Do Uninstallation
# Search for Plugin
open(F,"<$installfolder/data/system/plugindatabase.dat");
  @data = <F>;
  foreach (@data){
    s/[\n\r]//g;
    # Comments
    if ($_ =~ /^\s*#.*/) {
      print F "$_\n";
      next;
    }
    @fields = split(/\|/);
    if ($pid eq @fields[0]) {
      $pname   = @fields[4];
      $pfolder = @fields[5];
      $ptitle  = @fields[6];
    }
  }
close (F);

if (!$ptitle) {
  $error = $phrase->param("TXT0096");
  &error;
  exit;
}

# Purge old installation
# Plugin Folders
system("rm -r -f $home/config/plugins/$pfolder/");
system("rm -r -f $home/data/plugins/$pfolder/");
system("rm -r -f $home/log/plugins/$pfolder/");
system("rm -r -f $home/webfrontend/cgi/plugins/$pfolder/");
system("rm -r -f $home/webfrontend/html/plugins/$pfolder/");
system("rm -r -f $home/templates/plugins/$pfolder/");
# Icons for Main Menu
system("rm -r -f $home/webfrontend/html/system/images/icons/$pfolder/");
# Daemon file
system("rm -f $home/system/daemons/plugins/$pname");
# Cron jobs
system("rm -f $home/system/cron/cron.01min/$pname");
system("rm -f $home/system/cron/cron.03min/$pname");
system("rm -f $home/system/cron/cron.05min/$pname");
system("rm -f $home/system/cron/cron.10min/$pname");
system("rm -f $home/system/cron/cron.15min/$pname");
system("rm -f $home/system/cron/cron.30min/$pname");
system("rm -f $home/system/cron/cron.hourly/$pname");
system("rm -f $home/system/cron/cron.daily/$pname");
system("rm -f $home/system/cron/cron.weekly/$pname");
system("rm -f $home/system/cron/cron.monthly/$pname");
system("rm -f $home/system/cron/cron.yearly/$pname");

# Clean Database
open(F,"+<$installfolder/data/system/plugindatabase.dat");
  @data = <F>;
  seek(F,0,0);
  truncate(F,0);
  foreach (@data){
    s/[\n\r]//g;
    # Comments
    if ($_ =~ /^\s*#.*/) {
      print F "$_\n";
      next;
    }
    @fields = split(/\|/);
    if (@fields[0] eq $pid) {
      next;
    } else {
      print F "$_\n";
    }
  }
close (F);

# Updating header files for side menu
opendir(DIR, "$installfolder/templates/system");
  @data = readdir(DIR);
closedir(DIR);
foreach(@data) {
  if (-d "$installfolder/templates/system/$_" && $_ ne "." && $_ ne "..") {
    push (@tsets,$_);
  }
}
foreach (@tsets) {
  $startpsection = 0;
  open(F,"+<$installfolder/templates/system/$_/header.html");
    @data = <F>;
    seek(F,0,0);
    truncate(F,0);
    foreach (@data){
      s/[\n\r]//g;
      if ($_ =~ /ENDPLUGINSHERE/) {
        $startpsection = 0;
      }
      if ($_ =~ /STARTPLUGINSHERE/) {
        $startpsection = 1;
        print F "$_\n";
        open(F1,"<$installfolder/data/system/plugindatabase.dat");
          @data1 = <F1>;
          foreach (@data1){
            s/[\n\r]//g;
            # Comments
            if ($_ =~ /^\s*#.*/) {
              next;
            }
            @fields = split(/\|/);
            print F "<li><a href=\"/admin/plugins/@fields[5]/index.cgi\">@fields[6]</a></li>\n";
          }
        close (F1);
      }
      if (!$startpsection) {
        print F "$_\n";
      }
    } 
  close (F);
}

# Print Template
print "Content-Type: text/html\n\n";

$template_title = $phrase->param("TXT0000") . ": " . $phrase->param("TXT0043");
$help = "plugin";

$nexturl = "/admin/system/plugininstall.cgi?do=form";
$message = $phrase->param("TXT0097");

# Print Template
&header;
open(F,"$installfolder/templates/system/$lang/success.html") || die "Missing template system/$lang/success.html";
  while (<F>) {
    $_ =~ s/<!--\$(.*?)-->/${$1}/g;
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
$max_filesize = 50000;

# Filter Backslashes
$uploadfile =~ s/.*[\/\\](.*)/$1/;

# Filesize
$filesize = -s $uploadfile;
$filesize /= 1000;

# If it's larger than allowed...
if ($filesize > $max_filesize) {
  $error = $phrase->param("TXT0045");
  &error;
  exit;
}

# Test if filetype is allowed
if($uploadfile !~ /^.+\.($allowed_filetypes)/) {
  $error = $phrase->param("TXT0046");
  &error;
  exit;
}

# Create upload folder
make_path("/tmp/uploads/$tempfolder" , {chmod => 0777});

# Create status and logfile
if (-e "/tmp/uploads/$tempfile.status" || -e "/tmp/uploads/$tempfile.status") {
  $error = $phrase->param("TXT0047");
  &error;
}
open F, ">/tmp/uploads/$tempfile.status";
  print F "1";
close F;
open F, ">/tmp/uploads/$tempfile.log";
  print F "";
close F;
$statusfile = "/tmp/uploads/$tempfile.status";
$statusfileurl = "uploads/$tempfile.status";
$logfile = "/tmp/uploads/$tempfile.log";
$logfileurl = "uploads/$tempfile.log";

# Header
print "Content-Type: text/html\n\n";

$template_title = $phrase->param("TXT0000") . ": " . $phrase->param("TXT0043");
$help = "plugin";

$nexturl = "/admin/index.cgi";

# Print Template
&header;
open(F,"$installfolder/templates/system/$lang/plugininstall_install.html") || die "Missing template system/$lang/plugininstall_install.html";
  while (<F>) {
    $_ =~ s/<!--\$(.*?)-->/${$1}/g;
    print $_;
  }
close(F);
&footer;

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

  # Starting
  $message = $phrase->param("TXT0051");
  &loginfo;

  # We are careful, so test if file and/or dir already exists
  if (-e "/tmp/uploads/$tempfolder/$tempfile.zip") {
    $message = $phrase->param("TXT0047");
    &logfail;
  } else {
    # Write Uploadfile
    $openerr = 0;
    open UPLOADFILE, ">/tmp/uploads/$tempfolder/$tempfile.zip" or ($openerr = 1);
    binmode $uploadfile;
    while ( <$uploadfile> ) {
      print UPLOADFILE;
    }
    close UPLOADFILE;
    if ($openerr) {
      $message = $phrase->param("TXT0047");
      &logfail;
    } else {
      $message = $phrase->param("TXT0053");
      &logok;
    }
  }

  # UnZipping
  $message = $phrase->param("TXT0052");
  &loginfo;

  $message = "Command: $unzipbin -d /tmp/uploads/$tempfolder /tmp/uploads/$tempfolder/$tempfile.zip";
  &loginfo;

  system("$unzipbin -d /tmp/uploads/$tempfolder /tmp/uploads/$tempfolder/$tempfile.zip 2>&1");
  if ($? ne 0) {
    $message = $phrase->param("TXT0044");
    &logfail; 
  } else {
    $message = $phrase->param("TXT0054");
    &logok;
  }

  # Check for plugin.cfg
  if (!-f "/tmp/uploads/$tempfolder/plugin.cfg") {
    $exists = 0;
    opendir(DIR, "/tmp/uploads/$tempfolder");
      @data = readdir(DIR);
    closedir(DIR);
    foreach(@data) {
      if (-f "/tmp/uploads/$tempfolder/$_/plugin.cfg" && $_ ne "." && $_ ne "..") {
        $tempfolder = $tempfolder . "/$_";
        $exists = 1;
        last;
      }
    }
    if (!$exists) {
      $message = $phrase->param("TXT0048");
      &logfail;
      exit;
    }
  }

  # Read Plugin-Config
  $pcfg             = new Config::Simple("/tmp/uploads/$tempfolder/plugin.cfg");
  $pauthorname      = $pcfg->param("AUTHOR.NAME");
  $pauthoremail     = $pcfg->param("AUTHOR.EMAIL");
  $pversion         = $pcfg->param("PLUGIN.VERSION");
  $pname            = $pcfg->param("PLUGIN.NAME");
  $ptitle           = $pcfg->param("PLUGIN.TITLE");
  $pfolder          = $pcfg->param("PLUGIN.FOLDER");
  $pinterface       = $pcfg->param("SYSTEM.INTERFACE");

  # Filter
  quotemeta($pauthorname);
  quotemeta($pauthoremail);
  quotemeta($pversion);
  quotemeta($pname);
  quotemeta($ptitle);
  quotemeta($pfolder);
  quotemeta($pinterface);
  $pname =~ tr/A-Za-z0-9_-//cd;
  $pfolder =~ tr/A-Za-z0-9_-//cd;
  if (length($ptitle) > 25) {
    $ptitle = substr($ptitle,0,22);
    $ptitle = $ptitle . "...";
  }

  $message = "Author:    $pauthorname";
  &loginfo;
  $message = "Email:     $pauthoremail";
  &loginfo;
  $message = "Version:   $pversion";
  &loginfo;
  $message = "Name:      $pname";
  &loginfo;
  $message = "Folder:    $pfolder";
  &loginfo;
  $message = "Title:     $ptitle";
  &loginfo;
  $message = "Interface: $pinterface";
  &loginfo;

  if (!$pauthorname || !$pauthoremail || !$pversion || !$pname || !$ptitle ||
  !$pfolder || !$pinterface) {
    $message = $phrase->param("TXT0049");
    &logfail;
  }  else {
    $message = $phrase->param("TXT0055");
    &logok;
  }
  # Create MD5 Checksum
  $pmd5checksum = md5_hex(encode_utf8("$pauthorname$pauthoremail$pname$pfolder"));

  # Read Plugin Database
  $openerr = 0;
  if (!-e "$installfolder/data/system/plugindatabase.dat") {
    $message = $phrase->param("TXT0056");
    &logfail;
  }
  $isupgrade = 0;
  open(F,"+<$installfolder/data/system/plugindatabase.dat") or ($openerr = 1);
    if ($openerr) {
      $message = $phrase->param("TXT0056");
      &logfail;
    }
    @data = <F>;
    seek(F,0,0);
    truncate(F,0);
    foreach (@data){
      s/[\n\r]//g;
      # Comments
      if ($_ =~ /^\s*#.*/) {
        print F "$_\n";
        next;
      }
      @fields = split(/\|/);
      # If this is an upgrade use existing data
      if (@fields[0] eq $pmd5checksum) {
        $isupgrade = 1;
        print F "@fields[0]|@fields[1]|@fields[2]|$pversion|@fields[4]|@fields[5]|$ptitle|$pinterface\n";
        $pname = @fields[4];
        $pfolder = @fields[5];
        $message = $phrase->param("TXT0057");
        &loginfo;
      } else {
        print F "$_\n";
        push(@pnames,@fields[4]);
        push(@pfolders,@fields[5]);
      }
    }
    # If it is a new installation, make a new databaseentry
    if (!$isupgrade) {
      # Find "free" folder and name
      $exists = 0;
      for ($i=0;$i<=100;$i++){
        foreach (@pnames) {
          if ( ($_ eq $pname && $i == 1) || $_ eq $pname.sprintf("%02d", $i)) {
            $exists = 1;
          }
        }
        if (!$exists) {
          last;
        } else {
          $exists = 0;
        }
      }
      if ($i1 > 0) {
        $pname = $pname.sprintf("%02d", $i);
      }
      $exists = 0;
      for ($i1=0;$i1<=100;$i1++){
        foreach (@pfolders) {
          if ( ($_ eq $pfolder && $i1 == 1) || $_ eq $pfolder.sprintf("%02d", $i1)) {
            $exists = 1;
          }
        }
        if (!$exists) {
          last;
        } else {
          $exists = 0;
        }
      }
      if ($i1 > 0) {
        $pfolder = $pfolder.sprintf("%02d", $i1);
      }
      # Ok?
      if ($i < 100 && $i1 < 100) {
        $message = $phrase->param("TXT0058");
        &logok;
        $message = $phrase->param("TXT0060") . " $pname";
        &loginfo;
        $message = $phrase->param("TXT0061") . " $pfolder";
        &loginfo;
      } else {
        $message = $phrase->param("TXT0059");
        &logfail;
      }
      print F "$pmd5checksum|$pauthorname|$pauthoremail|$pversion|$pname|$pfolder|$ptitle|$pinterface\n";
    }
  close (F);

  # Starting installation

  # Executing preupgrade script
  if ($isupgrade) {
    if (-f "/tmp/uploads/$tempfolder/preupgrade.sh") {
      $message = $phrase->param("TXT0062");
      &loginfo;

      $message = "Command: $bashbin \"/tmp/uploads/$tempfolder/preupgrade.sh\" \"$tempfolder\" \"$pname\" \"$pfolder\" \"$pversion\" \"$installfolder\"";
      &loginfo;

      system("$bashbin \"/tmp/uploads/$tempfolder/preupgrade.sh\" \"$tempfolder\" \"$pname\" \"$pfolder\" \"$pversion\" \"$installfolder\" 2>&1");
      if ($? ne 0) {
        $message = $phrase->param("TXT0064");
        &logerr; 
      } else {
        $message = $phrase->param("TXT0063");
        &logok;
      }
    }
    # Purge old installation
    $message = $phrase->param("TXT0087");
    &loginfo;
    # Plugin Folders
    system("rm -r -f $home/config/plugins/$pfolder/ 2>&1");
    system("rm -r -f $home/data/plugins/$pfolder/ 2>&1");
    system("rm -r -f $home/templates/$pfolder/ 2>&1");
    # system("rm -r -f $home/log/plugins/$pfolder/"); 		# Don't ourge Logfolder in case of an upgrade
    system("rm -r -f $home/webfrontend/cgi/plugins/$pfolder/ 2>&1");
    system("rm -r -f $home/webfrontend/html/plugins/$pfolder/ 2>&1");
    # Icons for Main Menu
    system("rm -r -f $home/webfrontend/html/system/images/icons/$pfolder/ 2>&1");
    # Daemon file
    system("rm -f $home/system/daemons/plugins/$pname 2>&1");
    # Cron jobs
    system("rm -f $home/system/cron/cron.01min/$pname 2>&1");
    system("rm -f $home/system/cron/cron.03min/$pname 2>&1");
    system("rm -f $home/system/cron/cron.05min/$pname 2>&1");
    system("rm -f $home/system/cron/cron.10min/$pname 2>&1");
    system("rm -f $home/system/cron/cron.15min/$pname 2>&1");
    system("rm -f $home/system/cron/cron.30min/$pname 2>&1");
    system("rm -f $home/system/cron/cron.hourly/$pname 2>&1");
    system("rm -f $home/system/cron/cron.daily/$pname 2>&1");
    system("rm -f $home/system/cron/cron.weekly/$pname 2>&1");
    system("rm -f $home/system/cron/cron.monthly/$pname 2>&1");
    system("rm -f $home/system/cron/cron.yearly/$pname 2>&1");
  }

  # Executing preinstall script
  if (-f "/tmp/uploads/$tempfolder/preinstall.sh") {
    $message = $phrase->param("TXT0066");
    &loginfo;

    $message = "Command: $bashbin \"/tmp/uploads/$tempfolder/preinstall.sh\" \"$tempfolder\" \"$pname\" \"$pfolder\" \"$pversion\" \"$installfolder\"";
    &loginfo;

    system("$bashbin \"/tmp/uploads/$tempfolder/preinstall.sh\" \"$tempfolder\" \"$pname\" \"$pfolder\" \"$pversion\" \"$installfolder\" 2>&1");
    if ($? ne 0) {
      $message = $phrase->param("TXT0064");
      &logerr; 
    } else {
      $message = $phrase->param("TXT0063");
      &logok;
    }
  }  

  # Copy Config files
  make_path("$home/config/plugins/$pfolder" , {chmod => 0777});
  if (!&is_folder_empty("/tmp/uploads/$tempfolder/config")) {
    $message = $phrase->param("TXT0068");
    &loginfo;
    system("cp -r -v /tmp/uploads/$tempfolder/config/* $home/config/plugins/$pfolder/ 2>&1");
    if ($? ne 0) {
      $message = $phrase->param("TXT0070");
      &logerr; 
    } else {
      $message = $phrase->param("TXT0069");
      &logok;
    }
  }

  # Copy Template files
  make_path("$home/templates/plugins/$pfolder" , {chmod => 0777});
  if (!&is_folder_empty("/tmp/uploads/$tempfolder/templates")) {
    $message = $phrase->param("TXT0098");
    &loginfo;
    system("cp -r -v /tmp/uploads/$tempfolder/templates/* $home/templates/plugins/$pfolder/ 2>&1");
    if ($? ne 0) {
      $message = $phrase->param("TXT0070");
      &logerr; 
    } else {
      $message = $phrase->param("TXT0069");
      &logok;
    }
  }

  # Copy Daemon file
  if (-f "/tmp/uploads/$tempfolder/daemon/daemon") {
    $message = $phrase->param("TXT0071");
    &loginfo;
    system("cp -r -v /tmp/uploads/$tempfolder/daemon/daemon $home/system/daemons/plugins/$pname 2>&1");
    if ($? ne 0) {
      $message = $phrase->param("TXT0070");
      &logerr; 
    } else {
      $message = $phrase->param("TXT0069");
      &logok;
    }
    $message = $phrase->param("TXT0091") . " $chmodbin 755 $home/system/daemons/plugins/$pname";
    &loginfo;
    system("$chmodbin 755 $home/system/daemons/plugins/$pname 2>&1");
    if ($? ne 0) {
      $message = $phrase->param("TXT0093");
      &logerr; 
    } else {
      $message = $phrase->param("TXT0092");
      &logok;
    }
  }

  # Copy Cron files
  if (!&is_folder_empty("/tmp/uploads/$tempfolder/cron")) {
    $message = $phrase->param("TXT0088");
    &loginfo;
    $openerr = 0;
    if (-e "/tmp/uploads/$tempfolder/cron/cron.01min") {
      system("cp -r -v /tmp/uploads/$tempfolder/cron/cron.01min $home/system/cron/cron.01min/$pname 2>&1");
      if ($? ne 0) {
        $openerr = 1;
      }
    } 
    if (-e "/tmp/uploads/$tempfolder/cron/cron.03min") {
      system("cp -r -v /tmp/uploads/$tempfolder/cron/cron.03min $home/system/cron/cron.03min/$pname 2>&1");
      if ($? ne 0) {
        $openerr = 1;
      }
    } 
    if (-e "/tmp/uploads/$tempfolder/cron/cron.05min") {
      system("cp -r -v /tmp/uploads/$tempfolder/cron/cron.05min $home/system/cron/cron.05min/$pname 2>&1");
      if ($? ne 0) {
        $openerr = 1;
      }
    } 
    if (-e "/tmp/uploads/$tempfolder/cron/cron.10min") {
      system("cp -r -v /tmp/uploads/$tempfolder/cron/cron.10min $home/system/cron/cron.10min/$pname 2>&1");
      if ($? ne 0) {
        $openerr = 1;
      }
    } 
    if (-e "/tmp/uploads/$tempfolder/cron/cron.15min") {
      system("cp -r -v /tmp/uploads/$tempfolder/cron/cron.15min $home/system/cron/cron.15min/$pname 2>&1");
      if ($? ne 0) {
        $openerr = 1;
      }
    } 
    if (-e "/tmp/uploads/$tempfolder/cron/cron.30min") {
      system("cp -r -v /tmp/uploads/$tempfolder/cron/cron.30min $home/system/cron/cron.30min/$pname 2>&1");
      if ($? ne 0) {
        $openerr = 1;
      }
    } 
    if (-e "/tmp/uploads/$tempfolder/cron/cron.hourly") {
      system("cp -r -v /tmp/uploads/$tempfolder/cron/cron.hourly $home/system/cron/cron.hourly/$pname 2>&1");
      if ($? ne 0) {
        $openerr = 1;
      }
    } 
    if (-e "/tmp/uploads/$tempfolder/cron/cron.daily") {
      system("cp -r -v /tmp/uploads/$tempfolder/cron/cron.daily $home/system/cron/cron.daily/$pname 2>&1");
      if ($? ne 0) {
        $openerr = 1;
      }
    } 
    if (-e "/tmp/uploads/$tempfolder/cron/cron.weekly") {
      system("cp -r -v /tmp/uploads/$tempfolder/cron/cron.weekly01 $home/system/cron/cron.weekly/$pname 2>&1");
      if ($? ne 0) {
        $openerr = 1;
      }
    } 
    if (-e "/tmp/uploads/$tempfolder/cron/cron.monthly") {
      system("cp -r -v /tmp/uploads/$tempfolder/cron/cron.monthly $home/system/cron/cron.monthly/$pname 2>&1");
      if ($? ne 0) {
        $openerr = 1;
      }
    } 
    if (-e "/tmp/uploads/$tempfolder/cron/cron.yearly") {
      system("cp -r -v /tmp/uploads/$tempfolder/cron/cron.yearly $home/system/cron/cron.yearly/$pname 2>&1");
      if ($? ne 0) {
        $openerr = 1;
      }
    } 
    if ($openerr) {
      $message = $phrase->param("TXT0089");
      &logerr; 
    } else {
      $message = $phrase->param("TXT0090");
      &logok;
    }
    $message = $phrase->param("TXT0091") . " $chmodbin -R 755 $home/system/cron/";
    &loginfo;
    system("$chmodbin -R 755 $home/system/cron/ 2>&1");
    if ($? ne 0) {
      $message = $phrase->param("TXT0093");
      &logerr; 
    } else {
      $message = $phrase->param("TXT0092");
      &logok;
    }
  }

  # Copy Data files
  make_path("$home/data/plugins/$pfolder" , {chmod => 0777});
  if (!&is_folder_empty("/tmp/uploads/$tempfolder/data")) {
    $message = $phrase->param("TXT0072");
    &loginfo;
    system("cp -r -v /tmp/uploads/$tempfolder/data/* $home/data/plugins/$pfolder/ 2>&1");
    if ($? ne 0) {
      $message = $phrase->param("TXT0070");
      &logerr; 
    } else {
      $message = $phrase->param("TXT0069");
      &logok;
    }
  }

  # Copy Log files
  make_path("$home/log/plugins/$pfolder" , {chmod => 0777});
  if (!&is_folder_empty("/tmp/uploads/$tempfolder/log")) {
    $message = $phrase->param("TXT0073");
    &loginfo;
    system("cp -r -v /tmp/uploads/$tempfolder/log/* $home/log/plugins/$pfolder/ 2>&1");
    if ($? ne 0) {
      $message = $phrase->param("TXT0070");
      &logerr; 
    } else {
      $message = $phrase->param("TXT0069");
      &logok;
    }
  }

  # Copy CGI files
  make_path("$home/webfrontend/cgi/plugins/$pfolder" , {chmod => 0777});
  if (!&is_folder_empty("/tmp/uploads/$tempfolder/webfrontend/cgi")) {
    $message = $phrase->param("TXT0074");
    &loginfo;
    system("cp -r -v /tmp/uploads/$tempfolder/webfrontend/cgi/* $home/webfrontend/cgi/plugins/$pfolder/ 2>&1");
    if ($? ne 0) {
      $message = $phrase->param("TXT0070");
      &logerr; 
    } else {
      $message = $phrase->param("TXT0069");
      &logok;
    }
    $message = $phrase->param("TXT0091") . " $chmodbin -R 755 $home/webfrontend/cgi/plugins/$pfolder/";
    &loginfo;
    system("$chmodbin -R 755 $home/webfrontend/cgi/plugins/$pfolder/ 2>&1");
    if ($? ne 0) {
      $message = $phrase->param("TXT0093");
      &logerr; 
    } else {
      $message = $phrase->param("TXT0092");
      &logok;
    }
  }

  # Copy HTML files
  make_path("$home/webfrontend/html/plugins/$pfolder" , {chmod => 0777});
  if (!&is_folder_empty("/tmp/uploads/$tempfolder/webfrontend/html")) {
    $message = $phrase->param("TXT0075");
    &loginfo;
    system("cp -r -v /tmp/uploads/$tempfolder/webfrontend/html/* $home/webfrontend/html/plugins/$pfolder/ 2>&1");
    if ($? ne 0) {
      $message = $phrase->param("TXT0070");
      &logerr; 
    } else {
      $message = $phrase->param("TXT0069");
      &logok;
    }
  }

  # Copy Icon files
  make_path("$home/webfrontend/html/system/images/icons/$pfolder" , {chmod => 0777});
  $message = $phrase->param("TXT0084");
  &loginfo;
  system("cp -r -v /tmp/uploads/$tempfolder/icons/* $home/webfrontend/html/system/images/icons/$pfolder/ 2>&1");
  if ($? ne 0) {
    system("cp -r -v $home/webfrontend/html/system/images/icons/default/* $home/webfrontend/html/system/images/icons/$pfolder/ 2>&1");
    $message = $phrase->param("TXT0085");
    &logerr; 
  } else {
    $openerr = 0;
    if (!-e "$home/webfrontend/html/system/images/icons/$pfolder/icon_64.png") {
      $openerr = 1;
      system("cp -r -v $home/webfrontend/html/system/images/icons/default/icon_64.png $home/webfrontend/html/system/images/icons/$pfolder/ 2>&1");
    } 
    if (!-e "$home/webfrontend/html/system/images/icons/$pfolder/icon_128.png") {
      $openerr = 1;
      system("cp -r -v $home/webfrontend/html/system/images/icons/default/icon_128.png $home/webfrontend/html/system/images/icons/$pfolder/ 2>&1");
    } 
    if (!-e "$home/webfrontend/html/system/images/icons/$pfolder/icon_256.png") {
      $openerr = 1;
      system("cp -r -v $home/webfrontend/html/system/images/icons/default/icon_256.png $home/webfrontend/html/system/images/icons/$pfolder/ 2>&1");
    } 
    if (!-e "$home/webfrontend/html/system/images/icons/$pfolder/icon_512.png") {
      $openerr = 1;
      system("cp -r -v $home/webfrontend/html/system/images/icons/default/icon_512.png $home/webfrontend/html/system/images/icons/$pfolder/ 2>&1");
    } 
    if ($openerr) {
      $message = $phrase->param("TXT0085");
      &logerr;
    } else { 
      $message = $phrase->param("TXT0086");
      &logok;
    }
  }

  # Installing additional packages
  if (-e "/tmp/uploads/$tempfolder/apt") {
    $message = $phrase->param("TXT0081");
    &loginfo;
    $message = "Command: $sudobin $aptbin -q -y update";
    &loginfo;
    system("$sudobin $aptbin -q -y update 2>&1");
    if ($? ne 0) {
      $message = $phrase->param("TXT0082");
      &logerr; 
    } else {
      $message = $phrase->param("TXT0083");
      &logok;
    }
    $message = $phrase->param("TXT0078");
    &loginfo;
    $openerr = 0;
    open(F,"</tmp/uploads/$tempfolder/apt") or ($openerr = 1);
      if ($openerr) {
        $message = $phrase->param("TXT0077");
        &logerr;
      }
    @data = <F>;
    foreach (@data){
      s/[\n\r]//g;
      # Comments
      if ($_ =~ /^\s*#.*/) {
        next;
      }
      $message = "Command: $sudobin $aptbin -q -y install $_";
      &loginfo;
      system("$sudobin $aptbin -q -y install $_ 2>&1");
      if ($? ne 0) {
        $message = $phrase->param("TXT0079");
        &logerr; 
      } else {
        $message = $phrase->param("TXT0080");
        &logok;
      }
    }
    close (F)
  }

  # Executing postinstall script
  if (-f "/tmp/uploads/$tempfolder/postinstall.sh") {
    $message = $phrase->param("TXT0067");
    &loginfo;

    $message = "Command: $bashbin \"/tmp/uploads/$tempfolder/postinstall.sh\" \"$tempfolder\" \"$pname\" \"$pfolder\" \"$pversion\" \"$installfolder\"";
    &loginfo;

    system("$bashbin \"/tmp/uploads/$tempfolder/postinstall.sh\" \"$tempfolder\" \"$pname\" \"$pfolder\" \"$pversion\" \"$installfolder\" 2>&1");
    if ($? ne 0) {
      $message = $phrase->param("TXT0064");
      &logerr; 
    } else {
      $message = $phrase->param("TXT0063");
      &logok;
    }
  }

  # Executing postupgrade script
  if ($isupgrade) {
    if (-f "/tmp/uploads/$tempfolder/postupgrade.sh") {
      $message = $phrase->param("TXT0065");
      &loginfo;

      $message = "Command: $bashbin \"/tmp/uploads/$tempfolder/postupgrade.sh\" \"$tempfolder\" \"$pname\" \"$pfolder\" \"$pversion\" \"$installfolder\"";
      &loginfo;

      system("$bashbin \"/tmp/uploads/$tempfolder/postupgrade.sh\" \"$tempfolder\" \"$pname\" \"$pfolder\" \"$pversion\" \"$installfolder\" 2>&1");
      if ($? ne 0) {
        $message = $phrase->param("TXT0064");
        &logerr; 
      } else {
        $message = $phrase->param("TXT0063");
        &logok;
      }
    }
  }

  # Updating header files for side menu
  $message = $phrase->param("TXT0099");
  &loginfo;

  # Sorting Plugin Database
  &sort_plugins;

  opendir(DIR, "$installfolder/templates/system");
    @data = readdir(DIR);
  closedir(DIR);
  foreach(@data) {
    if (-d "$installfolder/templates/system/$_" && $_ ne "." && $_ ne "..") {
      push (@tsets,$_);
    }
  }
  foreach (@tsets) {
    $startpsection = 0;
    open(F,"+<$installfolder/templates/system/$_/header.html");
      @data = <F>;
      seek(F,0,0);
      truncate(F,0);
      foreach (@data){
        s/[\n\r]//g;
        if ($_ =~ /ENDPLUGINSHERE/) {
          $startpsection = 0;
        }
        if ($_ =~ /STARTPLUGINSHERE/) {
          $startpsection = 1;
          print F "$_\n";
          open(F1,"<$installfolder/data/system/plugindatabase.dat");
            @data1 = <F1>;
            foreach (@data1){
              s/[\n\r]//g;
              # Comments
              if ($_ =~ /^\s*#.*/) {
                next;
              }
              @fields = split(/\|/);
              print F "<li><a href=\"/admin/plugins/@fields[5]/index.cgi\">@fields[6]</a></li>\n";
            }
          close (F1);
        }
        if (!$startpsection) {
          print F "$_\n";
        }
      } 
    close (F);
  }
  $message = $phrase->param("TXT0100");
  &logok;

  # Cleaning
  $message = $phrase->param("TXT0095");
  &loginfo;
  system("rm -r -f /tmp/uploads/$pfolder 2>&1");
  system("cp /tmp/uploads/$tempfile.log $installfolder/log/system/plugininstall/$pname.log 2>&1");

  # Finished
  $message = $phrase->param("TXT0094");
  &logok;
  open F, ">/tmp/uploads/$tempfile.status";
    print F "0";
  close F;

# End Child process
}

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
# Logging installation
#####################################################

sub logerr {

  print "<ERROR> $message\n";
  return();

}

sub logfail {

  print "<FAIL> $message\n";

  # Status file: Error
  open F, ">/tmp/uploads/$tempfile.status";
    print F "2";
  close F;

  exit;

}

sub loginfo {

  print "<INFO> $message\n";
  return();

}

sub logok {

  print "<OK> $message\n";
  return();

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

#####################################################
# Sorting Plugin Database
#####################################################

sub sort_plugins {
  # Einlesen
  my @zeilen=();
  my $input_file="$installfolder/data/system/plugindatabase.dat";
  open (F, '<', $input_file) or die "Fehler bei open($input_file) : $!";
  while(<F>)
  {
     chomp($_ );
     push @zeilen, [ split /\|/, $_, 9 ];
  }
  close (F);

  # Sortieren
  my $first_line=shift(@zeilen);
  @zeilen=sort{$a->[6] cmp $b->[6]}@zeilen; 
  unshift(@zeilen, $first_line);

  # Ausgeben    
  open(F,"+<$installfolder/data/system/plugindatabase.dat");
  @data = <F>;
  seek(F,0,0);
  truncate(F,0);
  print F join('|', @{$_}), "\n" for @zeilen;   #sortiert wieder ausgeben
  close (F);
  return();
}
