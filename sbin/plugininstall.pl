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
our $lang;
our $installfolder;
our $languagefile;
our $version;
our $error;
our $output;
our $message;
our $e;
our $tempfolder;
our $pauthorname;
our $pauthoremail;
our $pversion;
our $pname;
our $ptitle;
our $pfolder;
our $pinterface;
our $logfile;
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
$version = "0.0.2";

$cfg             = new Config::Simple("$home/config/system/general.cfg");
$installfolder   = $cfg->param("BASE.INSTALLFOLDER");
$lang            = $cfg->param("BASE.LANG");
$bashbin         = $cfg->param("BINARIES.BASH");
$aptbin          = $cfg->param("BINARIES.APT");
$sudobin         = $cfg->param("BINARIES.SUDO");
$chmodbin        = $cfg->param("BINARIES.CHMOD");

##########################################################################
# Language Settings
##########################################################################

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

#####################################################
# Install
#####################################################

# Check for argument: plugin folder
if (!$ARGV[0]) {
  print "Missing Folder. Usage: $0 FOLDER_WITH_PLUGIN_FILES\n";
  exit;
}
$tempfolder = $ARGV[0];
$tempfolder =~ s/(.*)\/$/$1/eg; # Clean trailing /
if (!-d $tempfolder) {
  $error = "Plugin folder does not exist. Usage: $0 FOLDER_WITH_PLUGIN_FILES\n";
  &error;
}

# Choose random temp filename
$tempfile = &generate(10);

# Create status and logfile
if (-e "$tempfolder/$tempfile.log") {
  $error = $phrase->param("TXT0047");
  &error;
}
open (F, ">$tempfolder/$tempfile.log");
  print F "";
