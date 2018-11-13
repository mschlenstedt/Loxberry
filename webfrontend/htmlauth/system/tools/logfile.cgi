#!/usr/bin/perl

# Copyright 2016-2017 Michael Schlenstedt, michael@loxberry.de
#                Wörsty, git@loxberry.woerstenfeld.de
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

# use LoxBerry::Web;
use CGI;
use Getopt::Long;
use warnings;
use strict;

##########################################################################
# Read Settings
##########################################################################

# Version of this script
my $version = "1.2.0.4";
my $iscgi;
my $maintemplate;
my %SL;
my $template_title;

my $cfg = new Config::Simple("$lbsconfigdir/general.cfg");

my $cgi = CGI->new;
$cgi->import_names('R');

if ($R::lang) {
	$LoxBerry::System::lang = substr($R::lang, 0, 2);
}
my $lang = LoxBerry::System::lblanguage();

# $lang            = $cfg->param("BASE.LANG");

# Read translations
# $phrase = new Config::Simple($languagefile);

#########################################################################
# Parameter
#########################################################################
# Are we called from a browser/web enviroment?
if ($ENV{'HTTP_HOST'}) {

 # use CGI::Carp qw(fatalsToBrowser);
  # use CGI qw/:standard/;
	  
	$iscgi = 1;
	
	
	if ($R::format eq 'template') {
		require LoxBerry::Web;
		$maintemplate = HTML::Template->new(
						filename => "$lbstemplatedir/logfile.html",
						global_vars => 1,
						loop_context_vars => 1,
						die_on_bad_params=> 0,
						associate => $cfg,
					);
		%SL = LoxBerry::System::readlanguage($maintemplate);
		
	} else {
		%SL = LoxBerry::System::readlanguage();
	}

	
	$template_title = "$SL{'COMMON.LOXBERRY_MAIN_TITLE'}: $SL{'LOGVIEWER.WIDGETLABEL'}";

  
 
# Or from a terminal?
} else {
  
  GetOptions ('header=s'  => \$R::header,
              'logfile=s' => \$R::logfile,
              'format=s'  => \$R::format,
              'offset=i'  => \$R::offset,
              'length'    => \$R::length,
			  'package'	  => \$R::package,
			  'name'	  => \$R::name,
  );

}

##########################################################################
# Main program
##########################################################################

# Which Output Format
if (!$R::format) {
  $R::format = "plain";
}

# If package and/or name was used, get the latest logfile name.
if (! $R::logfile and $R::package) {
	require LoxBerry::Log;
	my @logs = LoxBerry::Log::get_logs( $R::package, $R::name); 
	if ($logs[0]->{FILENAME}) {
		$R::logfile = $logs[0]->{FILENAME};
	} else {
		$R::logfile = "/not/existing";
	}
}

# Check if logfile exists
# Note: Only ~/log, ~/webfrontend/html/tmp and /tmp are allowed
# for security reasons

# Check if logfile parameter provided
if (!$R::logfile) {
  if ($iscgi && $R::format eq 'template') {
    $maintemplate->param('NOLOGPARAMETER', 1);
	LoxBerry::Web::head();
	print $maintemplate->output();
	LoxBerry::Web::foot();
	exit(1);
	
  } 
  else {
    print $SL{'LOGVIEWER.ERR_MISSING_LOGPARAMETER_TXT'};
	exit (1);
	}
}

if (begins_with($R::logfile, $lbhomedir . "/log")) {
	$R::logfile = substr($R::logfile, length($lbhomedir . "/log"));
}
$R::logfile =~ s/^\///;

# Check if logfile exists
if (-e "/tmp/$R::logfile") {
  $R::logfilepath = "/tmp";
} elsif (-e "$lbhomedir/log/$R::logfile") {
  $R::logfilepath = "$lbhomedir/log";
} elsif (-e "$lbhomedir/webfrontend/html/tmp/$R::logfile") {
  $R::logfilepath = "$lbhomedir/webfrontend/html/tmp";
} else {
	# File does not exist
	if ($iscgi && $maintemplate) {
		$maintemplate->param('NOLOGFILE', 1);
		LoxBerry::Web::head();
		print $maintemplate->output();
		LoxBerry::Web::foot();
	   
	} elsif ($iscgi) {
		print $cgi->header(-type => 'text/plain;charset=utf-8');
		print $SL{'LOGVIEWER.ERR_NOLOG_TXT'};
	} else {
		print $SL{'LOGVIEWER.ERR_NOLOG_TXT'};
	}
	exit (1);
}

