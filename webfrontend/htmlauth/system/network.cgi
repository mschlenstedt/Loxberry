#!/usr/bin/perl

# Copyright 2017 Michael Schlenstedt, michael@loxberry.de
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
use LoxBerry::Web;

use URI::Escape;
use CGI qw/:standard/;
use LWP::UserAgent;
use Socket qw( inet_aton );
use warnings;
use strict;
# no strict "refs"; # we need it for template system

##########################################################################
# Variables
##########################################################################

my $helplink = "http://www.loxwiki.eu/display/LOXBERRY/LoxBerry";
my $helptemplate = "help_network.html";

our $cfg;
our $phrase;
our $namef;
our $value;
our %query;
our $lang;
our $template_title;
our $help;
our @help;
our $helptext;
our $languagefile;
our $error;
our $saveformdata;
our $checked1;
our $checked2;
our $checked3;
our $checked4;
our $netzwerkanschluss;
our $netzwerkssid;
our $netzwerkschluessel;
our $netzwerkadressen;
our $netzwerkipadresse;
our $netzwerkipmaske;
our $netzwerkgateway;
our $netzwerknameserver;
our @lines;
our $do;
our $message;
our $nexturl;
# our $lbhostname = lbhostname();

##########################################################################
# Read Settings
##########################################################################

# Version of this script
my $version = "0.3.5.1";

print STDERR "============= network.cgi ================\n";
print STDERR "lbhomedir: $lbhomedir\n";

$cfg                = new Config::Simple("$lbsconfigdir/general.cfg");
$netzwerkanschluss  = $cfg->param("NETWORK.INTERFACE");
$netzwerkadressen   = $cfg->param("NETWORK.TYPE");

my $maintemplate = HTML::Template->new(
			filename => "$lbstemplatedir/network.html",
			global_vars => 1,
			loop_context_vars => 1,
			die_on_bad_params=> 0,
			associate => $cfg,
			%htmltemplate_options,
			);

my %SL = LoxBerry::System::readlanguage($maintemplate);

# SSID and WPA-Key are URI-Encoded in general.cfg, therefore send it unencoded
# to the template
$maintemplate->param ( 
	'NETWORK.SSID' => uri_unescape($cfg->param('NETWORK.SSID')),
	'NETWORK.WPA' => uri_unescape($cfg->param('NETWORK.WPA')),
);
					


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

# Everything we got from forms
$saveformdata         = param('saveformdata');
defined $saveformdata ? $saveformdata =~ tr/0-1//cd : undef;

##########################################################################
# Language Settings
##########################################################################

$lang = lblanguage();
$maintemplate->param( "LBHOSTNAME", lbhostname());
$maintemplate->param( "LANG", $lang);
$maintemplate->param ( "SELFURL", $ENV{REQUEST_URI});

##########################################################################
# Main program
##########################################################################

#########################################################################
# What should we do
#########################################################################

# Step 1 or beginning

# $ipno = Regex pattern to validate IP Addresses
my $ipno = qr/
    2(?:5[0-5] | [0-4]\d)
    |
    1\d\d
    |
    [1-9]?\d
/x;

