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

use File::Path qw(make_path remove_tree);
use Digest::MD5 qw(md5_hex);
use Encode qw(encode_utf8);
use LoxBerry::System;
use LoxBerry::Web;
#use warnings;
#use strict;
#no strict "refs"; # we need it for template system

# Version of this script
my $version = "0.0.3";

##########################################################################
# Variables / Commandline
##########################################################################

# Command line options
my $cgi = CGI->new;
$cgi->import_names('R');

##########################################################################
# Read Settings
##########################################################################

#my $cfg             = new Config::Simple("$lbsconfigdir/general.cfg");

my $bins = LoxBerry::System::get_binaries();
my $bashbin         = $bins->{BASH};
my $aptbin          = $bins->{APT};
my $sudobin         = $bins->{SUDO};
my $chmodbin        = $bins->{CHMOD};
my $chownbin        = $bins->{CHOWN};
my $unzipbin        = $bins->{UNZIP};
my $findbin        = $bins->{FIND};

##########################################################################
# Language Settings
##########################################################################

if ($R::lang) {
        # Nice feature: We override language detection of LoxBerry::Web
        $LoxBerry::Web::lang = substr($R::lang, 0, 2);
}
# If we did the 'override', lblanguage will give us that language
my $lang = lblanguage();

# Read phrases from language_LANG.ini
our %SL = LoxBerry::Web::readlanguage(undef);

##########################################################################
# Checks
##########################################################################

my $message;
my @errors;
if ( $R::action ne "install" && $R::action ne "uninstall" ) {
  $message =  "$SL{'PLUGININSTALL.ERR_ACTION'}";
  &logfail;
}
if ( $R::action eq "install" ) {
  if ( (!$R::folder && !$R::file) || ($R::folder && $R::file) ) {
    $message =  "$SL{'PLUGININSTALL.ERR_NOFOLDER_OR_ZIP'}";
    &logfail;
  }
}
# ZIP or Folder mode?
my $zipmode = defined $R::file ? 1 : 0;

# Which Action should be perfomred?
if ($R::action eq "install" ) {
  &install;
}

exit;

#####################################################
# Install
#####################################################

sub install {

# Choose random temp filename
my $tempfile = &generate(10);
if (!$zipmode) { 
  our $tempfolder = $R::folder;
  if (!-e $tempfolder) {
    $message =  "$SL{'PLUGININSTALL.ERR_FOLDER_DOESNT_EXIST'}";
    &logfail;
  }
} else {
  our $tempfolder = "/tmp/$tempfile";
  if (!-e $R::file) {
    $message =  "$SL{'PLUGININSTALL.ERR_FILE_DOESNT_EXIST'}";
    &logfail;
  }
  make_path("$tempfolder" , {chmod => 0755, owner=>'loxberry', group=>'loxberry'});
}
$tempfolder =~ s/(.*)\/$/$1/eg; # Clean trailing /
$message =  "Temp Folder: $tempfolder";
&loginfo;

# Create status and logfile
my $logfile = "/tmp/$tempfile.log";
my $statusfile = "/tmp/$tempfile.status";
if (-e "$logfile" || -e "$statusfile") {
  $message =  "$SL{'PLUGININSTALL.ERR_TEMPFILES_EXISTS'}";
  &logfail;
}
$message =  "Logfile: $logfile";
&loginfo;
open (F, ">$logfile");
  print F "";
close (F);

$message =  "Statusfile: $statusfile";
&loginfo;
open (F, ">$statusfile");
  print F "1";
close (F);

# Starting
$message =  "$SL{'PLUGININSTALL.INF_START'}";
&loginfo;

# UnZipping
if ( $zipmode ) {

  $message =  "$SL{'PLUGININSTALL.INF_EXTRACTING'}";
  &loginfo;

  $message = "Command: $sudobin -n -u loxberry $unzipbin -d $tempfolder $R::file";
  &loginfo;

  system("$sudobin -n -u loxberry $unzipbin -d $tempfolder $R::file 2>&1");
  if ($? ne 0) {
    $message =  "$SL{'PLUGININSTALL.ERR_EXTRACTING'}";
    &logfail;
  } else {
    $message =  "$SL{'PLUGININSTALL.OK_EXTRACTING'}";
    &logok;
  }

}

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
    $message =  "$SL{'PLUGININSTALL.ERR_ARCHIVEFORMAT'}";
    &logfail;
  }
}

# Read Plugin-Config
our $pcfg             = new Config::Simple("$tempfolder/plugin.cfg");
our $pauthorname      = $pcfg->param("AUTHOR.NAME");
our $pauthoremail     = $pcfg->param("AUTHOR.EMAIL");
our $pversion         = $pcfg->param("PLUGIN.VERSION");
our $pname            = $pcfg->param("PLUGIN.NAME");
our $ptitle           = $pcfg->param("PLUGIN.TITLE");
our $pfolder          = $pcfg->param("PLUGIN.FOLDER");
our $pautoupdates     = $pcfg->param("AUTOUPDATE.AUTOMATIC_UPDATES");
our $preleasecfg      = $pcfg->param("AUTOUPDATE.RELEASECFG");
our $pprereleasecfg   = $pcfg->param("AUTOUPDATE.PRERELEASECFG");
our $pinterface       = $pcfg->param("SYSTEM.INTERFACE");
our $preboot          = $pcfg->param("SYSTEM.REBOOT");
our $plbmin           = $pcfg->param("SYSTEM.LB_MINIMUM");
our $plbmax           = $pcfg->param("SYSTEM.LB_MAXIMUM");
our $parch            = $pcfg->param("SYSTEM.ARCHITECTURE");

# Filter
#quotemeta($pauthorname);
#quotemeta($pauthoremail);
#quotemeta($pversion);
#quotemeta($pname);
#quotemeta($ptitle);
#quotemeta($pfolder);
#quotemeta($pinterface);
#quotemeta($pautoupdates);
#quotemeta($preleasecfg);
#quotemeta($pprereleasecfg);
#quotemeta($preboot);
#quotemeta($plbmin);
#quotemeta($plbmax);
#quotemeta($parch);
$pname =~ tr/A-Za-z0-9_-//cd;
$pfolder =~ tr/A-Za-z0-9_-//cd;
if (length($ptitle) > 25) {
  $ptitle = substr($ptitle,0,22);
  $ptitle = $ptitle . "...";
}
if ( $pautoupdates eq "false" || $pautoupdates eq "0" || $preleasecfg eq "" ) {
  $preleasecfg = "";
  $pprereleasecfg = "";
  $pautoupdates = "0";
} else {
  $pautoupdates = "1";
}

