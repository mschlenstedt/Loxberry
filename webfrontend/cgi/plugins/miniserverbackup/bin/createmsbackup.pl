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

use LWP::UserAgent;
use XML::Simple qw(:strict);
use Config::Simple;
#use Data::Dumper;
use File::Copy;
#use strict;
#use warnings;
use File::HomeDir;

##########################################################################
# Variables
##########################################################################

our $cfg;
our $pcfg;
our $miniserverip;
our $miniserverport;
our $miniserveradmin;
our $miniserverpass;
our $miniservers;
our $url;
our $ua;
our $response;
our $error = 0;
our $rawxml;
our $xml;
our @fields;
our $mainver;
our $subver;
our $monver;
our $dayver;
our $miniserverftpport;
our $wgetbin;
our $zipbin;
our $diryear;
our $dirmday;
our $dirhour;
our $dirmin;
our $dirsec;
our $dirwday;
our $diryday;
our $dirisdst;
our $bkpdir;
our $verbose;
our $debug;
our $maxfiles;
our $installfolder;
our $home = File::HomeDir->my_home;
our @Eintraege;
our @files;
our $subfolder;
our $i;
our $msno;
our $useclouddns;
our $miniservercloudurl;
our $curlbin;
our $grepbin;
our $awkbin;
our $logmessage;
our $clouddns;
our $quiet;
our $something_wrong;
##########################################################################
# Read Configuration
##########################################################################

# Version of this script
my $version = "0.0.6";

$cfg             = new Config::Simple("$home/config/system/general.cfg");
$installfolder   = $cfg->param("BASE.INSTALLFOLDER");
$miniservers     = $cfg->param("BASE.MINISERVERS");
$clouddns        = $cfg->param("BASE.CLOUDDNS");
$wgetbin         = $cfg->param("BINARIES.WGET");
$zipbin          = $cfg->param("BINARIES.ZIP");
$curlbin         = $cfg->param("BINARIES.CURL");
$grepbin         = $cfg->param("BINARIES.GREP");
$awkbin          = $cfg->param("BINARIES.AWK");

$pcfg            = new Config::Simple("$installfolder/config/plugins/miniserverbackup/miniserverbackup.cfg");
$debug           = $pcfg->param("MSBACKUP.DEBUG");
$maxfiles        = $pcfg->param("MSBACKUP.MAXFILES");
$subfolder       = $pcfg->param("MSBACKUP.SUBFOLDER");

our $css = "";
#Error Style
#"<div style=\'text-align:left; width:100%; color:#000000; background-color:\'#FFE0E0\';\'>";
our $red_css     = "ERROR";

#Good Style
#"<div style=\'text-align:left; width:100%; color:#000000; background-color:\'#D8FADC\';\'>";
our $green_css     = "OK";

#Download Style
#"<div style=\'text-align:left; width:100%; color:#000000; background-color:\'#F8F4D6\';\'>";
our $yellow_css     = "DWL";

#Download Style
#"<div style=\'text-align:left; width:100%; color:#000000; background-color:\'#DDEFFF\';\'>";
our $ms_css     = "MS#";

##########################################################################
# Main program
##########################################################################

if ($debug == 1)
{
	$debug = 0;
	$verbose = 1;
}
elsif ($debug == 2)
{
	$debug = 1;
	$verbose = 1;
}
else
{
	$debug = 0;
	$verbose = 0;
}

# Start
if ($verbose) {
  
  $logmessage = "### $miniservers Miniserver at all - Starting Backup with Script $0 Version $version";
  &log($green_css);
}

