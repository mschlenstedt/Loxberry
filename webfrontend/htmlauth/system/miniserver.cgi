#!/usr/bin/perl

# Copyright 2016-2017 Michael Schlenstedt, michael@loxberry.de
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
use Config::Simple;
use URI::Escape;
use warnings;
use strict;


##########################################################################
# Variables
##########################################################################

my $helpurl = "http://www.loxwiki.eu/display/LOXBERRY/LoxBerry";
my $helptemplate = "help_miniserver.html";

# my $cfg;
# our $phrase;
# our $namef;
# our $value;
# our %query;
my $lang;
my $template_title;
# our $help;
# our @help;
# our $helptext;
my $helplink;
# our $installfolder;
# our $languagefile;
my $error;
# our $saveformdata;
# our $output;
# our $message;
# our $do;
my $url;
my $ua;
my $response;
my $urlstatus;
my $urlstatuscode;
# our $nexturl;
my $miniservers;
my $miniserversprev;
my $msno;
# our $miniserverip;
# our $miniserverport;
# our $miniserveruser;
# our $miniserverkennwort;
# our $useclouddns;
# our $miniservercloudurl;
# our $miniservercloudurlftpport;
# our $curlbin;
# #our $grepbin;
# our $awkbin;
# our $miniservernote;
# our $miniserverfoldername;
my $clouddnsaddress;

##########################################################################
# Read Settings
##########################################################################

# Version of this script
my $version = "0.3.5.1";

my $cfg = new Config::Simple("$lbhomedir/config/system/general.cfg");
my $bins = LoxBerry::System::get_binaries();

#$installfolder      = $cfg->param("BASE.INSTALLFOLDER");
#$lang               = $cfg->param("BASE.LANG");
$miniservers        = $cfg->param("BASE.MINISERVERS");
$clouddnsaddress    = $cfg->param("BASE.CLOUDDNS");
$miniserversprev    = $miniservers;


#$curlbin            = $cfg->param("BINARIES.CURL");
#$grepbin            = $cfg->param("BINARIES.GREP");
#$awkbin             = $cfg->param("BINARIES.AWK");

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


# # Everything from URL
# foreach (split(/&/,$ENV{'QUERY_STRING'})){
  # ($namef,$value) = split(/=/,$_,2);
  # $namef =~ tr/+/ /;
  # $namef =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/eg;
  # $value =~ tr/+/ /;
  # $value =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/eg;
  # $query{$namef} = $value;
# }

# And this one we really want to use
#$do           = $query{'do'};

# Everything we got from forms
# $saveformdata         = param('saveformdata');


# $saveformdata          =~ tr/0-1//cd;
# $saveformdata          = substr($saveformdata,0,1);

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
if ($cgi->param("addbtn")) {
	$miniservers = $form_mscount + 1;
	$cfg->param("BASE.MINISERVERS", $miniservers);
#	$cfg->save();
	&form;
} elsif ($cgi->param("delbtn") && $form_mscount gt 1) {
	$cfg->set_block("MINISERVER$form_mscount", {});
	$miniservers = $form_mscount - 1;
	$cfg->param("BASE.MINISERVERS", $miniservers);
	$cfg->save();
	&form;
} elsif (!$R::saveformdata || $R::do eq "form") {
  &form;
} else {
  &save;
}

exit;

#####################################################
# Form
#####################################################

sub form {

	print STDERR "FORM called\n";
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
		
		push(@msdata, \%ms);
	}
		
	$maintemplate->param(MSDATA => \@msdata);
		
	# Print Template
	$template_title = $SL{'COMMON.LOXBERRY_MAIN_TITLE'} . ": " . $SL{'MINISERVER.WIDGETLABEL'};
	LoxBerry::Web::head();
	LoxBerry::Web::pagestart($template_title, $helplink, $helptemplate);
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

		$ms{"useclouddns.$msno"} = defined $ms{"useclouddns.$msno"} ? $ms{"useclouddns.$msno"} : "0";
  
		# URL-Encode form data before they are used to test the connection
		$ms{"miniserveruser.$msno"} = uri_escape($ms{"miniserveruser.$msno"});
		$ms{"miniserverkennwort.$msno"} = uri_escape($ms{"miniserverkennwort.$msno"});
		
		
# Removed as saving should not check MS anymote		
		
<<'COMMENTED_OUT';
		
		# Test if Miniserver is reachable
		if ( is_enabled($ms{"useclouddns.$msno"})) {
			# With Cloud DNS
			$ms{"useclouddns.$msno"} = "1";
			our $dns_info = `$bins->{'CURL'} -I http://$clouddnsaddress/$ms{"miniservercloudurl.$msno"} --connect-timeout 5 -m 5 2>/dev/null |$bins->{'GREP'} Location |$bins->{'AWK'} -F/ '{print \$3}'`;
			my @dns_info_pieces = split /:/, $dns_info;
			if ($dns_info_pieces[1]) {
				$dns_info_pieces[1] =~ s/^\s+|\s+$//g;
			} else {
				$dns_info_pieces[1] = 80;
			}
			if ($dns_info_pieces[0]) {
				$dns_info_pieces[0] =~ s/^\s+|\s+$//g;
			} else {
				$dns_info_pieces[0] = "[DNS-Error]"; 
			}
			$url = "http://$ms{\"miniserveruser.$msno\"}:$ms{\"miniserverkennwort.$msno\"}\@$dns_info_pieces[0]\:$dns_info_pieces[1]/dev/cfg/version";
		} else {
			# With local access
			$ms{"useclouddns.$msno"} = "0";
			$url = "http://$ms{\"miniserveruser.$msno\"}:$ms{\"miniserverkennwort.$msno\"}\@$ms{\"miniserverip.$msno\"}\:$ms{\"miniserverport.$msno\"}/dev/cfg/version";
		}
		$ua = LWP::UserAgent->new;
		$ua->timeout(5);
#		local $SIG{ALRM} = sub { die };
#		eval {
#			alarm(1);
			$response = $ua->get($url);
			$urlstatus = $response->status_line;
#		};
#		alarm(0);

		# Error if we can't login
		$urlstatuscode = substr($urlstatus,0,3);
		if ($urlstatuscode ne "200") {
			$error = $SL{'MINISERVER.SAVE_ERR_CANNOT_LOGIN'} . " <b>$msno. Miniserver</b>. " . $SL{'MINISERVER.SAVE_ERR_MS_UNREACHABLE'};
			$maintemplate->param ( "ERROR", $error );
			my $errordetails =  "<p>Request:<br>$url<p>" .
				"<p>Response: HTTP $urlstatus</p>" . 
				"<p>" . $response->content . "</p>";
			
			$maintemplate->param( "ERRORDETAILS", $errordetails );
			&error;
		}

COMMENTED_OUT
		
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
	LoxBerry::Web::lbheader($template_title, $helplink, $helptemplate);
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

