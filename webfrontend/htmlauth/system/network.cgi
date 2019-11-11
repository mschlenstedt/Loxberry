#!/usr/bin/perl

# Copyright 2017-2019 Michael Schlenstedt, michael@loxberry.de
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
use Data::Validate::IP qw(is_ipv4 is_ipv6);
use URI::Escape;
use warnings;
use strict;

# print STDERR "Execute network.cgi\n###################\n";

##########################################################################
# Variables
##########################################################################

# Version of this script
my $version = "2.0.0.1";

my $helplink = "https://www.loxwiki.eu/x/SogKAw";
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
my $netzwerkadressen_IPv6;
my $netzwerkipadresse_IPv6;
my $netzwerkipmaske_IPv6; 
my $netzwerkgateway_IPv6;
my $netzwerknameserver_IPv6;
my $netzwerkprivacyext_IPv6;
our @lines;
our $do;
our $message;
our $nexturl;
my @errors;
my $is_wireless;

##########################################################################
# Read Settings
##########################################################################


$cfg                = new Config::Simple("$lbsconfigdir/general.cfg");
$netzwerkanschluss  = $cfg->param("NETWORK.INTERFACE");
$netzwerkadressen   = $cfg->param("NETWORK.TYPE");
$netzwerkadressen_IPv6   = $cfg->param("NETWORK.TYPE_IPv6");

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
					
my @interfaces = get_interfaces();

#########################################################################
# Parameter
#########################################################################

# Get CGI
our  $cgi = CGI->new;

# Everything we got from forms
$do = $cgi->param('do');
$saveformdata = $cgi->param('saveformdata');

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

if ($saveformdata) 
{
	$netzwerkanschluss = $cgi->param('netzwerkanschluss');
	$netzwerkadressen = $cgi->param('netzwerkadressen');
	$netzwerkadressen_IPv6 = $cgi->param('netzwerkadressen_IPv6');
	
	# Check if $netzwerkanschluss is wireless
	
	foreach(@interfaces) {
		next if($_->{name} ne $netzwerkanschluss);
		$is_wireless = 1 if($_->{wireless});
		last;
	}
		
	# Check Wifi
	if ( $is_wireless ) {
		checkWifi();
	}
	
	# IPv4
	if ( $netzwerkadressen eq "manual" ) {
		checkIPv4( 
			ip => $cgi->param('netzwerkipadresse'),
			mask => $cgi->param('netzwerkipmaske'),
			gateway => $cgi->param('netzwerkgateway'),
			dns => $cgi->param('netzwerknameserver')
		);
	}
	
	# IPv6
	if ( $netzwerkadressen_IPv6 eq "manual" ) {
		checkIPv6(
			ip => $cgi->param('netzwerkipadresse_IPv6'),
			mask => $cgi->param('netzwerkipmaske_IPv6'),
			# gateway => $cgi->param('netzwerkgateway_IPv6'),
			dns => $cgi->param('netzwerknameserver_IPv6')
		);
	}
		
	if ($error)
	{
		&error;
	}

    # print STDERR "Calling subfunction SAVE\n";
    $maintemplate->param("SAVE", 1);
    &save;

} else {

  # print STDERR "Calling subfunction FORM\n";
  $maintemplate->param("FORM", 1);
  &form;

} 

exit;

#####################################################
# Form
#####################################################