if ($saveformdata) 
{
	$netzwerkanschluss  = param('netzwerkanschluss');
	if ( $netzwerkanschluss eq "eth0" )
	{
		print STDERR "Validation for LAN on eth0\n";
		$netzwerkadressen = param('netzwerkadressen');
		if ( $netzwerkadressen eq "dhcp" )
		{
			print STDERR "DHCP => No validation\n";
		}
		else
		{
			print STDERR "Server side validation for static IP to prevent corrupted datas in the configuration filesDHCP => No validation\n";
			$netzwerkipadresse  = param('netzwerkipadresse');
			$netzwerkipmaske    = param('netzwerkipmaske');
			$netzwerkgateway    = param('netzwerkgateway');
			$netzwerknameserver = param('netzwerknameserver');
			
			if ( $netzwerkipadresse =~ /^($ipno\.){3}$ipno$/ && $saveformdata != "")
			{
				#print STDERR "IP-Address $netzwerkipadresse matches the IP Address pattern!\n";
				if (  $netzwerkipmaske =~ /^(((128|192|224|240|248|252|254)\.0\.0\.0)|(255\.(0|128|192|224|240|248|252|254)\.0\.0)|(255\.255\.(0|128|192|224|240|248|252|254)\.0)|(255\.255\.255\.(0|128|192|224|240|248|252|254)))$/i )
				{
				  #print STDERR "NetMask $netzwerkipmaske matches the NetMask pattern!\n";
					if (  $netzwerkgateway =~ /^($ipno\.){3}$ipno$/ )
					{
					  #print STDERR "Gateway $netzwerkgateway matches the Gateway pattern!\n";
						if ( $netzwerknameserver =~ /^($ipno\.){3}$ipno$/ )
						{
							#print STDERR "Nameserver $netzwerknameserver matches the Nameserver pattern!\n";
						  my $subnetaddress = join '.', unpack 'C4', pack 'N', oct("0b" . (ip2bin($netzwerkipadresse, '') & ip2bin($netzwerkipmaske, '')));
						  #print STDERR "Calculated subnet is: ", $subnetaddress, "\n";
						  my $subnet = "$subnetaddress/$netzwerkipmaske";
							if( in_subnet( $netzwerkipadresse, $subnet ) )
							{
								#print STDERR "IP-Address $netzwerkipadresse is in the subnet $subnet\n";
							}
							else
							{
								$error = " $SL{'NETWORK.ERR_NOVALIDIP2'} $netzwerkipadresse $SL{'NETWORK.ERR_DOESNT_MATCH'} $subnet";
								#print STDERR $error;
							#	&error;
							}
							if( in_subnet( $netzwerkgateway, $subnet ) )
							{
								#print STDERR "Gateway $netzwerkgateway is in the subnet $subnet\n";
							}
							else
							{
								$error = " $SL{'NETWORK.ERR_NOVALIDGATEWAYIP2'} $netzwerkgateway $SL{'NETWORK.ERR_DOESNT_MATCH'} $subnet";
								#print STDERR $error;
						#		&error;
							}
						}
						else
						{
							$error = "$SL{'NETWORK.ERR_NOVALIDNAMESERVERIP1'}";
							#print STDERR $error;
					#		&error;
						}
					}
					else
					{
						$error = "$SL{'NETWORK.ERR_NOVALIDGATEWAYIP1'}";
						#print STDERR $error;
				#		&error;
					}
				}
				else
				{
					$error = "$SL{'NETWORK.ERR_NOVALIDNETMASK'}";
					#print STDERR $error;
			#		&error;
				}
			}
			else
			{
					$error = "$SL{'NETWORK.ERR_NOVALIDIP1'}";
					#print STDERR $error;
			}
		}
	}
	else
	{
		print STDERR "Validation for WLAN\n";
		$netzwerkssid       = param('netzwerkssid');
		$netzwerkschluessel = param('netzwerkschluessel');
		if ( $netzwerkssid ne "" && length($netzwerkssid) <= 32 && length($netzwerkssid) >= 1 )
		{
			#print STDERR "SSID OK\n";
		}
		else
		{
			$error = "$SL{'NETWORK.ERR_NOVALIDSSID'}";
			print STDERR $error;
		}
		if ( $netzwerkschluessel ne "" && length($netzwerkschluessel) <= 63 && length($netzwerkschluessel) >= 8 )
		{
			#print STDERR "WPA KEY OK\n";
		}
		else
		{
			$error = "$SL{'NETWORK.ERR_NOVALIDWPA'}";
			print STDERR $error;
		} 
	}
	if ($error)
	{
		&error;
	}
}


if (!$saveformdata) {
  print STDERR "FORM called\n";
  $maintemplate->param("FORM", 1);
  &form;
} else {
  print STDERR "SAVE called\n";
  $maintemplate->param("SAVE", 1);
  &save;
}

exit;

#####################################################
# Form
#####################################################