# Start Backup of all Miniservers
for($msno = 1; $msno <= $miniservers; $msno++) {
	
  $logmessage = "Starting Backup for Miniserver $msno";
  &log($ms_css);
	
	open(F,">$installfolder/webfrontend/html/plugins/miniserverbackup/backupstate.txt");
  print F "$msno";
  close (F);

  $logmessage = "Starting Backup";
  &log($green_css);

  $miniserverip       = $cfg->param("MINISERVER$msno.IPADDRESS");
  $miniserveradmin    = $cfg->param("MINISERVER$msno.ADMIN");
  $miniserverpass     = $cfg->param("MINISERVER$msno.PASS");
  $miniserverpport    = $cfg->param("MINISERVER$msno.PORT");
  $useclouddns        = $cfg->param("MINISERVER$msno.USECLOUDDNS");
  $miniservercloudurl = $cfg->param("MINISERVER$msno.CLOUDURL");

  # Get Firmware Version from Miniserver

  if ( ${useclouddns} eq "1" )
  {
   $logmessage = "Using Cloud-DNS http://$clouddns/$miniservercloudurl for Backup";
   &log($green_css);
   
   $dns_info = `$home/webfrontend/cgi/system/tools/showclouddns.pl $miniservercloudurl`;
   $logmessage = "Resolving DNS: $dns_info ($home/webfrontend/cgi/system/tools/showclouddns.pl $miniservercloudurl)";
   &log($green_css);
   
   my @dns_info_pieces = split /:/, $dns_info;
   if ($dns_info_pieces[1])
   {
    $dns_info_pieces[1] =~ s/^\s+|\s+$//g;
    $miniserverport = $dns_info_pieces[1];
   }
   else
   {
    $miniserverport  = 80;
   }
   if ($dns_info_pieces[0])
   {
    $dns_info_pieces[0] =~ s/^\s+|\s+$//g;
    $miniserverip = $dns_info_pieces[0]; 
   }
   else
   {
    $miniserverip = "127.0.0.1"; 
   }
   $url = "http://$miniserveradmin:$miniserverpass\@$miniserverip\:$miniserverport/dev/cfg/version";
  }
  else
  {
   if ( $miniserverport eq "" )
   {
   	$miniserverport = 80;
   } 
   $url = "http://$miniserveradmin:$miniserverpass\@$miniserverip\:$miniserverport/dev/cfg/version";
  }
  $logmessage = "Try to read Firmware Version ($url)";
  &log($green_css);
  $ua = LWP::UserAgent->new;
  $ua->timeout(1);
  local $SIG{ALRM} = sub { die };
  eval {
    alarm(1);
    $response = $ua->get($url);
    if (!$response->is_success) {
      $errormessage = "Unable to fetch Firmware Version. Giving up.";
      &error;
      next;
    } else {
      $success = 1;
    }
  };
  alarm(0);

  if (!$success) {
    $errormessage = "Unable to fetch Firmware Version. Giving up.";
    &error;
    next;
  }
  $success = 0;
 
  $rawxml = $response->decoded_content();
  $xml = XMLin($rawxml, KeyAttr => { LL => 'value' }, ForceArray => [ 'LL', 'value' ]);
  @fields = split(/\./,$xml->{value});
  $mainver = sprintf("%02d", $fields[0]);
  $subver  = sprintf("%02d", $fields[1]);
  $monver  = sprintf("%02d", $fields[2]);
  $dayver  = sprintf("%02d", $fields[3]);

  $logmessage = "Miniserver-Version: ".$xml->{value};
  &log($green_css);

  # Get FTP Port from Miniserver
  $url = "http://$miniserveradmin:$miniserverpass\@$miniserverip\:$miniserverport/dev/cfg/ftp";
  $ua = LWP::UserAgent->new;
  $ua->timeout(1);
  local $SIG{ALRM} = sub { die };
  eval {
    alarm(1);
    $response = $ua->get($url);
    if (!$response->is_success) {
      $errormessage = "Unable to fetch FTP Port. Giving up.";
      &error;
      next;
    } else {
      $success = 1;
    }
  };
  alarm(0);

  if (!$success) {
    $errormessage = "Unable to fetch FTP Port. Giving up.";
    &error;
    next;
  }
  $success = 0;
 
  $rawxml = $response->decoded_content();
  $xml = XMLin($rawxml, KeyAttr => { LL => 'value' }, ForceArray => [ 'LL', 'value' ]);
  $miniserverftpport = $xml->{value};

  $logmessage = "Using FTP-Port $miniserverftpport for Backup";
  &log($green_css);
  # Backing up to temorary directory
  ($dirsec,$dirmin,$dirhour,$dirmday,$dirmon,$diryear,$dirwday,$diryday,$dirisdst) = localtime();
  $diryear = $diryear+1900;
  $dirmon = $dirmon+1;
  $dirmon = sprintf("%02d", $dirmon);
  $dirmday = sprintf("%02d", $dirmday);
  $dirhour = sprintf("%02d", $dirhour);
  $dirmin = sprintf("%02d", $dirmin);
  $dirsec = sprintf("%02d", $dirsec);

  # Create temporary dir
  $bkpdir = "Backup_$miniserverip_Miniserver$msno\_$diryear$dirmon$dirmday$dirhour$dirmin$dirsec\_$mainver$subver$monver$dayver";
  $response = mkdir("/tmp/$bkpdir",0777);
  if ($response == 0) {
    $errormessage = "Could not create temporary folder /tmp/$bkpdir. Giving up.";
    &error;
    next;
  }
  if ($verbose) {
    $logmessage = "Temporary folder created: /tmp/$bkpdir.";
    &log($green_css);
  }


  $logmessage = "Starting Download";
  &log($green_css);

  # Download files from Miniserver
  # /log
  $url = "ftp://$miniserveradmin:$miniserverpass\@$miniserverip:$miniserverftpport/log";
  &download;
  # /prog
  $url = "ftp://$miniserveradmin:$miniserverpass\@$miniserverip:$miniserverftpport/prog";
  &download;
  # /sys
  $url = "ftp://$miniserveradmin:$miniserverpass\@$miniserverip:$miniserverftpport/sys";
  &download;
  # /stats
  $url = "ftp://$miniserveradmin:$miniserverpass\@$miniserverip:$miniserverftpport/stats";
  &download;
  # /temp
  $url = "ftp://$miniserveradmin:$miniserverpass\@$miniserverip:$miniserverftpport/temp";
  &download;
  # /update
  $url = "ftp://$miniserveradmin:$miniserverpass\@$miniserverip:$miniserverftpport/update";
  &download;
  # /web
  $url = "ftp://$miniserveradmin:$miniserverpass\@$miniserverip:$miniserverftpport/web";
  &download;
  # /user
  $url = "ftp://$miniserveradmin:$miniserverpass\@$miniserverip:$miniserverftpport/user";
  &download;

  $logmessage = "Compressing Backup ...";
  &log($green_css);
  
  # Zipping
  our @output = qx(cd /tmp && $zipbin -q -p -r $bkpdir.zip $bkpdir);
  if ($? ne 0) {
    $error=1;
  	$logmessage = "Compressing Error!";
  	&log($red_css);
    $errormessage = "Error while zipping the Backup $bkpdir. Errorcode: $?. Giving up.";
    &error;
    next;
  } else {
    if ($verbose) {
      $logmessage = "ZIP-Archive /tmp/$bkpdir/$bkpdir.zip created successfully.";
      &log($green_css);
    }
  }
  
  $logmessage = "Moving Backup to Download folder...";
  &log($green_css);
  
  # Moving ZIP to files section
  move("/tmp/$bkpdir.zip","$installfolder/webfrontend/html/plugins/$subfolder/files/$bkpdir.zip");
  if (!-e "$installfolder/webfrontend/html/plugins/$subfolder/files/$bkpdir.zip") {
    $error=1;
  	$logmessage = "Moving Error!";
  	&log($red_css);
    $errormessage = "Error while moving ZIP-Archive $bkpdir.zip to Files-Section. Giving up.";
    &error;
    next;
  } else {
    if ($verbose) {
      $logmessage = "Moving ZIP-Archive $bkpdir.zip to Files-Section successfully.";
      &log($green_css);
    }
  }

  # Clean up /tmp folder
  if ($verbose) {
    $logmessage = "Cleaning up temporary and old stuff.";
    &log($green_css);
  }
  @output = qx(rm -r /tmp/Backup_* > /dev/null 2>&1);

  # Delete old backup archives
  $i = 0;
  @files = "";
  @Eintraege = "";

  opendir(DIR, "$installfolder/webfrontend/html/plugins/$subfolder/files");
    @Eintraege = readdir(DIR);
  closedir(DIR);

  foreach(@Eintraege) {
    if ($_ =~ m/$Backup_$miniserverip/) {
      push(@files,$_);
    }
  }

  @files = sort {$b cmp $a}(@files);

  foreach(@files) {
    s/[\n\r]//g;
    $i++;
    if ($i > $maxfiles && $_ ne "") {
      $logmessage = "Deleting old Backup $_";
      &log($green_css);
      unlink("$installfolder/webfrontend/html/plugins/$subfolder/files/$_");
    } 
  }

  # End

		if ($error eq 1)
		{
		  $logmessage = "New Backup $bkpdir.zip created with errors - see log. -END-";
			$something_wrong = 1;
		  &log($red_css);
		}
		else
		{
		  $logmessage = "New Backup $bkpdir.zip created successfully. -END-";
		  &log($green_css);
		  $error = 0;
		}

}
		if ($something_wrong  eq 1)
		{
		  $logmessage = "All Backups created but with errors - see log. -END-";
		  &log($red_css);
		}
		else
		{
		  $logmessage = "All Backups created successfully. -END-";
		  &log($green_css);
		}