$maintemplate->param('LOGFILE', $R::logfile) if ($R::format eq 'template');

my $i;
# Print number of lines of logfile
if ($R::length) {
  $i = 0;
  open(F,"$R::logfilepath/$R::logfile") || die "Cannot open file: $!";
    while (<F>) {
      $i++
    }
  close(F);
  print $i;
  exit;
}

# Which header
my $header;
my $currfilesize = -s "$R::logfilepath/$R::logfile";

if (!$R::header || ($R::header ne "txt" && $R::header ne "file" && $R::header ne "html") ) {
	$R::header = "html";
}
if ($R::header && $R::header eq "txt") {
	$header = "Content-Type: text/plain;charset=utf-8\n\n";
	print $header;
} elsif ($R::header && $R::header eq "file" ) {
	use File::Basename;
	$header = "Content-Disposition: attachment; filename='" . basename($R::logfile) . "'\n\n";
  	print $header;
} elsif ($R::header && $R::header eq "html" || ($iscgi && !$R::header) ) {
	if ($R::clientsize && $R::clientsize ne "0") {
		if($R::clientsize eq $currfilesize) {
			$header = $cgi->header(-type => 'text/html;charset=utf-8',
						-status => "304 Not Modified",
						-filesize => $currfilesize,
			);
			print $header;
			exit(0);
		}
	}
	# print $cgi->header('text/html','304 Not Modified');
	$header = $cgi->header(-type => 'text/html;charset=utf-8',
			     -filesize => $currfilesize,
	);
	print $header if ($R::format ne 'template');
	# $header = "Content-Type: text/html\n\n";
} 


# Template Output
if ($R::format eq "template") {
	LoxBerry::Web::head();
}


