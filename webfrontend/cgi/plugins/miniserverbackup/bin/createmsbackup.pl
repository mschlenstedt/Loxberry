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
our $retry_error;
our $maxdwltries;
our $local_miniserver_ip;
##########################################################################
# Read Configuration
##########################################################################

# Version of this script
my $version = "0.0.9";

$cfg             = new Config::Simple("$home/config/system/general.cfg");
$installfolder   = $cfg->param("BASE.INSTALLFOLDER");
$miniservers     = $cfg->param("BASE.MINISERVERS");
$clouddns        = $cfg->param("BASE.CLOUDDNS");
$wgetbin         = $cfg->param("BINARIES.WGET");
$zipbin          = $cfg->param("BINARIES.ZIP");
$curlbin         = $cfg->param("BINARIES.CURL");
$grepbin         = $cfg->param("BINARIES.GREP");
$awkbin          = $cfg->param("BINARIES.AWK");
$lang            = $cfg->param("BASE.LANG");
$maxdwltries     = 15; # Maximale wget Wiederholungen
$pcfg            = new Config::Simple("$installfolder/config/plugins/miniserverbackup/miniserverbackup.cfg");
$debug           = $pcfg->param("MSBACKUP.DEBUG");
$maxfiles        = $pcfg->param("MSBACKUP.MAXFILES");
$subfolder       = $pcfg->param("MSBACKUP.SUBFOLDER");

$languagefileplugin = "$installfolder/templates/plugins/miniserverbackup/$lang/language.dat";
our $phraseplugin 	= new Config::Simple($languagefileplugin);


our $css = "";
#Error Style
#"<div style=\'text-align:left; width:100%; color:#000000; background-color:\'#FFE0E0\';\'>";
our $red_css     = "ERROR";

#Good Style
#"<div style=\'text-align:left; width:100%; color:#000000; background-color:\'#D8FADC\';\'>";
our $green_css     = "OK";

#Download Style
#"<div style=\'text-align:left; width:100%; color:#000000; background-color:\'#F8F4D6\';\'>";
our $dwl_css     = "DWL";