$message = "Author:       $pauthorname";
&loginfo;
$message = "Email:        $pauthoremail";
&loginfo;
$message = "Version:      $pversion";
&loginfo;
$message = "Name:         $pname";
&loginfo;
$message = "Folder:       $pfolder";
&loginfo;
$message = "Title:        $ptitle";
&loginfo;
$message = "Autoupdate:   $pautoupdates";
&loginfo;
$message = "Release:      $preleasecfg";
&loginfo;
$message = "Prerelease:   $pprereleasecfg";
&loginfo;
$message = "Reboot:       $preboot";
&loginfo;
$message = "Min LB Vers:  $plbmin";
&loginfo;
$message = "Max LB Vers:  $plbmax";
&loginfo;
$message = "Architecture: $parch";
&loginfo;
$message = "Interface:    $pinterface";
&loginfo;

if (!$pauthorname || !$pauthoremail || !$pversion || !$pname || !$ptitle || !$pfolder || !$pinterface) {
  $message =  "$SL{'PLUGININSTALL.ERR_PLUGINCFG'}";
  &logfail;
}  else {
  $message =  "$SL{'PLUGININSTALL.OK_PLUGINCFG'}";
  &logok;
}
if ( $pinterface eq "1.0" ) {
  $message =  "*** DEPRECIATED *** This Plugin uses the outdated PLUGIN Interface V1.0. It will be compatible with this Version of LoxBerry but may not work with the next Major LoxBerry release! Please inform the PLUGIN Author at $pauthoremail";
  &logerr; 
  push(@errors,"PLUGININTERFACE: $message");
}

# Create MD5 Checksum
our $pmd5checksum = md5_hex(encode_utf8("$pauthorname$pauthoremail$pname$pfolder"));

# Read Plugin Database
my $openerr = 0;
if (!-e "$lbsdatadir/plugindatabase.dat") {
  $message =  "$SL{'PLUGININSTALL.ERR_DATABASE'}";
  &logfail;
}
my @pnames;
my @pfolders;
my $isupgrade = 0;
open(F,"+<$lbsdatadir/plugindatabase.dat") or ($openerr = 1);
  flock(F,2);
  if ($openerr) {
    $message =  "$SL{'PLUGININSTALL.ERR_DATABASE'}";
    &logfail;
  }
  my @data = <F>;
  seek(F,0,0);
  truncate(F,0);
  foreach (@data){
    s/[\n\r]//g;
    # Comments
    if ($_ =~ /^\s*#.*/) {
      print F "$_\n";
      next;
    }
    my @fields = split(/\|/);
    # If this is an upgrade use existing data
    if (@fields[0] eq $pmd5checksum) {
      $isupgrade = 1;
      if ( $pautoupdates && @fields[8] > $pautoupdates ) {
        $pautoupdates = @fields[8] 
      };
      print F "@fields[0]|@fields[1]|@fields[2]|$pversion|@fields[4]|@fields[5]|$ptitle|$pinterface|$pautoupdates|$preleasecfg|$pprereleasecfg|3\n";
      $pname = @fields[4];
      $pfolder = @fields[5];
      $message =  "$SL{'PLUGININSTALL.INF_ISUPDATE'}";
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
    my $exists = 0;
    my $i;
    my $i1;
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
      $message =  "$SL{'PLUGININSTALL.OK_DBENTRY'}";
      &logok;
      $message = $SL{'PLUGININSTALL.INF_PNAME_IS'} . " $pname";
      &loginfo;
      $message = $SL{'PLUGININSTALL.INF_PFOLDER_IS'} . " $pfolder";
      &loginfo;
    } else {
      $message =  "$SL{'PLUGININSTALL.ERR_DBENTRY'}";
      &logfail;
    }
    print F "$pmd5checksum|$pauthorname|$pauthoremail|$pversion|$pname|$pfolder|$ptitle|$pinterface|$pautoupdates|$preleasecfg|$pprereleasecfg|0\n";
  }
  flock(F,8);
close (F);

# Starting installation

# Executing preroot script
if (-f "$tempfolder/preroot.sh") {
  $message =  "$SL{'PLUGININSTALL.INF_START_PREROOT'}";
  &loginfo;

  $message = "Command: \"$tempfolder/preroot.sh\" \"$tempfolder\" \"$pname\" \"$pfolder\" \"$pversion\" \"$lbhomedir\"";
  &loginfo;

  system("$sudobin -n -u loxberry $chmodbin -v a+x \"$tempfolder/preroot.sh\" 2>&1");
  system("\"$tempfolder/preroot.sh\" \"$tempfolder\" \"$pname\" \"$pfolder\" \"$pversion\" \"$lbhomedir\" 2>&1");
  if ($? eq 1) {
    $message =  "$SL{'PLUGININSTALL.ERR_SCRIPT'}";
    &logerr; 
    push(@errors,"PREROOT: $message");
  } 
  elsif ($? > 1) {
    $message =  "$SL{'PLUGININSTALL.FAIL_SCRIPT'}";
    &logfail; 
  }
  else {
    $message =  "$SL{'PLUGININSTALL.OK_SCRIPT'}";
    &logok;
  }

}

# Executing preupgrade script
if ($isupgrade) {
  if (-f "$tempfolder/preupgrade.sh") {

    $message =  "$SL{'PLUGININSTALL.INF_START_PREUPGRADE'}";
    &loginfo;

    $message = "Command: $sudobin -n -u loxberry \"$tempfolder/preupgrade.sh\" \"$tempfolder\" \"$pname\" \"$pfolder\" \"$pversion\" \"$lbhomedir\"";
    &loginfo;

    system("$sudobin -n -u loxberry $chmodbin -v a+x \"$tempfolder/preupgrade.sh\" 2>&1");
    system("$sudobin -n -u loxberry \"$tempfolder/preupgrade.sh\" \"$tempfolder\" \"$pname\" \"$pfolder\" \"$pversion\" \"$lbhomedir\" 2>&1");
    if ($? eq 1) {
      $message =  "$SL{'PLUGININSTALL.ERR_SCRIPT'}";
      &logerr; 
      push(@errors,"PREUPGRADE: $message");
    } 
    elsif ($? > 1) {
      $message =  "$SL{'PLUGININSTALL.FAIL_SCRIPT'}";
      &logfail; 
    }
    else {
      $message =  "$SL{'PLUGININSTALL.OK_SCRIPT'}";
      &logok;
    }

  }
  # Purge old installation
  $message =  "$SL{'PLUGININSTALL.INF_REMOVING_OLD_INSTALL'}";
  &loginfo;

  &purge_installation;

}