# Print Logfile
my @logcontent;
my $l = 0;
open(F,"$R::logfilepath/$R::logfile") || die "Cannot open file: $!";
  while (<F>) {
    # Offset
    if ($R::offset) {
      $i++;
      if ($i <= $R::offset) {
        next;
      }
    }
    # HTML Output
    if ($R::format eq "html" || $R::format eq "template") {
      $_ =~ s/([\e].*?)[m]//g;
	  $_ =~ s/^(.*?)\s*<EMERGE>\s*(.*?)$/<div class='logemerge'>$1 <FONT color=red><B>EMERGE:<\/B><\/FONT> $2<\/div>/g;
     # $_ =~ s/<\/EMERGE>//g;
      $_ =~ s/^(.*?)\s*<ALERT>\s*(.*?)$/<div class='logalert'>$1 <FONT color=red><B>ALERT:<\/B><\/FONT> $2<\/div>/g;
     # $_ =~ s/<\/ALERT>//g;
      $_ =~ s/^(.*?)\s*<FAIL>\s*(.*?)$/<div class='logcrit'>$1 <FONT color=red><B>CRITICAL:<\/B><\/FONT> $2<\/div>/g;
      $_ =~ s/<\/FAIL>//g;
      $_ =~ s/^(.*?)\s*<CRITICAL>\s*(.*?)$/<div class='logcrit'>$1 <FONT color=red><B>CRITICAL:<\/B><\/FONT> $2<\/div>/g;
     # $_ =~ s/<\/CRITICAL>//g;
	  $_ =~ s/^(.*?)\s*<ERROR>\s*(.*?)$/<div class='logerr'>$1 <FONT color=red><B>ERROR:<\/B><\/FONT> $2<\/div>/g;
      $_ =~ s/<\/ERROR>//g;
      $_ =~ s/^(.*?)\s*<WARNING>\s*(.*?)$/<div class='logwarn'>$1 <FONT color=red><B>WARNING:<\/B><\/FONT> $2<\/div>/g;
      $_ =~ s/<\/WARNING>//g;
      $_ =~ s/^(.*?)\s*<OK>\s*(.*?)$/<div class='logok'>$1 <FONT color=green><B>OK:<\/B><\/FONT> $2<\/div>/g;
      $_ =~ s/<\/OK>//g;
      $_ =~ s/^(.*?)\s*<INFO>\s*(.*?)$/<div class='loginf'>$1 <FONT color=black><B>INFO:<\/B> $2<\/FONT><\/div>/g;
      $_ =~ s/<\/INFO>//g;
      $_ =~ s/^(.*?)\s*<DEBUG>\s*(.*?)$/<div class='logdeb'>$1 <FONT color=darkgray><B>DEBUG:<\/B><\/FONT> $2<\/div>/g;
      $_ =~ s/<\/DEBUG>//g;
	  $_ =~ s/^(.*?)\s*<LOGSTART>\s*(.*?)$/<div class='logstart'>$1 $2<\/div>/g;
      $_ =~ s/^(.*?)\s*<LOGEND>\s*(.*?)$/<div class='logend'>$1 $2<\/div>/g;
  
      if ($_ !~ /<\/div>\n$/) { # New Line
        $_ =~ s/\n/<br>/g;
      }
    }
    # Terminal Output Colorized
    # http://misc.flogisoft.com/bash/tip_colors_and_formatting
    if ($R::format eq "terminal") { 
      $_ =~ s/^(.*?)(\s*)<EMERGE>\s*(.*?)$/$1$2 \\e[1m\\e[31mEMERGE:\\e[0m $3/g;
      $_ =~ s/^(.*?)(\s*)<ALERT>\s*(.*?)$/$1$2 \\e[1m\\e[31mALERT:\\e[0m $3/g;
      $_ =~ s/^(.*?)(\s*)<FAIL>\s*(.*?)$/$1$2 \\e[1m\\e[31mCRITICAL:\\e[0m $3/g;
      $_ =~ s/^(.*?)(\s*)<CRITICAL>\s*(.*?)$/$1$2 \\e[1m\\e[31mCRITICAL:\\e[0m $3/g;
      $_ =~ s/^(.*?)(\s*)<ERROR>\s*(.*?)$/$1$2\\e[1m\\e[31mERROR:\\e[0m $3/g;
      $_ =~ s/^(.*?)(\s*)<WARNING>\s*(.*?)$/$1$2\\e[1m\\e[31mWARNING:\\e[0m $3/g;
	  $_ =~ s/^(.*?)(\s*)<OK>\s*(.*?)$/$1$2\\e[1m\\e[32mOK:\\e[0m $3/g;
      $_ =~ s/^(.*?)(\s*)<INFO>\s*(.*?)$/$1$2\\e[1mINFO:\\e[0m $3/g;
	  $_ =~ s/^(.*?)(\s*)<DEBUG>\s*(.*?)$/$1$2\\e[1mDEBUG:\\e[0m $3/g;
    }

    if ($R::format ne "plain") { 
      # If someone uses end tags, remove them
    #  $_ =~ s/<\/EMERGE>$//g;
    #  $_ =~ s/<\/ALERT>$//g;
    #  $_ =~ s/<\/CRITICAL>$//g;
      $_ =~ s/<\/FAIL>$//g;
      $_ =~ s/<\/ERROR>$//g;
      $_ =~ s/<\/WARNING>$//g;
	  $_ =~ s/<\/OK>$//g;
      $_ =~ s/<\/INFO>//g;
      $_ =~ s/<\/DEBUG>//g;
    } 

    # Print line
	if ($R::format eq "template") {
		if ($l < 200) {
			my %line;
			$l++;
			$line{'logcontentline'} = "$_";
			push (@logcontent, \%line);
		} else {
			last;
		}
	} else {
		print "$_";
	}
  }
close(F);

# Template Output
if ($R::format eq "template") {
	$maintemplate->param( 'logcontent' => \@logcontent );
	print $maintemplate->output();
	LoxBerry::Web::foot();
	exit;
}




exit;

