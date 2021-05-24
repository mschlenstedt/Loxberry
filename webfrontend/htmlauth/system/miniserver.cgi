#!/usr/bin/perl

# Copyright 2016-2020 Michael Schlenstedt, michael@loxberry.de
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

use LoxBerry::Web;
use LoxBerry::System::General;
use CGI::Carp qw(fatalsToBrowser);
use CGI qw/:standard/;
use URI::Escape;
use warnings;
use strict;
print STDERR "Execute miniserver.cgi\n######################\n";


##########################################################################
# Variables
##########################################################################

my $helpurl = "https://www.loxwiki.eu/x/QYgKAw";
my $helptemplate = "help_miniserver.html";

my $lang;
my $template_title;
my $error;
my $url;
my $ua;
my $response;
my $urlstatus;
my $urlstatuscode;
my $miniservers;
my $miniserversprev;
my $msno;
my $clouddnsaddress;

##########################################################################
# Read Settings
##########################################################################

# Version of this script
my $version = "2.2.1.1";

my $jsonobj = LoxBerry::System::General->new();
my $cfg = $jsonobj->open();
my $bins = LoxBerry::System::get_binaries();

# Miniserver count from json
$miniservers        = scalar keys %{$cfg->{Miniserver}};
#$clouddnsaddress    = $cfg->{Base}->{Clouddnsuri};
#$miniserversprev    = $miniservers;

my $maintemplate = HTML::Template->new(
		filename => "$lbstemplatedir/miniserver.html",
		global_vars => 1,
		loop_context_vars => 1,
		die_on_bad_params=> 0,
		%htmltemplate_options,
		# debug => 1,
		);
	
my %SL = LoxBerry::System::readlanguage($maintemplate);

#########################################################################
# Parameter
#########################################################################

our  $cgi = CGI->new;
$cgi->import_names('R');

##########################################################################
# Language Settings
##########################################################################

$lang = lblanguage();

##########################################################################
# Main program
##########################################################################

#########################################################################
# What should we do
#########################################################################

$R::saveformdata if (0);
$R::do if (0);

if ($cgi->param("addbtn")) {
	# Add button
	# Figure out the highest number of Miniserver id's 
	my $max = 0;
	$_ > $max and $max = $_ for keys %{$cfg->{Miniserver}};
	my $newid = int($max) + 1;
	$cfg->{Miniserver}->{$newid}->{Name} = "";
	$jsonobj->write();
	$miniservers = scalar keys %{$cfg->{Miniserver}};
	&form;
	exit;
} elsif ( $cgi->param("delbtn") ) {
	# Delete button
	# POST value 'delbtn' sends the id of the last element in list to delete
	if ( keys %{$cfg->{Miniserver}} > 1 ) {
		delete $cfg->{Miniserver}->{ $cgi->param("delbtn") };
		$jsonobj->write();
		$miniservers = scalar keys %{$cfg->{Miniserver}};	
	}
	
	&form;
	exit;
} elsif (!$R::saveformdata || $R::do eq "form") {
  # Show form
  &form;
  exit;
} else {
  # Save form data
  &save;
  exit;
}

exit;

#####################################################
# Form
#####################################################

sub form {

	print STDERR "Calling subfunction FORM\n";
	$maintemplate->param("FORM", 1);
	$maintemplate->param( "LANG", $lang);
	$maintemplate->param ( "SELFURL", $ENV{REQUEST_URI});
	
	$maintemplate->param ( "MINISERVERS", $miniservers);
	
	my @msdata = ();
	my $lastkey;
	
	foreach my $msno (sort {$a <=> $b} keys %{$cfg->{Miniserver}} ) {	
		$lastkey = $msno;
		my %ms;
		my $curms = $cfg->{Miniserver}->{$msno};
		$ms{MSNO} = $msno;
		$ms{MSIP} = $curms->{Ipaddress};
		$ms{MSPORT} = $curms->{Port};
		$ms{MSUSER} = uri_unescape($curms->{Admin});
		$ms{MSPASS} = uri_unescape($curms->{Pass});
		$ms{MSUSECLOUDDNS} = is_enabled( $curms->{Useclouddns} ) ? "true" : "false";
		$ms{MSCLOUDURL} = $curms->{Cloudurl};
		$ms{MSCLOUDURLFTPPORT} = $curms->{Cloudurlftpport};
		$ms{MSNOTE} = $curms->{Note};
		$ms{MSNAME} = $curms->{Name};
		$ms{MSPREFERHTTPS} = is_enabled( $curms->{Preferhttps} ) ? "true" : "false";
		$ms{MSPORTHTTPS} = $curms->{Porthttps};
		
		push(@msdata, \%ms);
	}
		
	$maintemplate->param(MSDATA => \@msdata);
	$maintemplate->param(LASTKEY => $lastkey);
	
	# Print Template
	$template_title = $SL{'COMMON.LOXBERRY_MAIN_TITLE'} . ": " . $SL{'MINISERVER.WIDGETLABEL'};
	LoxBerry::Web::head();
	LoxBerry::Web::pagestart($template_title, $helpurl, $helptemplate);
	print $maintemplate->output();
	undef $maintemplate;			
	LoxBerry::Web::pageend();
	LoxBerry::Web::foot();
	
	exit;

}