# Executing preinstall script
if (-f "$tempfolder/preinstall.sh") {
  $message =  "$SL{'PLUGININSTALL.INF_START_PREINSTALL'}";
  &loginfo;

  $message = "Command: $sudobin -n -u loxberry \"$tempfolder/preinstall.sh\" \"$tempfolder\" \"$pname\" \"$pfolder\" \"$pversion\" \"$lbhomedir\"";
  &loginfo;

  system("$sudobin -n -u loxberry $chmodbin -v a+x \"$tempfolder/preinstall.sh\" 2>&1");
  system("$sudobin -n -u loxberry \"$tempfolder/preinstall.sh\" \"$tempfolder\" \"$pname\" \"$pfolder\" \"$pversion\" \"$lbhomedir\" 2>&1");
  if ($? eq 1) {
    $message =  "$SL{'PLUGININSTALL.ERR_SCRIPT'}";
    &logerr; 
    push(@errors,"PREINSTALL: $message");
  } 
  elsif ($? > 1) {
    $message =  "$SL{'PLUGININSTALL.FAIL_SCRIPT'}";
    &logfail; 
  }
  else {
    $message =  "$SL{'PLUGININSTALL.OK_SCRIPT'}";
    &logok;
  }
}  

# Copy Config files
make_path("$lbhomedir/config/plugins/$pfolder" , {chmod => 0755, owner=>'loxberry', group=>'loxberry'});
if (!&is_folder_empty("$tempfolder/config")) {
  $message =  "$SL{'PLUGININSTALL.INF_CONFIG'}";
  &loginfo;
  system("$sudobin -n -u loxberry cp -r -v $tempfolder/config/* $lbhomedir/config/plugins/$pfolder/ 2>&1");
  if ($? ne 0) {
    $message =  "$SL{'PLUGININSTALL.ERR_FILES'}";
    &logerr; 
    push(@errors,"CONFIG files: $message");
  } else {
    $message =  "$SL{'PLUGININSTALL.OK_FILES'}";
    &logok;
  }
  &setowner ("loxberry", "1", "$lbhomedir/config/plugins/$pfolder", "CONFIG files");

}

# Copy bin files
make_path("$lbhomedir/bin/plugins/$pfolder" , {chmod => 0755, owner=>'loxberry', group=>'loxberry'});
if (!&is_folder_empty("$tempfolder/bin")) {
  $message =  "$SL{'PLUGININSTALL.INF_BIN'}";
  &loginfo;
  system("$sudobin -n -u loxberry cp -r -v $tempfolder/bin/* $lbhomedir/bin/plugins/$pfolder/ 2>&1");
  if ($? ne 0) {
    $message =  "$SL{'PLUGININSTALL.ERR_FILES'}";
    &logerr; 
    push(@errors,"BIN files: $message");
  } else {
    $message =  "$SL{'PLUGININSTALL.OK_FILES'}";
    &logok;
  }

  &setrights ("755", "1", "$lbhomedir/bin/plugins/$pfolder", "BIN files");

  &setowner ("loxberry", "1", "$lbhomedir/bin/plugins/$pfolder", "BIN files");

}

# Copy Template files
make_path("$lbhomedir/templates/plugins/$pfolder" , {chmod => 0755, owner=>'loxberry', group=>'loxberry'});
if (!&is_folder_empty("$tempfolder/templates")) {
  $message =  "$SL{'PLUGININSTALL.INF_TEMPLATES'}";
  &loginfo;
  system("$sudobin -n -u loxberry cp -r -v $tempfolder/templates/* $lbhomedir/templates/plugins/$pfolder/ 2>&1");
  if ($? ne 0) {
    $message =  "$SL{'PLUGININSTALL.ERR_FILES'}";
    &logerr; 
    push(@errors,"TEMPLATE files: $message");
  } else {
    $message =  "$SL{'PLUGININSTALL.OK_FILES'}";
    &logok;
  }

  &setowner ("loxberry", "1", "$lbhomedir/templates/plugins/$pfolder", "TEMPLATE files");
  
}