#MS Style
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
if ($verbose) { $logmessage = $miniservers." ".$phraseplugin->param("TXT1001")." $0($version)"; &log($green_css); } # ### Miniserver insgesamt - Starte Backup mit Script / Version 
# Start Backup of all Miniservers
for($msno = 1; $msno <= $miniservers; $msno++) 
{
  # Set Backup Flag
	open(F,">$installfolder/webfrontend/html/plugins/miniserverbackup/backupstate.txt");
  print F "$msno";
  close (F);

  $logmessage = $phraseplugin->param("TXT1002").$msno; &log($green_css); #Starte Backup for Miniserver 

  $miniserverip       = $cfg->param("MINISERVER$msno.IPADDRESS");
  $miniserveradmin    = $cfg->param("MINISERVER$msno.ADMIN");
  $miniserverpass     = $cfg->param("MINISERVER$msno.PASS");
  $miniserverport     = $cfg->param("MINISERVER$msno.PORT");
  $useclouddns        = $cfg->param("MINISERVER$msno.USECLOUDDNS");
  $miniservercloudurl = $cfg->param("MINISERVER$msno.CLOUDURL");

  # Get Firmware Version from Miniserver

  if ( ${useclouddns} eq "1" )
  {
	   $logmessage = $phraseplugin->param("TXT1003")." http://$clouddns/$miniservercloudurl ".$phraseplugin->param("TXT1004"); &log($green_css); # Using Cloud-DNS xxx for Backup 
	   
	   $dns_info = `$home/webfrontend/cgi/system/tools/showclouddns.pl $miniservercloudurl`;
	   $logmessage = $phraseplugin->param("TXT1005")." $dns_info ($home/webfrontend/cgi/system/tools/showclouddns.pl $miniservercloudurl)"; &log($green_css); # DNS Data
	   
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
  }
  else
  {
	   if ( $miniserverport eq "" )
	   {
	 	  	$miniserverport = 80;
	   } 
  }
  $url = "http://$miniserveradmin:$miniserverpass\@$miniserverip\:$miniserverport/dev/cfg/version";
  $logmessage = $phraseplugin->param("TXT1006")." ($url)"; &log($green_css); # Try to read MS Firmware Version
  $ua = LWP::UserAgent->new;
  $ua->timeout(1);
  local $SIG{ALRM} = sub { die };
  eval {
    alarm(1);
    $response = $ua->get($url);
    if (!$response->is_success) 
    {
      $error        = 1;
      $logmessage = $phraseplugin->param("TXT2001"); &error; # Unable to fetch Firmware Version. Giving up.
      next;
    }
    else 
    {
      $success = 1;
    }
  };
  alarm(0);
  if (!$success) 
  {
    $error=1;
		$logmessage = $phraseplugin->param("TXT2001"); &error; # Unable to fetch Firmware Version. Giving up.
    next;
  }
  $success = 0;
  $rawxml  = $response->decoded_content();
  $xml     = XMLin($rawxml, KeyAttr => { LL => 'value' }, ForceArray => [ 'LL', 'value' ]);
  @fields  = split(/\./,$xml->{value});
  $mainver = sprintf("%02d", $fields[0]);
  $subver  = sprintf("%02d", $fields[1]);
  $monver  = sprintf("%02d", $fields[2]);
  $dayver  = sprintf("%02d", $fields[3]);
  $logmessage = $phraseplugin->param("TXT1007").$xml->{value}; &log($green_css); # Miniserver Version


  $url = "http://$miniserveradmin:$miniserverpass\@$miniserverip\:$miniserverport/dev/cfg/ip";
  $logmessage = $phraseplugin->param("TXT1026")." ($url)"; &log($green_css); # Try to read MS Local IP
  $ua = LWP::UserAgent->new;
  $ua->timeout(1);
  local $SIG{ALRM} = sub { die };
  eval {
    alarm(1);
    $response = $ua->get($url);
    if (!$response->is_success) 
    {
      $error        = 1;
      $logmessage = $phraseplugin->param("TXT2008"); &error; # Unable to fetch local IP. Giving up.
      next;
    }
    else 
    {
      $success = 1;
    }
  };
  alarm(0);
  if (!$success) 
  {
    $error=1;
		$logmessage = $phraseplugin->param("TXT2008"); &error; # Unable to fetch local IP. Giving up.
    next;
  }
  $success = 0;
  $rawxml  = $response->decoded_content();
  $xml     = XMLin($rawxml, KeyAttr => { LL => 'value' }, ForceArray => [ 'LL', 'value' ]);
  @fields  = split(/\./,$xml->{value});
  $mainver = sprintf("%02d", $fields[0]);
  $subver  = sprintf("%02d", $fields[1]);
  $monver  = sprintf("%02d", $fields[2]);
  $dayver  = sprintf("%02d", $fields[3]);
  $logmessage = $phraseplugin->param("TXT1027").$xml->{value}; &log($green_css); # Miniserver IP local
  $local_miniserver_ip = $xml->{value};
################################

  # Get FTP Port from Miniserver
  $url = "http://$miniserveradmin:$miniserverpass\@$miniserverip\:$miniserverport/dev/cfg/ftp";
  $ua = LWP::UserAgent->new;
  $ua->timeout(1);
  local $SIG{ALRM} = sub { die };
  eval {
    alarm(1);
    $response = $ua->get($url);
    if (!$response->is_success) 
    {
      $error=1;
      $logmessage = $phraseplugin->param("TXT2002"); &error; # Unable to fetch FTP Port. Giving up. 
      next;
    }
    else
    {
      $success = 1;
    }
  };
  alarm(0);

  if (!$success) 
  {
    $error=1;
    $logmessage = $phraseplugin->param("TXT2002"); &error; # Unable to fetch FTP Port. Giving up. 
    next;
  }
  $success = 0;
  $rawxml = $response->decoded_content();
  $xml = XMLin($rawxml, KeyAttr => { LL => 'value' }, ForceArray => [ 'LL', 'value' ]);
  $miniserverftpport = $xml->{value};
  $logmessage = $phraseplugin->param("TXT1008").$miniserverftpport; &log($green_css); #Using this FTP-Port for Backup: xxx
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
  $bkpdir = "Backup_$local_miniserver_ip\_$diryear$dirmon$dirmday$dirhour$dirmin$dirsec\_$mainver$subver$monver$dayver";
  $response = mkdir("/tmp/$bkpdir",0777);
  if ($response == 0) 
  {
    $error=1;
    $logmessage = $phraseplugin->param("TXT2003")." /tmp/$bkpdir"; &error; # Could not create temporary folder /tmp/$bkpdir. Giving up.
    next;
  }
  if ($verbose) { $logmessage = $phraseplugin->param("TXT1009")." /tmp/$bkpdir"; &log($green_css); } # "Temporary folder created: /tmp/$bkpdir."
  $logmessage = $phraseplugin->param("TXT1010"); &log($green_css); # Starting Download
  # Download files from Miniserver
  # /log
  $url = " ftp://$miniserveradmin:$miniserverpass\@$miniserverip:$miniserverftpport/log "; &download; 
	# /prog
  $url = "ftp://$miniserveradmin:$miniserverpass\@$miniserverip:$miniserverftpport/prog";	&download;
  # /sys
  $url = "ftp://$miniserveradmin:$miniserverpass\@$miniserverip:$miniserverftpport/sys"; &download;
  # /stats
  $url = "ftp://$miniserveradmin:$miniserverpass\@$miniserverip:$miniserverftpport/stats"; &download;
  # /temp
  $url = "ftp://$miniserveradmin:$miniserverpass\@$miniserverip:$miniserverftpport/temp"; &download;
  # /update
  $url = "ftp://$miniserveradmin:$miniserverpass\@$miniserverip:$miniserverftpport/update"; &download;
  # /web
  $url = "ftp://$miniserveradmin:$miniserverpass\@$miniserverip:$miniserverftpport/web"; &download;
  # /user
  $url = "ftp://$miniserveradmin:$miniserverpass\@$miniserverip:$miniserverftpport/user"; &download;

  $logmessage = $phraseplugin->param("TXT1011")." $bkpdir.zip"; &log($green_css); # Compressing Backup xxx ...
  
  # Zipping
  our @output = qx(cd /tmp && $zipbin -q -p -r $bkpdir.zip $bkpdir);
  if ($? ne 0) 
  {
    $error=1;
  	$logmessage = $phraseplugin->param("TXT2004")." $bkpdir (Errorcode: $?)"; &error; # Compressing error
    next;
  } 
  else
  {
    if ($verbose) { $logmessage = $phraseplugin->param("TXT1012"); &log($green_css); } # ZIP-Archive /tmp/$bkpdir/$bkpdir.zip created successfully.
  }
  $logmessage = $phraseplugin->param("TXT1013"); &log($green_css); #Moving Backup to Download folder..."
  
  # Moving ZIP to files section
  move("/tmp/$bkpdir.zip","$installfolder/webfrontend/html/plugins/$subfolder/files/$bkpdir.zip");
  if (!-e "$installfolder/webfrontend/html/plugins/$subfolder/files/$bkpdir.zip") 
  {
    $error=1;
  	$logmessage = $phraseplugin->param("TXT2005")." ($bkpdir.zip)" ; &error; # "Moving Error!"
    next;
  } 
  else 
  {
    if ($verbose) { $logmessage = $phraseplugin->param("TXT1014")." ($bkpdir.zip)"; &log($green_css); }  # Moved ZIP-Archive to Files-Section successfully.
  }

  ABBRUCH:

  # Clean up /tmp folder
  if ($verbose) 
  {
    $logmessage = $phraseplugin->param("TXT1015"); &log($green_css);  # Cleaning up temporary and old stuff.
  }
  @output = qx(rm -r /tmp/Backup_* > /dev/null 2>&1);
  # Delete old backup archives
  $i 					= 0;
  @files 			= "";
  @Eintraege	= "";
  opendir(DIR, "$installfolder/webfrontend/html/plugins/$subfolder/files");
    @Eintraege = readdir(DIR);
  closedir(DIR);
  if ($verbose) { $logmessage = scalar(@Eintraege)." ".$phraseplugin->param("TXT1016")." $installfolder/webfrontend/html/plugins/$subfolder/files "; &log($green_css); } # x files found in dir y
  if ($debug)   { $logmessage = "Files: $installfolder/webfrontend/html/plugins/$subfolder/files :".join(" + ", @Eintraege); &log($green_css); }
  
  foreach(@Eintraege) 
  {
    if ($_ =~ m/$Backup_$local_miniserver_ip/) 
    {
     push(@files,$_);
    }
  }
  @files = sort {$b cmp $a}(@files);
  foreach(@files) 
  {
    s/[\n\r]//g;
    $i++;
    if ($i > $maxfiles && $_ ne "") 
    {
      $logmessage = $phraseplugin->param("TXT1017")." $_"; &log($green_css); # Deleting old Backup $_
      unlink("$installfolder/webfrontend/html/plugins/$subfolder/files/$_");
  	} 
  }
	if ($error eq 0) { $logmessage = $phraseplugin->param("TXT1018")." $bkpdir.zip "; &log($green_css); } # New Backup $bkpdir.zip created successfully.
  $error = 0;
}
$msno = "1 => #".($msno - 1); # Minisever x ... y saved
if ($something_wrong  eq 1)
{
  $logmessage = $phraseplugin->param("TXT1019"); &log($red_css); # Not all Backups created without errors - see log. 
}
else
{
  $logmessage = $phraseplugin->param("TXT1020"); &log($green_css); # All Backups created successfully. 
}
# Remove Backup Flag
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
  if ( $debug ne 1 )
  { 
  	$logmessage =~ s/\/\/(.*)\:(.*)\@/\/\/xxx\:xxx\@/g;
	}
  # Logfile
  open(F,">>$installfolder/log/plugins/miniserverbackup/backuplog.log");
  print F "<$css> $year-$mon-$mday $hour:$min:$sec Miniserver #$msno: $logmessage</$css>\n";
  close (F);

  return ();
}