sub form {

	# Defaults for template
	if ($netzwerkanschluss eq "eth0") {
	  $maintemplate->param( "CHECKED1", 'checked="checked"');
	} else {
	  $maintemplate->param( "CHECKED2", 'checked="checked"');
	}

	if ($netzwerkadressen eq "manual") {
	  $maintemplate->param( "CHECKED4", 'checked="checked"');
	} else {
	  $maintemplate->param( "CHECKED3", 'checked="checked"');
	}

	# Print Template
	$template_title = $SL{'COMMON.LOXBERRY_MAIN_TITLE'} . ": " . $SL{'NETWORK.WIDGETLABEL'};
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

	# Everything from Forms
	$netzwerkanschluss  = param('netzwerkanschluss');
	$netzwerkssid       = param('netzwerkssid');
	$netzwerkschluessel = param('netzwerkschluessel');
	$netzwerkadressen   = param('netzwerkadressen');
	$netzwerkipadresse  = param('netzwerkipadresse');
	$netzwerkipmaske    = param('netzwerkipmaske');
	$netzwerkgateway    = param('netzwerkgateway');
	$netzwerknameserver = param('netzwerknameserver');

	# Write configuration file(s)
	$cfg->param("NETWORK.INTERFACE", "$netzwerkanschluss");
	$cfg->param("NETWORK.SSID", uri_escape($netzwerkssid));
	$cfg->param("NETWORK.WPA", uri_escape($netzwerkschluessel));
	$cfg->param("NETWORK.TYPE", "$netzwerkadressen");
	$cfg->param("NETWORK.IPADDRESS", "$netzwerkipadresse");
	$cfg->param("NETWORK.MASK", "$netzwerkipmaske");
	$cfg->param("NETWORK.GATEWAY", "$netzwerkgateway");
	$cfg->param("NETWORK.DNS", "$netzwerknameserver");

	$cfg->save();

	# Set network options
	my $interface_file = "$lbhomedir/system/network/interfaces";
	my $ethtemplate_name = undef;

	# Wireless
	if ($netzwerkanschluss eq "wlan0") {
		if ($netzwerkadressen eq "manual") {
			# Manual / Static
			$ethtemplate_name = "$lbhomedir/system/network/interfaces.wlan_static";
		} else {
			# DHCP
			$ethtemplate_name = "$lbhomedir/system/network/interfaces.wlan_dhcp";
		}
	# Ethernet
	} else {
		if ($netzwerkadressen eq "manual") {
			# Manual / Static
			$ethtemplate_name = "$lbhomedir/system/network/interfaces.eth_static";
		} else {
			# DHCP	
			$ethtemplate_name = "$lbhomedir/system/network/interfaces.eth_dhcp";
		}
	}

	my $ethtmpl = HTML::Template->new(
				filename => $ethtemplate_name,
				global_vars => 1,
				loop_context_vars => 1,
				die_on_bad_params=> 0,
				%htmltemplate_options,
				#associate => $cfg,
				# debug => 1,
			) or do 
			{ $error = "System failure: Cannot open network template $ethtemplate_name";
			&error; };
			
	$ethtmpl->param( 
					'netzwerkssid' => $netzwerkssid,
					'netzwerkschluessel' => $netzwerkschluessel,
					'netzwerkipadresse' => $netzwerkipadresse,
					'netzwerkipmaske' => $netzwerkipmaske,
					'netzwerkgateway' => $netzwerkgateway,
					'netzwerknameserver' => $netzwerknameserver,
					'netzwerkdnsdomain' => 'loxberry.local',
				);
	open(my $fh, ">" , $interface_file) or do 
			{ $error = "System failure: Cannot open network file $interface_file";
			&error; };
	$ethtmpl->output(print_to => $fh);
	close $fh;
	$ethtmpl = undef;
	reboot_required($SL{'NETWORK.CHANGE_REBOOT_REQUIRED_MSG'});
	
	$template_title = $SL{'COMMON.LOXBERRY_MAIN_TITLE'} . ": " . $SL{'NETWORK.WIDGETLABEL'};
	$maintemplate->param("NEXTURL", "/admin/system/index.cgi?form=system");

	# Print Template
	LoxBerry::Web::head();
	LoxBerry::Web::pagestart($template_title, $helplink, $helptemplate);
	print $maintemplate->output();
	LoxBerry::Web::pageend();
	LoxBerry::Web::foot();
	exit;
}

exit;


#####################################################
# 
# Subroutines
#
#####################################################

#####################################################
# IP and subnet checking subs 
#####################################################

sub ip2bin
{
	# Convert IP address like 192.168.178.50 to binary like 11000000 10101000 10110010 00110010
  my ($ip, $delimiter) = @_;
  return join($delimiter,  map 
        substr(unpack("B32",pack("N",$_)),-8), 
        split(/\./,$ip));
}

sub ip2long
{
	return( unpack( 'N', inet_aton($_) ) );
}

sub in_subnet
{
	my ($ip, $subnet) = @_;
	
	print STDERR "Validating $ip with $subnet\n";
	
	my $ip_long = ip2long( $ip );

	if( $subnet=~m|(^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})/(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})$| )
	{
		my $subnet = ip2long( $1 );
		my $mask = ip2long( $2 );

		if( ($ip_long & $mask)==$subnet )
		{
			return( 1 );
		}
	}
	elsif( $subnet=~m|(^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})/(\d{1,2})$| )
	{
		my $subnet = ip2long( $1 );
		my $bits = $2;
		my $mask = -1<<(32-$bits);

		$subnet&= $mask;

		if( ($ip_long & $mask)==$subnet )
		{
			return( 1 );
		}
	}
	elsif( $subnet=~m|(^\d{1,3}\.\d{1,3}\.\d{1,3}\.)(\d{1,3})-(\d{1,3})$| )
	{
		my $start_ip = ip2long( $1.$2 );
		my $end_ip = ip2long( $1.$3 );

		if( $start_ip<=$ip_long and $end_ip>=$ip_long )
		{
			return( 1 );
		}
	}
	elsif( $subnet=~m|^[\d\*]{1,3}\.[\d\*]{1,3}\.[\d\*]{1,3}\.[\d\*]{1,3}$| )
	{
		my $search_string = $subnet;

		$search_string=~s/\./\\\./g;
		$search_string=~s/\*/\.\*/g;

		if( $ip=~/^$search_string$/ )
		{
			return( 1 );
		}
	}

	return( 0 );
}

#####################################################
# Error
#####################################################

sub error {

	$template_title = $SL{'COMMON.LOXBERRY_MAIN_TITLE'} . ": " . $SL{'NETWORK.WIDGETLABEL'};

	my $maintemplate = HTML::Template->new(
				filename => "$lbstemplatedir/error.html",
				global_vars => 1,
				loop_context_vars => 1,
				die_on_bad_params=> 0,
				%htmltemplate_options,
				# associate => $cfg,
				);
	$maintemplate->param('ERROR' => $error);
	
	LoxBerry::System::readlanguage($maintemplate);
	LoxBerry::Web::head();
	LoxBerry::Web::pagestart();
	print $maintemplate->output();
	LoxBerry::Web::pageend();
	LoxBerry::Web::foot();
	exit;

}