# Copy Cron files
if (!&is_folder_empty("$tempfolder/cron")) {
  $message =  "$SL{'PLUGININSTALL.INF_CRONJOB'}";
  &loginfo;
  $openerr = 0;
  if (-e "$tempfolder/cron/crontab" && !-e "$lbhomedir/system/cron/cron.d/$pname") {
    system("cp -r -v $tempfolder/cron/crontab $lbhomedir/system/cron/cron.d/$pname 2>&1");
    if ($? ne 0) {
      $openerr = 1;
    }
  } 
  if (-e "$tempfolder/cron/cron.01min") {
    system("$sudobin -n -u loxberry cp -r -v $tempfolder/cron/cron.01min $lbhomedir/system/cron/cron.01min/$pname 2>&1");
    if ($? ne 0) {
      $openerr = 1;
    }
  } 
  if (-e "$tempfolder/cron/cron.03min") {
    system("$sudobin -n -u loxberry cp -r -v $tempfolder/cron/cron.03min $lbhomedir/system/cron/cron.03min/$pname 2>&1");
    if ($? ne 0) {
      $openerr = 1;
    }
  } 
  if (-e "$tempfolder/cron/cron.05min") {
    system("$sudobin -n -u loxberry cp -r -v $tempfolder/cron/cron.05min $lbhomedir/system/cron/cron.05min/$pname 2>&1");
    if ($? ne 0) {
      $openerr = 1;
    }
  } 
  if (-e "$tempfolder/cron/cron.10min") {
    system("$sudobin -n -u loxberry cp -r -v $tempfolder/cron/cron.10min $lbhomedir/system/cron/cron.10min/$pname 2>&1");
    if ($? ne 0) {
      $openerr = 1;
    }
  } 
  if (-e "$tempfolder/cron/cron.15min") {
    system("$sudobin -n -u loxberry cp -r -v $tempfolder/cron/cron.15min $lbhomedir/system/cron/cron.15min/$pname 2>&1");
    if ($? ne 0) {
      $openerr = 1;
    }
  } 
  if (-e "$tempfolder/cron/cron.30min") {
    system("$sudobin -n -u loxberry cp -r -v $tempfolder/cron/cron.30min $lbhomedir/system/cron/cron.30min/$pname 2>&1");
    if ($? ne 0) {
      $openerr = 1;
    }
  } 
  if (-e "$tempfolder/cron/cron.hourly") {
    system("$sudobin -n -u loxberry cp -r -v $tempfolder/cron/cron.hourly $lbhomedir/system/cron/cron.hourly/$pname 2>&1");
    if ($? ne 0) {
      $openerr = 1;
    }
  } 
  if (-e "$tempfolder/cron/cron.daily") {
    system("$sudobin -n -u loxberry cp -r -v $tempfolder/cron/cron.daily $lbhomedir/system/cron/cron.daily/$pname 2>&1");
    if ($? ne 0) {
      $openerr = 1;
    }
  } 
  if (-e "$tempfolder/cron/cron.weekly") {
    system("$sudobin -n -u loxberry cp -r -v $tempfolder/cron/cron.weekly01 $lbhomedir/system/cron/cron.weekly/$pname 2>&1");
    if ($? ne 0) {
      $openerr = 1;
    }
  } 
  if (-e "$tempfolder/cron/cron.monthly") {
    system("$sudobin -n -u loxberry cp -r -v $tempfolder/cron/cron.monthly $lbhomedir/system/cron/cron.monthly/$pname 2>&1");
    if ($? ne 0) {
      $openerr = 1;
    }
  } 
  if (-e "$tempfolder/cron/cron.yearly") {
    system("$sudobin -n -u loxberry cp -r -v $tempfolder/cron/cron.yearly $lbhomedir/system/cron/cron.yearly/$pname 2>&1");
    if ($? ne 0) {
      $openerr = 1;
    }
  } 
  if ($openerr) {
    $message =  "$SL{'PLUGININSTALL.ERR_FILES'}";
    &logerr; 
    push(@errors,"CRONJOB files: $message");
  } else {
    $message =  "$SL{'PLUGININSTALL.OK_FILES'}";
    &logok;
  }

  &setrights ("755", "1", "$lbhomedir/system/cron/cron.01min", "CRONJOB files");
  &setowner  ("loxberry", "1", "$lbhomedir/system/cron/cron.01min", "CRONJOB files");
  &setrights ("755", "1", "$lbhomedir/system/cron/cron.03min", "CRONJOB files");
  &setowner  ("loxberry", "1", "$lbhomedir/system/cron/cron.03min", "CRONJOB files");
  &setrights ("755", "1", "$lbhomedir/system/cron/cron.05min", "CRONJOB files");
  &setowner  ("loxberry", "1", "$lbhomedir/system/cron/cron.05min", "CRONJOB files");
  &setrights ("755", "1", "$lbhomedir/system/cron/cron.10min", "CRONJOB files");
  &setowner  ("loxberry", "1", "$lbhomedir/system/cron/cron.10min", "CRONJOB files");
  &setrights ("755", "1", "$lbhomedir/system/cron/cron.15min", "CRONJOB files");
  &setowner  ("loxberry", "1", "$lbhomedir/system/cron/cron.15min", "CRONJOB files");
  &setrights ("755", "1", "$lbhomedir/system/cron/cron.30min", "CRONJOB files");
  &setowner  ("loxberry", "1", "$lbhomedir/system/cron/cron.30min", "CRONJOB files");
  &setrights ("755", "1", "$lbhomedir/system/cron/cron.hourly", "CRONJOB files");
  &setowner  ("loxberry", "1", "$lbhomedir/system/cron/cron.hourly", "CRONJOB files");
  &setrights ("755", "1", "$lbhomedir/system/cron/cron.daily", "CRONJOB files");
  &setowner  ("loxberry", "1", "$lbhomedir/system/cron/cron.daily", "CRONJOB files");
  &setrights ("755", "1", "$lbhomedir/system/cron/cron.weekly", "CRONJOB files");
  &setowner  ("loxberry", "1", "$lbhomedir/system/cron/cron.weekly", "CRONJOB files");
  &setrights ("755", "1", "$lbhomedir/system/cron/cron.monthly", "CRONJOB files");
  &setowner  ("loxberry", "1", "$lbhomedir/system/cron/cron.monthly", "CRONJOB files");
  &setrights ("755", "1", "$lbhomedir/system/cron/cron.yearly", "CRONJOB files");
  &setowner  ("loxberry", "1", "$lbhomedir/system/cron/cron.yearly", "CRONJOB files");
  &setrights ("644", "0", "$lbhomedir/system/cron/cron.d/*", "CRONTAB files");
  &setowner  ("root", "0", "$lbhomedir/system/cron/cron.d/*", "CRONTAB files");

}

# Copy Data files
make_path("$lbhomedir/data/plugins/$pfolder" , {chmod => 0755, owner=>'loxberry', group=>'loxberry'});
if (!&is_folder_empty("$tempfolder/data")) {
  $message =  "$SL{'PLUGININSTALL.INF_DATAFILES'}";
  &loginfo;
  system("$sudobin -n -u loxberry cp -r -v $tempfolder/data/* $lbhomedir/data/plugins/$pfolder/ 2>&1");
  if ($? ne 0) {
    $message =  "$SL{'PLUGININSTALL.ERR_FILES'}";
    &logerr; 
    push(@errors,"DATA files: $message");
  } else {
    $message =  "$SL{'PLUGININSTALL.OK_FILES'}";
    &logok;
  }

  &setowner ("loxberry", "1", "$lbhomedir/data/plugins/$pfolder", "DATA files");

}

# Copy Log files
if ( $pinterface eq "1.0" && !-e "$lbhomedir/log/plugins/$pfolder" ) {
  make_path("$lbhomedir/log/plugins/$pfolder" , {chmod => 0755, owner=>'loxberry', group=>'loxberry'});
  if (!&is_folder_empty("$tempfolder/log")) {
    $message =  "$SL{'PLUGININSTALL.INF_LOGFILES'}";
    &loginfo;
    $message =  "*** DEPRECIATED *** This Plugin uses an outdated feature! Log files are stored in a RAMDISC now. The plugin has to create the logfiles at runtime! Please inform the PLUGIN Author at $pauthoremail";
    &logerr; 
    push(@errors,"LOG files: $message");
    system("$sudobin -n -u loxberry cp -r -v $tempfolder/log/* $lbhomedir/log/plugins/$pfolder/ 2>&1");
    if ($? ne 0) {
      $message =  "$SL{'PLUGININSTALL.ERR_FILES'}";
      &logerr; 
      push(@errors,"LOG files: $message");
    } else {
      $message =  "$SL{'PLUGININSTALL.OK_FILES'}";
      &logok;
    }

    &setowner ("loxberry", "1", "$lbhomedir/log/plugins/$pfolder", "LOG files");

  }
}

# Copy CGI files - DEPRECIATED!!!
if ( $pinterface eq "1.0" ) {
  make_path("$lbhomedir/webfrontend/htmlauth/plugins/$pfolder" , {chmod => 0755, owner=>'loxberry', group=>'loxberry'});
  if (!&is_folder_empty("$tempfolder/webfrontend/cgi")) {
    $message =  "$SL{'PLUGININSTALL.INF_HTMLAUTHFILES'}";
    &loginfo;
    $message =  "*** DEPRECIATED *** This Plugin uses an outdated feature! CGI files are stored in HTMLAUTH now. Please inform the PLUGIN Author at $pauthoremail";
    &logerr; 
    push(@errors,"HTMLAUTH files: $message");
    system("$sudobin -n -u loxberry cp -r -v $tempfolder/webfrontend/cgi/* $lbhomedir/webfrontend/htmlauth/plugins/$pfolder/ 2>&1");
    if ($? ne 0) {
      $message =  "$SL{'PLUGININSTALL.ERR_FILES'}";
      &logerr; 
      push(@errors,"HTMLAUTH files: $message");
    } else {
      $message =  "$SL{'PLUGININSTALL.OK_FILES'}";
      &logok;
    }

    &setowner ("loxberry", "1", "$lbhomedir/webfrontend/htmlauth/plugins/$pfolder", "HTMLAUTH files");

    &setrights ("755", "1", "$lbhomedir/webfrontend/htmlauth/plugins/$pfolder", "HTMLAUTH files");

  }
}

