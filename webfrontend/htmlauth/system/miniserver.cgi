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
use CGI::Carp qw(fatalsToBrowser);
use CGI qw/:standard/;
use LWP::UserAgent;
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
my $version = "2.0.2.5";

my $cfg = new Config::Simple("$lbhomedir/config/system/general.cfg");
my $bins = LoxBerry::System::get_binaries();

$miniservers        = $cfg->param("BASE.MINISERVERS");
$clouddnsaddress    = $cfg->param("BASE.CLOUDDNS");
$miniserversprev    = $miniservers;

my $maintemplate = HTML::Template->new(
		filename => "$lbstemplatedir/miniserver.html",
		global_vars => 1,
		loop_context_vars => 1,
		die_on_bad_params=> 0,
		associate => $cfg,
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

my $form_mscount = $cgi->param("miniservers");
$R::saveformdata if (0);
$R::do if (0);
if ($cgi->param("addbtn")) {
	$miniservers = $form_mscount + 1;
	$cfg->param("BASE.MINISERVERS", $miniservers);
	param('miniservers', $miniservers);
#	$cfg->save();
	&save;
	&form;
	exit;
} elsif ($cgi->param("delbtn") && $form_mscount gt 1) {
	$cfg->set_block("MINISERVER$form_mscount", {});
	$miniservers = $form_mscount - 1;
	$cfg->param("BASE.MINISERVERS", $miniservers);
	param('miniservers', $miniservers);
	# $cfg->save();
	&save;
	&form;
	exit;
} elsif (!$R::saveformdata || $R::do eq "form") {
  &form;
  exit;
} else {
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
	
	for ($msno = 1; $msno<=$miniservers; $msno++) {	
	
		my %ms;
		$ms{MSNO} = $msno;
		$ms{MSIP} = $cfg->param("MINISERVER$msno.IPADDRESS");
		$ms{MSPORT} = $cfg->param("MINISERVER$msno.PORT");
		$ms{MSUSER} = uri_unescape($cfg->param("MINISERVER$msno.ADMIN"));
		$ms{MSPASS} = uri_unescape($cfg->param("MINISERVER$msno.PASS"));
		$ms{MSUSECLOUDDNS} = is_enabled( $cfg->param("MINISERVER$msno.USECLOUDDNS") ) ? "true" : "false";
		$ms{MSCLOUDURL} = $cfg->param("MINISERVER$msno.CLOUDURL");
		$ms{MSCLOUDURLFTPPORT} = $cfg->param("MINISERVER$msno.CLOUDURLFTPPORT");
		$ms{MSNOTE} = $cfg->param("MINISERVER$msno.NOTE");
		$ms{MSNAME} = $cfg->param("MINISERVER$msno.NAME");
		$ms{MSPREFERHTTPS} = is_enabled($cfg->param("MINISERVER$msno.PREFERHTTPS")) ? "true" : "false";
		$ms{MSPORTHTTPS} = $cfg->param("MINISERVER$msno.PORTHTTPS");
		
		push(@msdata, \%ms);
	}
		
	$maintemplate->param(MSDATA => \@msdata);
		
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
	
	$cfg->param("BASE.MINISERVERS", $miniservers);

	$msno = 1;
	my %ms;
	
	while ($msno <= $miniservers) {
		
		$cfg->param("MINISERVER$msno.IPADDRESS", param("miniserverip$msno") );
		$cfg->param("MINISERVER$msno.PORT", defined param("miniserverport$msno") ? param("miniserverport$msno") : 80 );
		$cfg->param("MINISERVER$msno.NOTE", param("miniservernote$msno"));
		$cfg->param("MINISERVER$msno.USECLOUDDNS", is_enabled( param("useclouddns$msno") ) ? '1' : '0' );
		$cfg->param("MINISERVER$msno.CLOUDURL", param("miniservercloudurl$msno") );
		$cfg->param("MINISERVER$msno.CLOUDURLFTPPORT", param("miniservercloudurlftpport$msno") );
		$cfg->param("MINISERVER$msno.PREFERHTTPS", is_enabled( param("miniserverpreferhttps$msno") ) ? "1" : "0" );
		$cfg->param("MINISERVER$msno.PORTHTTPS", defined param("miniserverporthttps$msno") ? param("miniserverporthttps$msno") : 443 );
		$cfg->param("MINISERVER$msno.NAME", param("miniserverfoldername$msno") );
		# Credentials are RAW and URI-encoded
		$cfg->param("MINISERVER$msno.ADMIN", uri_escape( param("miniserveruser$msno") ) );
		$cfg->param("MINISERVER$msno.PASS", uri_escape( param("miniserverkennwort$msno") ) );
		
		# Save calculated values
		my $transport;
		$transport = $cfg->param("MINISERVER$msno.PREFERHTTPS") ? 'https' : 'http';
		$cfg->param("MINISERVER$msno.TRANSPORT", $transport );
		
		# Check if ip format is IPv6
		my $IPv6Format = '0';
		my $ipaddress = $cfg->param("MINISERVER$msno.IPADDRESS");
		if( $cfg->param("MINISERVER$msno.USECLOUDDNS") eq '1' or index( $ipaddress, ':' ) != -1 ) {
			$IPv6Format = '1';
		}
		$cfg->param("MINISERVER$msno.IPV6FORMAT", $IPv6Format );
		
		# Build FullURI from Credentials
		my $FullURI;
		if ( $cfg->param("MINISERVER$msno.USECLOUDDNS") eq '0' ) {
			$ipaddress = $IPv6Format eq '1' ? '['.$ipaddress.']' : $ipaddress;
			my $port = $cfg->param("MINISERVER$msno.PREFERHTTPS") eq '1' ? $cfg->param("MINISERVER$msno.PORTHTTPS") : $cfg->param("MINISERVER$msno.PORT");
			$FullURI = $transport.'://'.$cfg->param("MINISERVER$msno.ADMIN").':'.$cfg->param("MINISERVER$msno.PASS").'@'.$ipaddress.':'.$port;
		} else {
			$FullURI = "";
		}
		$cfg->param("MINISERVER$msno.FULLURI", $FullURI );
		
		
		# Next
		$msno++;
	}

	# Deleting old Miniserver if any (TODO: How to delete the BLOCKs?!?)
	
	while ($miniserversprev > $miniservers) {
		$cfg->set_block("MINISERVER$miniserversprev", {});
		$miniserversprev--;
	}

	# Save Config
	$cfg->save();

	if ($cgi->param("delbtn") || $cgi->param("addbtn")) { 
		return;
	}
	
	my $maintemplate = HTML::Template->new(
		filename => "$lbstemplatedir/success.html",
		global_vars => 1,
		loop_context_vars => 1,
		die_on_bad_params=> 0,
		associate => $cfg,
		%htmltemplate_options,
		# debug => 1,
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