open(F,">$installfolder/webfrontend/html/plugins/miniserverbackup/backupstate.txt");
print F "";
close (F);
exit;


##########################################################################
# Subroutinen
##########################################################################

# Logfile
sub log {

  $css = shift;

# Today's date for logfile
  (my $sec,my $min,my $hour,my $mday,my $mon,my $year,my $wday,my $yday,my $isdst) = localtime();
  $year = $year+1900;
  $mon = $mon+1;
  $mon = sprintf("%02d", $mon);
  $mday = sprintf("%02d", $mday);
  $hour = sprintf("%02d", $hour);
  $min = sprintf("%02d", $min);
  $sec = sprintf("%02d", $sec);

  # Clean Username/Password for Logfile
  $logmessage =~ s/\/\/(.*)\:(.*)\@/\/\/xxx\:xxx\@/g;

  # Logfile
  open(F,">>$installfolder/log/plugins/miniserverbackup/backuplog.log");
  print F "<$css> $year-$mon-$mday $hour:$min:$sec Miniserver #$msno: $logmessage</$css>\n";
  close (F);

  return ();
}

# Error Message
sub error {
  our $error = "1";
  $logmessage = "ERROR: $errormessage";
  &log($red_css);
  # Clean up /tmp folder
  @output = qx(rm -r /tmp/Backup_* > /dev/null 2>&1);
  return ();
}

# Download
sub download {

if ($debug eq 1) 
{
	$quiet="  ";
}
else
{
 $quiet=" -q ";
}
    if ($verbose) {
      $logmessage = "Downloading $url ...";
      &log($green_css);
    }
  open(F,">>$installfolder/log/plugins/miniserverbackup/backuplog.log");
  print F "<DWL>";
  close (F);
	system("$wgetbin $quiet --retry-connrefused --tries=15 --waitretry=5 --timeout=30 -nH -r $url -P /tmp/$bkpdir 2>&1 |sed -r 's/$miniserveradmin/xxx/g'|sed -r 's/$miniserverpass/xxx/g' >> $home/log/plugins/miniserverbackup/backuplog.log; test \${PIPESTATUS[0]}-eq 0");
  if ($? ne 0) {
    $logmessage = "Error while fetching $url. Backup may be incomplete. Errorcode: $?";
    $error = 1;
    &log($red_css);
  } else {
    if ($verbose) {
      $logmessage = "Saved $url successfully.";
      &log($green_css);
    }
  open(F,">>$installfolder/log/plugins/miniserverbackup/backuplog.log");
  print F "</DWL>";
  close (F);
    
  }
  return ();
}