# Copy HTMLAUTH files
if ( $pinterface ne "1.0" ) {
  make_path("$lbhomedir/webfrontend/htmlauth/plugins/$pfolder" , {chmod => 0755, owner=>'loxberry', group=>'loxberry'});
  if (!&is_folder_empty("$tempfolder/webfrontend/htmlauth")) {
    $message =  "$SL{'PLUGININSTALL.INF_HTMLAUTHFILES'}";
    &loginfo;
    system("$sudobin -n -u loxberry cp -r -v $tempfolder/webfrontend/htmlauth/* $lbhomedir/webfrontend/htmlauth/plugins/$pfolder/ 2>&1");
    if ($? ne 0) {
      $message =  "$SL{'PLUGININSTALL.ERR_FILES'}";
      &logerr; 
      push(@errors,"HTMLAUTH files: $message");
    } else {
      $message =  "$SL{'PLUGININSTALL.OK_FILES'}";
      &logok;
    }

    &setrights ("755", "0", "$lbhomedir/webfrontend/htmlauth/plugins/$pfolder", "HTMLAUTH files", ".*\\.cgi\\|.*\\.pl");

    &setowner ("loxberry", "1", "$lbhomedir/webfrontend/htmlauth/plugins/$pfolder", "HTMLAUTH files");

  }
}

# Copy HTML files
make_path("$lbhomedir/webfrontend/html/plugins/$pfolder" , {chmod => 0755, owner=>'loxberry', group=>'loxberry'});
if (!&is_folder_empty("$tempfolder/webfrontend/html")) {
  $message =  "$SL{'PLUGININSTALL.INF_HTMLFILES'}";
  &loginfo;
  system("$sudobin -n -u loxberry cp -r -v $tempfolder/webfrontend/html/* $lbhomedir/webfrontend/html/plugins/$pfolder/ 2>&1");
  if ($? ne 0) {
    $message =  "$SL{'PLUGININSTALL.ERR_FILES'}";
    &logerr; 
    push(@errors,"HTML files: $message");
  } else {
    $message =  "$SL{'PLUGININSTALL.OK_FILES'}";
    &logok;
  }

    &setrights ("755", "0", "$lbhomedir/webfrontend/html/plugins/$pfolder", "HTMLAUTH files", ".*\\.cgi\\|.*\\.pl");

    &setowner ("loxberry", "1", "$lbhomedir/webfrontend/html/plugins/$pfolder", "HTMLAUTH files");

}

# Copy Icon files
make_path("$lbhomedir/webfrontend/html/system/images/icons/$pfolder" , {chmod => 0755, owner=>'loxberry', group=>'loxberry'});
$message =  "$SL{'PLUGININSTALL.INF_ICONFILES'}";
&loginfo;
system("$sudobin -n -u loxberry cp -r -v $tempfolder/icons/* $lbhomedir/webfrontend/html/system/images/icons/$pfolder/ 2>&1");
if ($? ne 0) {
  system("$sudobin -n -u loxberry cp -r -v $lbhomedir/webfrontend/html/system/images/icons/default/* $lbhomedir/webfrontend/html/system/images/icons/$pfolder/ 2>&1");
  $message =  "$SL{'PLUGININSTALL.ERR_ICONFILES'}";
  &logerr; 
  push(@errors,"ICON files: $message");
} else {
  $openerr = 0;
  if (!-e "$lbhomedir/webfrontend/html/system/images/icons/$pfolder/icon_64.png") {
    $openerr = 1;
    system("$sudobin -n -u loxberry cp -r -v $lbhomedir/webfrontend/html/system/images/icons/default/icon_64.png $lbhomedir/webfrontend/html/system/images/icons/$pfolder/ 2>&1");
  } 
  if (!-e "$lbhomedir/webfrontend/html/system/images/icons/$pfolder/icon_128.png") {
    $openerr = 1;
    system("$sudobin -n -u loxberry cp -r -v $lbhomedir/webfrontend/html/system/images/icons/default/icon_128.png $lbhomedir/webfrontend/html/system/images/icons/$pfolder/ 2>&1");
  } 
  if (!-e "$lbhomedir/webfrontend/html/system/images/icons/$pfolder/icon_256.png") {
    $openerr = 1;
    system("$sudobin -n -u loxberry cp -r -v $lbhomedir/webfrontend/html/system/images/icons/default/icon_256.png $lbhomedir/webfrontend/html/system/images/icons/$pfolder/ 2>&1");
  } 
  if (!-e "$lbhomedir/webfrontend/html/system/images/icons/$pfolder/icon_512.png") {
    $openerr = 1;
    system("$sudobin -n -u loxberry cp -r -v $lbhomedir/webfrontend/html/system/images/icons/default/icon_512.png $lbhomedir/webfrontend/html/system/images/icons/$pfolder/ 2>&1");
  } 
  if ($openerr) {
    $message =  "$SL{'PLUGININSTALL.ERR_ICONFILES'}";
    &logerr;
    push(@errors,"ICON files: $message");
  } else { 
    $message =  "$SL{'PLUGININSTALL.OK_ICONFILES'}";
    &logok;
  }

  &setowner ("loxberry", "1", "$lbhomedir/webfrontend/html/system/images/icons/$pfolder", "ICON files");

}

# Copy Daemon file
if (-f "$tempfolder/daemon/daemon") {
  $message =  "$SL{'PLUGININSTALL.INF_DAEMON'}";
  &loginfo;
  system("cp -v $tempfolder/daemon/daemon $lbhomedir/system/daemons/plugins/$pname 2>&1");
  if ($? ne 0) {
    $message =  "$SL{'PLUGININSTALL.ERR_FILES'}";
    &logerr; 
    push(@errors,"DAEMON FILE: $message");
  } else {
    $message =  "$SL{'PLUGININSTALL.OK_FILES'}";
    &logok;
  }

  &setrights ("755", "0", "$lbhomedir/system/daemons/plugins/$pname", "DAEMON script");

  &setowner ("root", "0", "$lbhomedir/system/daemons/plugins/$pname", "DAEMON script");

}