sub form {

	my @interfaces_ordered;
	# Wired
	foreach(@interfaces) {
		push @interfaces_ordered, $_ if (!$_->{wireless} and !$_->{loopback});
	}
	# Wireless
	foreach(@interfaces) {
		push @interfaces_ordered, $_ if ($_->{wireless});
	}
	
	$maintemplate->param( "INTERFACES" => \@interfaces_ordered );
	
	$maintemplate->param( "netzwerkanschluss", $netzwerkanschluss );
	$maintemplate->param( "netzwerkadressen", $netzwerkadressen );
	$maintemplate->param( "netzwerkadressen_IPv6", $netzwerkadressen_IPv6 );

	if ( is_enabled( $cfg->param("NETWORK.PRIVACYEXT_IPv6") ) ) {
	  $maintemplate->param( "netzwerkprivacyext_IPv6", 'checked="checked"');
	}

	# israspberry Check
	$maintemplate->param( 'israspberry' , 1 ) if ( -e "$lbsconfigdir/is_raspberry.cfg" );

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
	# Adapter
	$netzwerkanschluss  = $cgi->param('netzwerkanschluss');
	$netzwerkssid       = $cgi->param('netzwerkssid');
	$netzwerkschluessel = $cgi->param('netzwerkschluessel');
	# IPv4
	$netzwerkadressen   = $cgi->param('netzwerkadressen');
	$netzwerkipadresse  = $cgi->param('netzwerkipadresse');
	$netzwerkipmaske    = $cgi->param('netzwerkipmaske');
	$netzwerkgateway    = $cgi->param('netzwerkgateway');
	$netzwerknameserver = $cgi->param('netzwerknameserver');
	# IPv6
	$netzwerkadressen_IPv6   = $cgi->param('netzwerkadressen_IPv6');
	$netzwerkipadresse_IPv6  = $cgi->param('netzwerkipadresse_IPv6');
	$netzwerkipmaske_IPv6    = $cgi->param('netzwerkipmaske_IPv6');
	$netzwerkgateway_IPv6    = $cgi->param('netzwerkgateway_IPv6');
	$netzwerknameserver_IPv6 = $cgi->param('netzwerknameserver_IPv6');
	$netzwerkprivacyext_IPv6 = is_enabled($cgi->param('netzwerkprivacyext_IPv6')) ? "ON" : "OFF";

	# Write configuration file(s)
	$cfg->param("NETWORK.INTERFACE", "$netzwerkanschluss");
	$cfg->param("NETWORK.SSID", uri_escape($netzwerkssid));
	$cfg->param("NETWORK.WPA", uri_escape($netzwerkschluessel));

	$cfg->param("NETWORK.TYPE", "$netzwerkadressen");
	$cfg->param("NETWORK.IPADDRESS", "$netzwerkipadresse");
	$cfg->param("NETWORK.MASK", "$netzwerkipmaske");
	$cfg->param("NETWORK.GATEWAY", "$netzwerkgateway");
	$cfg->param("NETWORK.DNS", "$netzwerknameserver");

	$cfg->param("NETWORK.TYPE_IPv6", "$netzwerkadressen_IPv6");
	$cfg->param("NETWORK.IPADDRESS_IPv6", "$netzwerkipadresse_IPv6");
	$cfg->param("NETWORK.MASK_IPv6", "$netzwerkipmaske_IPv6");
	$cfg->param("NETWORK.DNS_IPv6", "$netzwerknameserver_IPv6");
	$cfg->param("NETWORK.PRIVACYEXT_IPv6", $netzwerkprivacyext_IPv6);

	$cfg->save();

	# Set network options
	my $interface_file = "$lbhomedir/system/network/interfaces";
	my $ethtemplate_name = undef;
	my $ethtmpl;
	
	my $part_loopback;
	my $part_ipv4;
	my $part_ipv6;
		
	#### Loopback device ####
	$ethtemplate_name = "$lbstemplatedir/network/interfaces.loopback";
	$ethtmpl = HTML::Template->new(
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
	
	$ethtmpl->param('ipv6', 1) if (defined $netzwerkadressen_IPv6 and $netzwerkadressen_IPv6 ne "auto");
		
	$part_loopback = $ethtmpl->output();
	
	
	#### IPv4 ####
	$ethtemplate_name = "$lbstemplatedir/network/interfaces.ipv4";
	$ethtmpl = HTML::Template->new(
				filename => $ethtemplate_name,
				global_vars => 1,
				loop_context_vars => 1,
				die_on_bad_params=> 0,
				%htmltemplate_options,
				#associate => $cfg,
				# debug => 1,
	) or do 
		{ $error = "System failure: Cannot open network template $ethtemplate_name";
		&error; 
	};
	
	$ethtmpl->param('dhcp', 1) if ($netzwerkadressen eq "dhcp");
	$ethtmpl->param('static', 1) if ($netzwerkadressen eq "manual");
	$ethtmpl->param( 
					'wifi' => $is_wireless,
					'iface' => $netzwerkanschluss,
					'netzwerkssid' => $netzwerkssid,
					'netzwerkschluessel' => $netzwerkschluessel,
					'netzwerkipadresse' => $netzwerkipadresse,
					'netzwerkipmaske' => $netzwerkipmaske,
					'netzwerkgateway' => $netzwerkgateway,
					'netzwerknameserver' => $netzwerknameserver,
					'netzwerkdnsdomain' => 'loxberry.local',
		);
		
	$part_ipv4 = $ethtmpl->output();
	
	#### IPv6 ####
	if ( defined $netzwerkadressen_IPv6 and $netzwerkadressen_IPv6 ne "auto" ) {
		$ethtemplate_name = "$lbstemplatedir/network/interfaces.ipv6";
		$ethtmpl = HTML::Template->new(
				filename => $ethtemplate_name,
				global_vars => 1,
				loop_context_vars => 1,
				die_on_bad_params=> 0,
				%htmltemplate_options,
				#associate => $cfg,
				# debug => 1,
		) or do 
			{ $error = "System failure: Cannot open network template $ethtemplate_name";
			&error; 
		};
		
		$ethtmpl->param('dhcp', 1) if ($netzwerkadressen_IPv6 eq "dhcp");
		$ethtmpl->param('static', 1) if ($netzwerkadressen_IPv6 eq "manual");
		$ethtmpl->param( 
						'wifi', $is_wireless,
						'iface' => $netzwerkanschluss,
						'netzwerkssid' => $netzwerkssid,
						'netzwerkschluessel' => $netzwerkschluessel,
						'netzwerkipadresse_IPv6' => $netzwerkipadresse_IPv6,
						'netzwerkipmaske_IPv6' => $netzwerkipmaske_IPv6,
						'netzwerkgateway_IPv6' => $netzwerkgateway_IPv6,
						'netzwerknameserver_IPv6' => $netzwerknameserver_IPv6,
						'netzwerkdnsdomain' => 'loxberry.local',
						'netzwerkprivacyext_IPv6' => is_enabled($netzwerkprivacyext_IPv6) ? 2 : undef,
			);
			
		$part_ipv6 = $ethtmpl->output();
	
	}	
	
	## Backup old interfaces
	`cp $interface_file $interface_file.backup`;
	
	## Write new interfaces file
	
	open(my $fh, ">" , $interface_file) or do 
			{ $error = "System failure: Cannot open network file $interface_file";
			&error; };
	
	my $full_interfaces = $part_loopback . $part_ipv4 . $part_ipv6;
	$full_interfaces =~ s/\n+/\n/gs;
	
	print $fh $full_interfaces;
		
	close $fh;
	
	## Test interfaces file
	my $returncode = `ifup --no-act lo`;
	$returncode = $? >> 8;
	
	if ( $returncode != 0 ) {
		
		$error = "System failure: The new interfaces file seems to have an error and the original configuration was recovered. Check $interface_file.error file manually.";
		`cp $interface_file $interface_file.error`;
		`cp $interface_file.backup $interface_file`;
		&error;
	}
		
	# Make sure, dhcpcd is not running
	`sudo systemctl disable dhcpcd`;
	`sudo systemctl stop dhcpcd`;
	
	# Restart interfaces
	# `sudo systemctl restart networking` if (! $cgi->param('norestart'));
	
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
# Check IPv4
#####################################################
sub checkIPv4
{
	my %p = @_;
	
	# Check ip's
	if (!is_ipv4($p{ip})) { push @errors, "IPv4: $SL{'NETWORK.ERR_NOVALIDIP1'}"; }
	if (!is_ipv4($p{mask})) { push @errors, "IPv4: $SL{'NETWORK.ERR_NOVALIDNETMASK'}"; }
	if (!is_ipv4($p{gateway})) { push @errors, "IPv4: $SL{'NETWORK.ERR_NOVALIDGATEWAYIP1'}"; }
	if (!is_ipv4($p{dns})) { push @errors, "IPv4: $SL{'NETWORK.ERR_NOVALIDNAMESERVERIP1'}"; }
	
	# Check subnet
	my $network = NetAddr::IP->new($p{ip}, $p{mask})->network(); 
	if (!Data::Validate::IP::is_innet_ipv4($p{gateway}, $network)) {  push @errors, "IPv4: $SL{'NETWORK.ERR_NOVALIDGATEWAYIP2'}"; }
	
	$error .= join "<br>\n", @errors;
	
}

#####################################################
# Check IPv6
#####################################################
sub checkIPv6
{
	my %p = @_;
	
	print STDERR "checkIPv6: IP $p{ip} / MASK $p{mask} / GW $p{gateway} / DNS $p{dns}\n";
	
	# Check ip's
	if (!is_ipv6($p{ip})) { push @errors, "IPv6: $SL{'NETWORK.ERR_NOVALIDIP_IPv6'}"; }
	if (! defined $p{mask} or $p{mask} < 0 or $p{mask} > 128) { push @errors, "IPv6: $SL{'NETWORK.ERR_NOVALIDPREFIXLENGTH_IPv6'}"; }
	# if (!is_ipv6($p{gateway})) { push @errors, "$SL{'NETWORK.ERR_NOVALIDGATEWAYIP1_IPv6'}"; }
	if (!is_ipv6($p{dns})) { push @errors, "IPv6: $SL{'NETWORK.ERR_NOVALIDNAMESERVERIP1_IPv6'}"; }
	
	$error .= join "<br>\n", @errors;
	
}

#####################################################
# Check Wifi settings
#####################################################
sub checkWifi
{
	print STDERR "Validation for WLAN\n";
	$netzwerkssid = $cgi->param('netzwerkssid');
	$netzwerkschluessel = $cgi->param('netzwerkschluessel');
	if ( $netzwerkssid ne "" && length($netzwerkssid) <= 32 && length($netzwerkssid) >= 1 )
	{
		#print STDERR "SSID OK\n";
	}
	else
	{
		$error .= "$SL{'NETWORK.ERR_NOVALIDSSID'}<br>\n";
		print STDERR $error;
	}
	
	if ( $netzwerkschluessel ne "" && length($netzwerkschluessel) <= 63 && length($netzwerkschluessel) >= 8 )
	{
		#print STDERR "WPA KEY OK\n";
	}
	else
	{
		$error .= "$SL{'NETWORK.ERR_NOVALIDWPA'}<br>\n";
		print STDERR $error;
	} 

}

########################################################
# Parse network interfaces
#   This collects all interfaces, and determines
#   what interfaces are loopback, wired and wireless
#   Returns: Array with Hashref of interface properties
########################################################
sub get_interfaces
{
	my @interfacelist;
	
	## All interfaces
	my @iplink = `ip link show`;
	foreach my $linkline (@iplink) {
		if( substr($linkline, 0, 1) ne " " ) {
			# New interface line
			my %if;
			push @interfacelist, \%if;
			
			($if{id}, $if{name}, $if{fulloptions}) = split /:/, $linkline; 
			$if{id} = trim($if{id});
			$if{name} = trim($if{name});
			$if{fulloptions} = trim($if{fulloptions});

			# Collect information from line
			$if{loopback} = $if{fulloptions} =~ /<\S*(LOOPBACK)\s*\>*/ ? 1 : 0;
			$if{carrier} = $if{fulloptions} =~ /<\S*(NO-CARRIER)\s*\>*/ ? 0 : 1;
			$if{state} = $if{fulloptions} =~ /\sstate\s(\S*)/ ? $1 : undef;
		} else {
			# Second line
			my $if = $interfacelist[-1];
			$if->{loopback} = $linkline =~ /link\/loopback/ ? 1 : 0;
			$if->{mac} = $linkline =~ /link\/\S*\s(\S*)/ ? $1 : undef;
		}
	}
	
	# Find Wifi interfaces
	my @iwconfig = `iwconfig 2>&1`;
	foreach my $linkline (@iwconfig) {
		next if( index($linkline, "no wireless extensions") != -1 );
		# WIFI found
		my $wifiname = $1 if($linkline =~ /(^\S+)/);
		foreach my $if (@interfacelist) {
			# print STDERR "Search interface: $if->{name}\n";
			next if( $if->{name} ne $wifiname );
			$if->{wireless} = 1;
			last;
		}
	}

	# use Data::Dumper;
	# print STDERR Dumper(@interfacelist);

	return @interfacelist;

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