# Error Message
sub error {
  our $error = "1";
  &log($red_css);
  # Clean up /tmp folder
  @output = qx(rm -r /tmp/Backup_* > /dev/null 2>&1);
  if ( $retry_error eq $maxdwltries ) { $something_wrong = "1"; } 
  return ();
}

# Download
sub download 
{
	if ($debug eq 1) 
	{
		#Debug
		$quiet='  ';
	}
	elsif  ($verbose eq 1) 
	{
		#Verbose
		$quiet=' --no-verbose ';
	}
	else   
	{
		#None
		$quiet=' -q  ';
	}

  if ($verbose) { $logmessage = $phraseplugin->param("TXT1021")." $url ..."; &log($green_css); } # Downloading xxx ....
  for(my $versuche = 1; $versuche < 16; $versuche++) 
	{
				system("$wgetbin $quiet -a $home/log/plugins/miniserverbackup/backuplog.log --retry-connrefused --tries=$maxdwltries --waitretry=5 --timeout=10 --passive-ftp -nH -r $url -P /tmp/$bkpdir ");
			  if ($? ne 0) 
			  {
			    $logmessage = $phraseplugin->param("TXT2006")." $url ".$phraseplugin->param("TXT1022")." $versuche ".$phraseplugin->param("TXT1023")." $maxdwltries (Errorcode: $?)"; &log($red_css); # Try x of y failed 
			    $retry_error = $versuche;
			  } 
			  else 
			  {
		      $logmessage = $phraseplugin->param("TXT1024")." $versuche ".$phraseplugin->param("TXT1023")." $maxdwltries ".$phraseplugin->param("TXT1025")." $url"; &log($dwl_css); # Download ok
			    $retry_error = 0;
			  }
				if ($retry_error eq 0) { last; }
	}
	if ($retry_error eq $maxdwltries)
	{ 
      $error = 1;
 	    $logmessage = $phraseplugin->param("TXT2007")." $url (Errorcode: $?)"; &error; # "Wiederholter Fehler $? beim Speichern von $url. GEBE AUF!!"
    	if ( $retry_error eq $maxdwltries ) { goto ABBRUCH; }
	}
  return ();
}