# Copy Uninstall file
if (-f "$tempfolder/uninstall/uninstall") {
  $message =  "$SL{'PLUGININSTALL.INF_UNINSTALL'}";
  &loginfo;
  system("cp -r -v $tempfolder/uninstall/uninstall $lbhomedir/data/system/uninstall/$pname 2>&1");
  if ($? ne 0) {
    $message =  "$SL{'PLUGININSTALL.ERR_FILES'}";
    &logerr; 
    push(@errors,"UNINSTALL Script: $message");
  } else {
    $message =  "$SL{'PLUGININSTALL.OK_FILES'}";
    &logok;
  }

  &setrights ("755", "0", "$lbhomedir/data/system/uninstall/$pname", "UNINSTALL script");

  &setowner ("root", "0", "$lbhomedir/data/system/uninstall/$pname", "UNINSTALL script");

}

# Copy Sudoers file
if (-f "$tempfolder/sudoers/sudoers") {
  $message =  "$SL{'PLUGININSTALL.INF_SUDOERS'}";
  &loginfo;
  system("cp -v $tempfolder/sudoers/sudoers $lbhomedir/system/sudoers/$pname 2>&1");
  if ($? ne 0) {
    $message =  "$SL{'PLUGININSTALL.ERR_FILES'}";
    &logerr; 
    push(@errors,"SUDOERS file: $message");
  } else {
    $message =  "$SL{'PLUGININSTALL.OK_FILES'}";
    &logok;
  }

  &setrights ("644", "0", "$lbhomedir/system/sudoers/$pname", "SUDOERS file");

  &setowner ("root", "0", "$lbhomedir/system/sudoers/$pname", "SUDOERS file");

}

# Installing additional packages
if ( $pinterface eq "1.0" ) {
	my $aptfile="$tempfolder/apt";
} else {
	my $aptfile="$tempfolder/dpkg/apt";
}

if (-e "$aptfile") {

  if (-e "$lbhomedir/data/system/lastaptupdate.dat") {
    open(F,"<$lbhomedir/data/system/lastaptupdate.dat");
      $lastaptupdate = <F>;
    close(F);
  } else {
    $lastaptupdate = 0;
  }
  $now = time;
  # If last run of apt-get update is longer than 24h ago, do a refresh.
  if ($now > $lastaptupdate+86400) {
    $message =  "$SL{'PLUGININSTALL.INF_APTREFRESH'}";
    &loginfo;
    $message = "Command: $aptbin -q -y update";
    &loginfo;
    system("$aptbin -q -y update 2>&1");
    if ($? ne 0) {
      $message =  "$SL{'PLUGININSTALL.ERR_APTREFRESH'}";
      &logerr; 
      push(@errors,"APT refresh: $message");
    } else {
      $message =  "$SL{'PLUGININSTALL.OK_APTREFRESH'}";
      &logok;
      open(F,">$lbhomedir/data/system/lastaptupdate.dat");
        print F $now;
      close(F);
    }
  }
  $message =  "$SL{'PLUGININSTALL.INF_APT'}";
  &loginfo;
  $openerr = 0;
  open(F,"<$aptfile") or ($openerr = 1);
    if ($openerr) {
      $message =  "$SL{'PLUGININSTALL.ERR_APT'}";
      &logerr;
      push(@errors,"APT install: $message");
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

  $message = "Command: $aptbin -q -y install $aptpackages";
  &loginfo;
  system("$aptbin -q -y install $aptpackages 2>&1");
  if ($? ne 0) {
    $message =  "$SL{'PLUGININSTALL.ERR_PACKAGESINSTALL'}";
    &logerr; 
    push(@errors,"APT install: $message");
    # If it failed, maybe due to an outdated apt-database... So
    # do a apt-get update once more
    $message =  "$SL{'PLUGININSTALL.INF_APTREFRESH'}";
    &loginfo;
    $message = "Command: $aptbin -q -y update";
    &loginfo;
    system("$aptbin -q -y update 2>&1");
    if ($? ne 0) {
      $message =  "$SL{'PLUGININSTALL.ERR_APTREFRESH'}";
      &logerr; 
      push(@errors,"APT refresh: $message");
    } else {
      $message =  "$SL{'PLUGININSTALL.OK_APTREFRESH'}";
      &logok;
      open(F,">$lbhomedir/data/system/lastaptupdate.dat");
        print F $now;
      close(F);
    }
    # And try to install packages again...
    $message = "Command: $aptbin -q -y install $aptpackages";
    &loginfo;
    system("$aptbin -q -y install $aptpackages 2>&1");
    if ($? ne 0) {
      $message =  "$SL{'PLUGININSTALL.ERR_PACKAGESINSTALL'}";
      &logerr; 
      push(@errors,"APT install: $message");
    } else {
      $message =  "$SL{'PLUGININSTALL.OK_PACKAGESINSTALL'}";
      &logok;
    }
  } else {
    $message =  "$SL{'PLUGININSTALL.OK_PACKAGESINSTALL'}";
    &logok;
  }

}

# Executing postinstall script
if (-f "$tempfolder/postinstall.sh") {
  $message =  "$SL{'PLUGININSTALL.INF_START_POSTINSTALL'}";
  &loginfo;

  $message = "Command: $sudobin -n -u loxberry \"$tempfolder/postinstall.sh\" \"$tempfolder\" \"$pname\" \"$pfolder\" \"$pversion\" \"$lbhomedir\"";
  &loginfo;

  system("$sudobin -n -u loxberry $chmodbin -v a+x \"$tempfolder/postinstall.sh\" 2>&1");
  system("$sudobin -n -u loxberry \"$tempfolder/postinstall.sh\" \"$tempfolder\" \"$pname\" \"$pfolder\" \"$pversion\" \"$lbhomedir\" 2>&1");
  if ($? eq 1) {
    $message =  "$SL{'PLUGININSTALL.ERR_SCRIPT'}";
    &logerr; 
     ush(@errors,"POSTINSTALL: $message");
  } 
  elsif ($? > 1) {
    $message =  "$SL{'PLUGININSTALL.FAIL_SCRIPT'}";
    &logfail; 
  }
  else {
    $message =  "$SL{'PLUGININSTALL.OK_SCRIPT'}";
    &logok;
  }

}

# Executing postupgrade script
if ($isupgrade) {
  if (-f "$tempfolder/postupgrade.sh") {
    $message =  "$SL{'PLUGININSTALL.INF_START_POSTUPGRADE'}";
    &loginfo;

    $message = "Command: $sudobin -n -u loxberry \"$tempfolder/postupgrade.sh\" \"$tempfolder\" \"$pname\" \"$pfolder\" \"$pversion\" \"$lbhomedir\"";
    &loginfo;

    system("$sudobin -n -u loxberry $chmodbin -v a+x \"$tempfolder/postupgrade.sh\" 2>&1");
    system("$sudobin -n -u loxberry \"$tempfolder/postupgrade.sh\" \"$tempfolder\" \"$pname\" \"$pfolder\" \"$pversion\" \"$lbhomedir\" 2>&1");
    if ($? eq 1) {
      $message =  "$SL{'PLUGININSTALL.ERR_SCRIPT'}";
      &logerr; 
      push(@errors,"POSTUPGRADE: $message");
    } 
    elsif ($? > 1) {
      $message =  "$SL{'PLUGININSTALL.FAIL_SCRIPT'}";
      &logfail; 
    }
    else {
      $message =  "$SL{'PLUGININSTALL.OK_SCRIPT'}";
      &logok;
    }

  }
}

# Executing postroot script
if (-f "$tempfolder/postroot.sh") {
  $message =  "$SL{'PLUGININSTALL.INF_START_POSTROOT'}";
  &loginfo;

  $message = "Command: \"$tempfolder/postroot.sh\" \"$tempfolder\" \"$pname\" \"$pfolder\" \"$pversion\" \"$lbhomedir\"";
  &loginfo;

  system("$sudobin -n -u loxberry $chmodbin -v a+x \"$tempfolder/postroot.sh\" 2>&1");
  system("\"$tempfolder/postroot.sh\" \"$tempfolder\" \"$pname\" \"$pfolder\" \"$pversion\" \"$lbhomedir\" 2>&1");
  if ($? eq 1) {
    $message =  "$SL{'PLUGININSTALL.ERR_SCRIPT'}";
    &logerr; 
    push(@errors,"POSTROOT: $message");
  } 
  elsif ($? > 1) {
    $message =  "$SL{'PLUGININSTALL.FAIL_SCRIPT'}";
    &logfail; 
  }
  else {
    $message =  "$SL{'PLUGININSTALL.OK_SCRIPT'}";
    &logok;
  }

}

# Copy installation files
make_path("$lbhomedir/data/system/install/$pfolder" , {chmod => 0755, owner=>'loxberry', group=>'loxberry'});
$message =  "$SL{'PLUGININSTALL.INF_INSTALLSCRIPTS'}";
&loginfo;
system("$sudobin -n -u loxberry cp -v $tempfolder/*.sh $lbhomedir/data/system/install/$pfolder 2>&1");
if ($? ne 0) {
  $message =  "$SL{'PLUGININSTALL.ERR_FILES'}";
  &logerr; 
  push(@errors,"INSTALL scripts: $message");
} else {
  $message =  "$SL{'PLUGININSTALL.OK_FILES'}";
  &logok;
}

&setowner ("loxberry", "1", "$lbhomedir/data/system/install/$pfolder", "INSTALL scripts");

}