#####################################################
# Save
#####################################################

sub save {

	$maintemplate->param( "LANG", $lang);
	$maintemplate->param ( "SELFURL", $ENV{REQUEST_URI});
	
	# Everything from Forms
	$miniservers =  !defined param('miniservers') || param('miniservers') lt 1 ? 1 : param('miniservers');
	
	$msno = 1;
	my %ms;
	
	while ($msno <= $miniservers) {
		my %ms;
		my $curms = $cfg->{Miniserver}->{$msno};
		$curms->{Ipaddress} = param("miniserverip$msno");
		$curms->{Port} = defined param("miniserverport$msno") ? param("miniserverport$msno") : 80 ;
		$curms->{Note} = param("miniservernote$msno");
		$curms->{Useclouddns} = is_enabled( scalar param("useclouddns$msno") ) ? '1' : '0' ;
		$curms->{Cloudurl} = param("miniservercloudurl$msno");
		$curms->{Cloudurlftpport} = param("miniservercloudurlftpport$msno");
		$curms->{Preferhttps} = is_enabled( scalar param("miniserverpreferhttps$msno") ) ? "1" : "0" ;
		$curms->{Porthttps} = defined param("miniserverporthttps$msno") ? param("miniserverporthttps$msno") : 443 ;
		$curms->{Name} = param("miniserverfoldername$msno");
		# Credentials are RAW and URI-encoded
		$curms->{Admin_raw} = param("miniserveruser$msno");
		$curms->{Pass_raw} = param("miniserverkennwort$msno");
		$curms->{Admin} = uri_escape( scalar param("miniserveruser$msno") );
		$curms->{Pass} = uri_escape( scalar param("miniserverkennwort$msno") );
		$curms->{Credentials} = $curms->{Admin}.':'.$curms->{Pass};
		$curms->{Credentials_raw} = $curms->{Admin_raw}.':'.$curms->{Pass_raw};
		
		# Save calculated values
		my $transport;
		$transport = $curms->{Preferhttps} eq '1' ? 'https' : 'http';
		$curms->{Transport} = $transport;
		
		# Check if ip format is IPv6
		my $IPv6Format = '0';
		my $ipaddress = $curms->{Ipaddress};
		if( $curms->{Preferhttps} eq '1' or index( $ipaddress, ':' ) != -1 ) {
			$IPv6Format = '1';
		}
		$curms->{Ipv6format} = $IPv6Format;
		
		# Build FullURI from Credentials
		my ($FullURI, $FullURI_RAW);
		if ( $curms->{Useclouddns} eq '0' ) {
			$ipaddress = $IPv6Format eq '1' ? '['.$ipaddress.']' : $ipaddress;
			my $port = $curms->{Preferhttps} eq '1' ? $curms->{Porthttps} : $curms->{Port};
			$FullURI = $transport.'://'.$curms->{Admin}.':'.$curms->{Pass}.'@'.$ipaddress.':'.$port;
			$FullURI_RAW = $transport.'://'.$curms->{Admin_raw}.':'.$curms->{Pass_raw}.'@'.$ipaddress.':'.$port;
		} else {
			$FullURI = "";
			$FullURI_RAW = "";
		}
		$curms->{Fulluri} = $FullURI;
		$curms->{Fulluri_raw} = $FullURI_RAW;
		
		
		# Next
		$msno++;
	}

	# Save Config
	$jsonobj->write();

	if ($cgi->param("delbtn") || $cgi->param("addbtn")) { 
		return;
	}
	
	my $maintemplate = HTML::Template->new(
		filename => "$lbstemplatedir/success.html",
		global_vars => 1,
		loop_context_vars => 1,
		die_on_bad_params=> 0,
		%htmltemplate_options,
	);
	
	my %SL = LoxBerry::System::readlanguage($maintemplate);

	$maintemplate->param ( "NEXTURL", "/admin/system/index.cgi?form=system");
	$maintemplate->param ( "MESSAGE", $SL{'MINISERVER.SAVE_OK_MSG'});
	# Print Template
	$template_title = $SL{'COMMON.LOXBERRY_MAIN_TITLE'} . ": " . $SL{'MINISERVER.WIDGETLABEL'};
	LoxBerry::Web::lbheader($template_title, $helpurl, $helptemplate);
	print $maintemplate->output();
	LoxBerry::Web::lbfooter();
	undef $maintemplate;			
	
	exit;

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
	$maintemplate->param( "ERRORFORM", 1);
	LoxBerry::Web::lbheader();
	print $maintemplate->output();
	LoxBerry::Web::lbfooter();
	
	exit;

}