close (F);
$logfile = "$tempfolder/$tempfile.log";

  # Starting
  $message = $phrase->param("TXT0051");
  &loginfo;

  # Check for plugin.cfg
  if (!-f "$tempfolder/plugin.cfg") {
    $exists = 0;
    opendir(DIR, "$tempfolder");
      @data = readdir(DIR);
    closedir(DIR);
    foreach(@data) {
      if (-f "$tempfolder/$_/plugin.cfg" && $_ ne "." && $_ ne "..") {
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
  $pcfg             = new Config::Simple("$tempfolder/plugin.cfg");
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
    if (-f "$tempfolder/preupgrade.sh") {
      $message = $phrase->param("TXT0062");
      &loginfo;

      $message = "Command: $bashbin \"$tempfolder/preupgrade.sh\" \"$tempfolder\" \"$pname\" \"$pfolder\" \"$pversion\" \"$installfolder\"";
      &loginfo;

      system("$bashbin \"$tempfolder/preupgrade.sh\" \"$tempfolder\" \"$pname\" \"$pfolder\" \"$pversion\" \"$installfolder\" 2>&1");
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
  if (-f "$tempfolder/preinstall.sh") {
    $message = $phrase->param("TXT0066");
    &loginfo;

    $message = "Command: $bashbin \"$tempfolder/preinstall.sh\" \"$tempfolder\" \"$pname\" \"$pfolder\" \"$pversion\" \"$installfolder\"";
    &loginfo;

    system("$bashbin \"$tempfolder/preinstall.sh\" \"$tempfolder\" \"$pname\" \"$pfolder\" \"$pversion\" \"$installfolder\" 2>&1");
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
  if (!&is_folder_empty("$tempfolder/config")) {
    $message = $phrase->param("TXT0068");
    &loginfo;
    system("cp -r -v $tempfolder/config/* $home/config/plugins/$pfolder/ 2>&1");
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
  if (!&is_folder_empty("$tempfolder/templates")) {
    $message = $phrase->param("TXT0098");
    &loginfo;
    system("cp -r -v $tempfolder/templates/* $home/templates/plugins/$pfolder/ 2>&1");
    if ($? ne 0) {
      $message = $phrase->param("TXT0070");
      &logerr; 
    } else {
      $message = $phrase->param("TXT0069");
      &logok;
    }
  }

  # Copy Daemon file
  if (-f "$tempfolder/daemon/daemon") {
    $message = $phrase->param("TXT0071");
    &loginfo;
    system("cp -r -v $tempfolder/daemon/daemon $home/system/daemons/plugins/$pname 2>&1");
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

  # Copy Uninstall file
  if (-f "$tempfolder/uninstall/uninstall") {
    $message = $phrase->param("TXT0112");
    &loginfo;
    system("cp -r -v $tempfolder/uninstall/uninstall $home/data/system/uninstall/$pname 2>&1");
    if ($? ne 0) {
      $message = $phrase->param("TXT0070");
      &logerr; 
    } else {
      $message = $phrase->param("TXT0069");
      &logok;
    }
    $message = $phrase->param("TXT0091") . " $chmodbin 755 $home/data/system/uninstall/$pname";
    &loginfo;
    system("$chmodbin 755 $home/data/system/uninstall/$pname 2>&1");
    if ($? ne 0) {
      $message = $phrase->param("TXT0093");
      &logerr; 
    } else {
      $message = $phrase->param("TXT0092");
      &logok;
    }
  }

  # Copy Cron files
  if (!&is_folder_empty("$tempfolder/cron")) {
    $message = $phrase->param("TXT0088");
    &loginfo;
    $openerr = 0;
    if (-e "$tempfolder/cron/cron.01min") {
      system("cp -r -v $tempfolder/cron/cron.01min $home/system/cron/cron.01min/$pname 2>&1");
      if ($? ne 0) {
        $openerr = 1;
      }
    } 
    if (-e "$tempfolder/cron/cron.03min") {
      system("cp -r -v $tempfolder/cron/cron.03min $home/system/cron/cron.03min/$pname 2>&1");
      if ($? ne 0) {
        $openerr = 1;
      }
    } 
    if (-e "$tempfolder/cron/cron.05min") {
      system("cp -r -v $tempfolder/cron/cron.05min $home/system/cron/cron.05min/$pname 2>&1");
      if ($? ne 0) {
        $openerr = 1;
      }
    } 
    if (-e "$tempfolder/cron/cron.10min") {
      system("cp -r -v $tempfolder/cron/cron.10min $home/system/cron/cron.10min/$pname 2>&1");
      if ($? ne 0) {
        $openerr = 1;
      }
    } 
    if (-e "$tempfolder/cron/cron.15min") {
      system("cp -r -v $tempfolder/cron/cron.15min $home/system/cron/cron.15min/$pname 2>&1");
      if ($? ne 0) {
        $openerr = 1;
      }
    } 
    if (-e "$tempfolder/cron/cron.30min") {
      system("cp -r -v $tempfolder/cron/cron.30min $home/system/cron/cron.30min/$pname 2>&1");
      if ($? ne 0) {
        $openerr = 1;
      }
    } 
    if (-e "$tempfolder/cron/cron.hourly") {
      system("cp -r -v $tempfolder/cron/cron.hourly $home/system/cron/cron.hourly/$pname 2>&1");
      if ($? ne 0) {
        $openerr = 1;
      }
    } 
    if (-e "$tempfolder/cron/cron.daily") {
      system("cp -r -v $tempfolder/cron/cron.daily $home/system/cron/cron.daily/$pname 2>&1");
      if ($? ne 0) {
        $openerr = 1;
      }
    } 
    if (-e "$tempfolder/cron/cron.weekly") {
      system("cp -r -v $tempfolder/cron/cron.weekly01 $home/system/cron/cron.weekly/$pname 2>&1");
      if ($? ne 0) {
        $openerr = 1;
      }
    } 
    if (-e "$tempfolder/cron/cron.monthly") {
      system("cp -r -v $tempfolder/cron/cron.monthly $home/system/cron/cron.monthly/$pname 2>&1");
      if ($? ne 0) {
        $openerr = 1;
      }
    } 
    if (-e "$tempfolder/cron/cron.yearly") {
      system("cp -r -v $tempfolder/cron/cron.yearly $home/system/cron/cron.yearly/$pname 2>&1");
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
  if (!&is_folder_empty("$tempfolder/data")) {
    $message = $phrase->param("TXT0072");
    &loginfo;
    system("cp -r -v $tempfolder/data/* $home/data/plugins/$pfolder/ 2>&1");
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
  if (!&is_folder_empty("$tempfolder/log")) {
    $message = $phrase->param("TXT0073");
    &loginfo;
    system("cp -r -v $tempfolder/log/* $home/log/plugins/$pfolder/ 2>&1");
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
  if (!&is_folder_empty("$tempfolder/webfrontend/cgi")) {
    $message = $phrase->param("TXT0074");
    &loginfo;
    system("cp -r -v $tempfolder/webfrontend/cgi/* $home/webfrontend/cgi/plugins/$pfolder/ 2>&1");
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
  if (!&is_folder_empty("$tempfolder/webfrontend/html")) {
    $message = $phrase->param("TXT0075");
    &loginfo;
    system("cp -r -v $tempfolder/webfrontend/html/* $home/webfrontend/html/plugins/$pfolder/ 2>&1");
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
  system("cp -r -v $tempfolder/icons/* $home/webfrontend/html/system/images/icons/$pfolder/ 2>&1");
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
  if (-e "$tempfolder/apt") {

    if (-e "$home/data/system/lastaptupdate.dat") {
      open(F,"<$home/data/system/lastaptupdate.dat");
        $lastaptupdate = <F>;
      close(F);
    } else {
      $lastaptupdate = 0;
    }
    $now = time;
    # If last run of apt-get update is longer than 24h ago, do a refresh.
    if ($now > $lastaptupdate+86400) {
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
        open(F,">$home/data/system/lastaptupdate.dat");
          print F $now;
        close(F);
      }
    }
    $message = $phrase->param("TXT0078");
    &loginfo;
    $openerr = 0;
    open(F,"<$tempfolder/apt") or ($openerr = 1);
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
      $aptpackages = $aptpackages . " " . $_;
    }
    close (F);

    $message = "Command: $sudobin $aptbin -q -y install $aptpackages";
    &loginfo;
    system("$sudobin $aptbin -q -y install $aptpackages 2>&1");
    if ($? ne 0) {
      $message = $phrase->param("TXT0079");
      &logerr; 
      # If it failed, maybe due to an outdateß apt-database... So
      # do a apt-get update once more
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
        open(F,">$home/data/system/lastaptupdate.dat");
          print F $now;
        close(F);
      }
      # And try to install packages again...
      $message = "Command: $sudobin $aptbin -q -y install $aptpackages";
      &loginfo;
      system("$sudobin $aptbin -q -y install $aptpackages 2>&1");
      if ($? ne 0) {
        $message = $phrase->param("TXT0079");
        &logerr; 
      } else {
        $message = $phrase->param("TXT0080");
        &logok;
      }
    } else {
      $message = $phrase->param("TXT0080");
      &logok;
    }

  }

  # Executing postinstall script
  if (-f "$tempfolder/postinstall.sh") {
    $message = $phrase->param("TXT0067");
    &loginfo;

    $message = "Command: $bashbin \"$tempfolder/postinstall.sh\" \"$tempfolder\" \"$pname\" \"$pfolder\" \"$pversion\" \"$installfolder\"";
    &loginfo;

    system("$bashbin \"$tempfolder/postinstall.sh\" \"$tempfolder\" \"$pname\" \"$pfolder\" \"$pversion\" \"$installfolder\" 2>&1");
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
    if (-f "$tempfolder/postupgrade.sh") {
      $message = $phrase->param("TXT0065");
      &loginfo;

      $message = "Command: $bashbin \"$tempfolder/postupgrade.sh\" \"$tempfolder\" \"$pname\" \"$pfolder\" \"$pversion\" \"$installfolder\"";
      &loginfo;

      system("$bashbin \"$tempfolder/postupgrade.sh\" \"$tempfolder\" \"$pname\" \"$pfolder\" \"$pversion\" \"$installfolder\" 2>&1");
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
    open(F,"+<$installfolder/templates/system/$_/header.html") or die "Fehler: $!";
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
          open(F1,"<$installfolder/data/system/plugindatabase.dat") or die "Fehler: $!";
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
  system("cp $tempfolder/$tempfile.log $installfolder/log/system/plugininstall/$pname.log 2>&1");

  # Finished
  $message = $phrase->param("TXT0094");
  &logok;
  system("rm -f $tempfolder/$tempfile.log");

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

print "$error\n\n";
system("rm -f $tempfolder/$tempfile.log");

exit;

}

#####################################################
# Logging installation
#####################################################

sub logerr {

  open (LOG, ">>$logfile");
    print LOG "<ERROR> $message\n";
    print "\e[1m\e[31mERROR:\e[0m $message\n";
  close (LOG);

  return();

}

sub logfail {

  open (LOG, ">>$logfile");
    print LOG "<FAIL> $message\n";
    print "\e[1m\e[31mFAIL:\e[0m $message\n";
  close (LOG);

  exit;

}

sub loginfo {

  open (LOG, ">>$logfile");
    print LOG "<INFO> $message\n";
    print "\e[1mINFO:\e[0m $message\n";
  close (LOG);

  return();

}

sub logok {

  open (LOG, ">>$logfile");
    print LOG "<OK> $message\n";
    print "\e[1m\e[32mOK:\e[0m $message\n";
  close (LOG);

  return();

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