# Updating header files for side menu
#$message = $phrase->param("TXT0099");
#&loginfo;

# Sorting Plugin Database
#&sort_plugins;

#opendir(DIR, "$lbhomedir/templates/system");
#  @data = readdir(DIR);
#closedir(DIR);
#foreach(@data) {
#  if (-d "$lbhomedir/templates/system/$_" && $_ ne "." && $_ ne "..") {
#    push (@tsets,$_);
#  }
#}
#foreach (@tsets) {
#  $startpsection = 0;
#  open(F,"+<$lbhomedir/templates/system/$_/header.html") or die "Fehler: $!";
#    @data = <F>;
#    seek(F,0,0);
#    truncate(F,0);
#    foreach (@data){
#      s/[\n\r]//g;
#      if ($_ =~ /ENDPLUGINSHERE/) {
#        $startpsection = 0;
#      }
#      if ($_ =~ /STARTPLUGINSHERE/) {
#        $startpsection = 1;
#        print F "$_\n";
#        open(F1,"<$lbhomedir/data/system/plugindatabase.dat") or die "Fehler: $!";
#          @data1 = <F1>;
#          foreach (@data1){
#            s/[\n\r]//g;
#            # Comments
#            if ($_ =~ /^\s*#.*/) {
#              next;
#            }
#            @fields = split(/\|/);
#            print F "<li><a href=\"/admin/plugins/@fields[5]/index.cgi\">@fields[6]</a></li>\n";
#          }
#        close (F1);
#      }
#      if (!$startpsection) {
#        print F "$_\n";
#      }
#    } 
#  close (F);
#}
#$message = $phrase->param("TXT0100");
#&logok;

# Cleaning
$message =  "$SL{'PLUGININSTALL.INF_END'}";
&loginfo;
system("$sudobin -n -u loxberry cp /tmp/$tempfile.log $lbhomedir/log/system/plugininstall/$pname.log 2>&1");

# Finished
$message =  "$SL{'PLUGININSTALL.OK_END'}";
&logok;
system("rm -f /tmp/$tempfile.log");

exit;

}

#####################################################
# 
# Subroutines
#
#####################################################

#####################################################
# Purge installation
#####################################################

