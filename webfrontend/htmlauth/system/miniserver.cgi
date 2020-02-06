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
my $version = "2.0.2.2";

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
		$ms{MSUSECLOUDDNS} = is_enabled ($cfg->param("MINISERVER$msno.USECLOUDDNS")) ? "checked" : "";
		$ms{MSCLOUDURL} = $cfg->param("MINISERVER$msno.CLOUDURL");
		$ms{MSCLOUDURLFTPPORT} = $cfg->param("MINISERVER$msno.CLOUDURLFTPPORT");
		$ms{MSNOTE} = $cfg->param("MINISERVER$msno.NOTE");
		$ms{MSNAME} = $cfg->param("MINISERVER$msno.NAME");
		$ms{MSPREFERSSL} = is_enabled($cfg->param("MINISERVER$msno.PREFERSSL")) ? "true" : "false";
		$ms{MSSSLPORT} = $cfg->param("MINISERVER$msno.SSLPORT");
		
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
	# Not conform with use strict;, but no idea for a better solution...
	$miniservers =  !defined param('miniservers') || param('miniservers') lt 1 ? 1 : param('miniservers');
	
	$cfg->param("BASE.MINISERVERS", $miniservers);

	$msno = 1;
	my %ms;
	
	while ($msno <= $miniservers) {
		# Data from form
		$ms{"miniserverip.$msno"}       				= param("miniserverip$msno");
		$ms{"miniserverport.$msno"}     				= param("miniserverport$msno");
		$ms{"miniserveruser.$msno"}     				= param("miniserveruser$msno");
		$ms{"miniserverkennwort.$msno"} 				= param("miniserverkennwort$msno");
		$ms{"miniservernote.$msno"}     				= param("miniservernote$msno");
		$ms{"miniserverfoldername.$msno"}  		   	= param("miniserverfoldername$msno");
		$ms{"useclouddns.$msno"}        				= param("useclouddns$msno");
		$ms{"miniservercloudurl.$msno"} 				= param("miniservercloudurl$msno");
		$ms{"miniservercloudurlftpport.$msno"} 	= param("miniservercloudurlftpport$msno");
		$ms{"useclouddns.$msno"} = is_enabled( $ms{"useclouddns.$msno"} ) ? "1" : "0";
		$ms{"miniserverpreferssl.$msno"} = is_enabled( param("miniserverpreferssl$msno") ) ? "1" : "0";
		$ms{"miniserversslport.$msno"} = defined param("miniserversslport$msno") ? param("miniserversslport$msno") : 443;
 
	# URL-Encode form data before they are used to test the connection
		$ms{"miniserveruser.$msno"} = uri_escape($ms{"miniserveruser.$msno"});
		$ms{"miniserverkennwort.$msno"} = uri_escape($ms{"miniserverkennwort.$msno"});
		# Write configuration file(s)
		$cfg->param("MINISERVER$msno.PORT", $ms{"miniserverport.$msno"});
		$cfg->param("MINISERVER$msno.PASS", $ms{"miniserverkennwort.$msno"});
		$cfg->param("MINISERVER$msno.ADMIN", $ms{"miniserveruser.$msno"});
		$cfg->param("MINISERVER$msno.IPADDRESS", $ms{"miniserverip.$msno"});
		$cfg->param("MINISERVER$msno.USECLOUDDNS", $ms{"useclouddns.$msno"});
		$cfg->param("MINISERVER$msno.CLOUDURL", $ms{"miniservercloudurl.$msno"});
		$cfg->param("MINISERVER$msno.CLOUDURLFTPPORT", $ms{"miniservercloudurlftpport.$msno"});
		$cfg->param("MINISERVER$msno.NOTE", $ms{"miniservernote.$msno"});
		$cfg->param("MINISERVER$msno.NAME", $ms{"miniserverfoldername.$msno"});
		$cfg->param("MINISERVER$msno.PREFERSSL", $ms{"miniserverpreferssl.$msno"});
		$cfg->param("MINISERVER$msno.SSLPORT", $ms{"miniserversslport.$msno"});
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