sub purge_installation {

  my $option = shift; # http://wiki.selfhtml.org/wiki/Perl/Subroutinen

  if ($pfolder) {
    # Plugin Folders
    system("$sudobin -n -u loxberry rm -rfv $lbhomedir/config/plugins/$pfolder/ 2>&1");
    system("$sudobin -n -u loxberry rm -rfv $lbhomedir/bin/plugins/$pfolder/ 2>&1");
    system("$sudobin -n -u loxberry rm -rfv $lbhomedir/data/plugins/$pfolder/ 2>&1");
    system("$sudobin -n -u loxberry rm -rfv $lbhomedir/templates/$pfolder/ 2>&1");
    system("$sudobin -n -u loxberry rm -rfv $lbhomedir/webfrontend/htmlauth/plugins/$pfolder/ 2>&1");
    system("$sudobin -n -u loxberry rm -rfv $lbhomedir/webfrontend/html/plugins/$pfolder/ 2>&1");
    system("$sudobin -n -u loxberry rm -rfv $lbhomedir/data/system/install/$pfolder 2>&1");
    # Icons for Main Menu
    system("$sudobin -n -u loxberry rm -rfv $lbhomedir/webfrontend/html/system/images/icons/$pfolder/ 2>&1");
  }

  if ($pname) {
    # Daemon file
    system("rm -fv $lbhomedir/system/daemons/plugins/$pname 2>&1");
    # Uninstall file
    system("rm -fv $lbhomedir/system/uninstall/plugins/$pname 2>&1");
    # Cron jobs
    system("$sudobin -n -u loxberry rm -fv $lbhomedir/system/cron/cron.01min/$pname 2>&1");
    system("$sudobin -n -u loxberry rm -fv $lbhomedir/system/cron/cron.03min/$pname 2>&1");
    system("$sudobin -n -u loxberry rm -fv $lbhomedir/system/cron/cron.05min/$pname 2>&1");
    system("$sudobin -n -u loxberry rm -fv $lbhomedir/system/cron/cron.10min/$pname 2>&1");
    system("$sudobin -n -u loxberry rm -fv $lbhomedir/system/cron/cron.15min/$pname 2>&1");
    system("$sudobin -n -u loxberry rm -fv $lbhomedir/system/cron/cron.30min/$pname 2>&1");
    system("$sudobin -n -u loxberry rm -fv $lbhomedir/system/cron/cron.hourly/$pname 2>&1");
    system("$sudobin -n -u loxberry rm -fv $lbhomedir/system/cron/cron.daily/$pname 2>&1");
    system("$sudobin -n -u loxberry rm -fv $lbhomedir/system/cron/cron.weekly/$pname 2>&1");
    system("$sudobin -n -u loxberry rm -fv $lbhomedir/system/cron/cron.monthly/$pname 2>&1");
    system("$sudobin -n -u loxberry rm -fv $lbhomedir/system/cron/cron.yearly/$pname 2>&1");
    # Sudoers
    system("rm -fv $lbhomedir/system/sudoers/$pname 2>&1");
  }

  # This will only be purged if we do an uninstallation
  if ($option eq "all") {
    if ($pfolder) {
      # Log
      system("$sudobin -n -u loxberry rm -rfv $lbhomedir/log/plugins/$pfolder/ 2>&1");
    }

    if ($pname) {
      # Crontab
      system("rm -vf $lbhomedir/system/cron.d/$pname 2>&1");
    }
  }

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

  &purge_installation("all");
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
# Set owner
#####################################################

# &setowner ("loxberry", "1", "path/to/folder", "CONFIG files");
# &setowner ("root", "0", "path/to/file", "DAEMON script");

sub setowner {

  my $owner = shift;
  my $group = $owner;
  my $recursive = shift;
  my $target = shift;
  my $type = shift;

  if ( $recursive ) {
    our $chownoptions = "-Rv";
  } else {
    our $chownoptions = "-v";
  }

  $message = $SL{'PLUGININSTALL.INF_FILE_OWNER'} . " $chownbin $chownoptions $owner.$group $target";
  &loginfo;
  system("$chownbin $chownoptions $owner.$group $target 2>&1");
  if ($? ne 0) {
    $message =  "$SL{'PLUGININSTALL.ERR_FILE_OWNER'}";
    &logerr; 
    push(@errors,"$type: $message");
  } else {
    $message =  "$SL{'PLUGININSTALL.OK_FILE_OWNER'}";
    &logok;
  }

}

#####################################################
# Set permissions
#####################################################

# &setrights ("755", "1", "path/to/folder", "CONFIG files" [,"Regex"]);
# &setrights ("644", "0", "path/to/file", "DAEMON script" [,"Regex"]);

sub setrights {

  my $rights = shift;
  my $recursive = shift;
  my $target = shift;
  my $type = shift;
  my $regex = shift;

  if ( $recursive ) {
    our $chmodoptions = "-Rv";
  } else {
    our $chmodoptions = "-v";
  }

  if ($regex) {

    $chmodoptions = "-v";
    $message = $SL{'PLUGININSTALL.INF_FILE_PERMISSIONS'} . " $findbin $target -iregex '$regex' -exec $chmodbin $chmodoptions $rights {} \\;";
    &loginfo;
    system("$sudobin -n -u loxberry $findbin $target -iregex '$regex' -exec $chmodbin $chmodoptions $rights {} \\; 2>&1");

  } else {

    $message = $SL{'PLUGININSTALL.INF_FILE_PERMISSIONS'} . " $chmodbin $chmodoptions $rights $target";
    &loginfo;
    system("$chmodbin $chmodoptions $rights $target 2>&1");

  }
  if ($? ne 0) {
    $message =  "$SL{'PLUGININSTALL.ERR_FILE_PERMISSIONS'}";
    &logerr; 
    push(@errors,"$type: $message");
  } else {
    $message =  "$SL{'PLUGININSTALL.OK_FILE_PERMISSIONS'}";
    &logok;
  }

}

#####################################################
# Replace strings in pluginfiles
#####################################################

sub replaceenvironment {

  system("$sudobin -n -u loxberry $findbin $lbhomedir/config/plugins/$pfolder -iregex '.*\..*' -exec /bin/sed -i 's#REPLACELBHOMEDIR#$lbhomedir#g {} \\; 2>&1");
  system("$sudobin -n -u loxberry $findbin $lbhomedir/config/plugins/$pfolder -iregex '.*\..*' -exec /bin/sed -i 's#REPLACELBPPLUGINDIR#$pfolder#g {} \\; 2>&1");
  system("$sudobin -n -u loxberry $findbin $lbhomedir/config/plugins/$pfolder -iregex '.*\..*' -exec /bin/sed -i 's#REPLACELBPHTMLAUTHDIR#$lbhomedir/webfrontend/htmlauth/plugins/$pfolder#g {} \\; 2>&1");
  system("$sudobin -n -u loxberry $findbin $lbhomedir/config/plugins/$pfolder -iregex '.*\..*' -exec /bin/sed -i 's#REPLACELBPHTMLDIR#$lbhomedir/webfrontend/html/plugins/$pfolder#g {} \\; 2>&1");
  system("$sudobin -n -u loxberry $findbin $lbhomedir/config/plugins/$pfolder -iregex '.*\..*' -exec /bin/sed -i 's#REPLACELBPTEMPLATEDIR#$lbhomedir/templates/plugins/$pfolder#g {} \\; 2>&1");
  system("$sudobin -n -u loxberry $findbin $lbhomedir/config/plugins/$pfolder -iregex '.*\..*' -exec /bin/sed -i 's#REPLACELBPDATADIR#$lbhomedir/data/plugins/$pfolder#g {} \\; 2>&1");
  system("$sudobin -n -u loxberry $findbin $lbhomedir/config/plugins/$pfolder -iregex '.*\..*' -exec /bin/sed -i 's#REPLACELBPLOGDIR#$lbhomedir/log/plugins/$pfolder#g {} \\; 2>&1");
  system("$sudobin -n -u loxberry $findbin $lbhomedir/config/plugins/$pfolder -iregex '.*\..*' -exec /bin/sed -i 's#REPLACELBPCONFIGDIR#$lbhomedir/config/plugins/$pfolder#g {} \\; 2>&1");
  system("$sudobin -n -u loxberry $findbin $lbhomedir/config/plugins/$pfolder -iregex '.*\..*' -exec /bin/sed -i 's#REPLACELBPBINDIR#$lbhomedir/bin/plugins/$pfolder#g {} \\; 2>&1");

  return();

}

#####################################################
# Sorting Plugin Database
#####################################################

sub sort_plugins {
  # Einlesen
  my @zeilen=();
  my $input_file="$lbhomedir/data/system/plugindatabase.dat";
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
  open(F,"+<$lbhomedir/data/system/plugindatabase.dat");
  @data = <F>;
  seek(F,0,0);
  truncate(F,0);
  print F join('|', @{$_}), "\n" for @zeilen;   #sortiert wieder ausgeben
  close (F);
  return();
}
