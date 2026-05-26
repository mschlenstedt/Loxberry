#!/usr/bin/perl

# Copyright 2017-2020 Michael Schlenstedt, michael@loxberry.de
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
use LoxBerry::System::General;
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
my $version = "2.0.2.2";

my $helplink = "https://wiki.loxberry.de/konfiguration/widget_help/widget_network";
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
my %netcfg;

##########################################################################
# Read Settings
##########################################################################


my $jsonobj = LoxBerry::System::General->new();
my $cfg = $jsonobj->open();

# Migrate: remove deprecated Network section from general.json
if (exists $cfg->{Network}) {
	delete $cfg->{Network};
	$jsonobj->write();
}

# Read current network settings from /etc/network/interfaces
%netcfg = parse_interfaces_file();

$netzwerkanschluss     = $netcfg{interface}       // 'eth0';
$netzwerkadressen      = $netcfg{ipv4}{type}       // 'dhcp';
$netzwerkadressen_IPv6 = $netcfg{ipv6}{type}       // 'auto';

my $maintemplate = HTML::Template->new(
			filename => "$lbstemplatedir/network.html",
			global_vars => 1,
			loop_context_vars => 1,
			die_on_bad_params=> 0,
			associate => $jsonobj,
			%htmltemplate_options,
			);

my %SL = LoxBerry::System::readlanguage($maintemplate);

# Set network values read from /etc/network/interfaces
$maintemplate->param(
	'NETWORK.SSID'           => $netcfg{ssid}            // '',
	'NETWORK.WPA'            => $netcfg{wpa}             // '',
	'NETWORK.IPV4.IPADDRESS' => $netcfg{ipv4}{ipaddress} // '',
	'NETWORK.IPV4.MASK'      => $netcfg{ipv4}{mask}      // '',
	'NETWORK.IPV4.GATEWAY'   => $netcfg{ipv4}{gateway}   // '',
	'NETWORK.IPV4.DNS'       => $netcfg{ipv4}{dns}       // '',
	'NETWORK.IPV6.IPADDRESS' => $netcfg{ipv6}{ipaddress} // '',
	'NETWORK.IPV6.MASK'      => $netcfg{ipv6}{mask}      // '',
	'NETWORK.IPV6.DNS'       => $netcfg{ipv6}{dns}       // '',
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

	if ( is_enabled( $netcfg{ipv6}{privacyext} ) ) {
	  $maintemplate->param( "netzwerkprivacyext_IPv6", 'checked="checked"');
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

	# Build network interfaces file content using LoxBerry templates

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

	my $full_interfaces = $part_loopback . $part_ipv4 . ($part_ipv6 // '');
	$full_interfaces =~ s/\n+/\n/gs;

	## Test new interfaces content via a temporary file before writing
	my $tmp_file = '/tmp/lb_network_interfaces_test';
	open(my $fh, '>', $tmp_file) or do
			{ $error = "System failure: Cannot write temporary interfaces file";
			&error; };
	print $fh $full_interfaces;
	close $fh;

	my $returncode = system("ifup --no-act -i $tmp_file lo 2>/dev/null");
	$returncode = $returncode >> 8;
	unlink($tmp_file);

	if ( $returncode != 0 ) {
		$error = "System failure: The new interfaces configuration seems to have an error. Please check the settings.";
		&error;
	}

	## Write to /etc/network/interfaces via privileged sbin script.
	## The script handles symlink migration and sets root:root 644 permissions.
	open(my $pipe, '|-', 'sudo', '/opt/loxberry/sbin/network-interfaces-write.pl') or do
			{ $error = "System failure: Cannot execute network-interfaces-write.pl";
			&error; };
	print $pipe $full_interfaces;
	close($pipe);

	if ($? >> 8 != 0) {
		$error = "System failure: Cannot write /etc/network/interfaces";
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
# Parse /etc/network/interfaces
#   Reads current network configuration directly from
#   the interfaces file (follows symlinks if present).
#   Returns a hash with keys:
#     interface, ssid, wpa,
#     ipv4 => { type, ipaddress, mask, gateway, dns },
#     ipv6 => { type, ipaddress, mask, dns, privacyext }
#####################################################
sub parse_interfaces_file {
	my $file = '/etc/network/interfaces';
	my %net = (
		interface => undef,
		ssid      => '',
		wpa       => '',
		ipv4      => { type => 'dhcp', ipaddress => '', mask => '', gateway => '', dns => '' },
		ipv6      => { type => 'auto', ipaddress => '', mask => '', dns => '', privacyext => '' },
	);

	open(my $fh, '<', $file) or return %net;

	my $current_iface = undef;
	my $current_proto = undef;

	while (my $line = <$fh>) {
		chomp $line;
		$line =~ s/^\s+//;
		next if $line =~ /^#/ || $line eq '';

		# auto / allow-hotplug line: identifies the primary non-loopback interface
		if ($line =~ /^(?:auto|allow-hotplug)\s+(\S+)$/) {
			my $iface = $1;
			next if $iface eq 'lo';
			$net{interface} //= $iface;
			next;
		}

		# iface declaration line
		if ($line =~ /^iface\s+(\S+)\s+(inet6?)\s+(\S+)$/) {
			my ($iface, $proto, $type) = ($1, $2, $3);
			next if $iface eq 'lo';
			$current_iface = $iface;
			$current_proto = $proto;
			$net{interface} //= $iface;
			if ($proto eq 'inet') {
				# interfaces file uses 'static'; CGI uses 'manual'
				$net{ipv4}{type} = ($type eq 'static') ? 'manual' : $type;
			} else {
				$net{ipv6}{type} = $type;
			}
			next;
		}

		next unless defined $current_iface;

		# Interface option lines
		if ($line =~ /^address\s+(\S+)$/) {
			if    ($current_proto eq 'inet')  { $net{ipv4}{ipaddress} = $1; }
			elsif ($current_proto eq 'inet6') { $net{ipv6}{ipaddress} = $1; }
		}
		elsif ($line =~ /^netmask\s+(\S+)$/) {
			if    ($current_proto eq 'inet')  { $net{ipv4}{mask} = $1; }
			elsif ($current_proto eq 'inet6') { $net{ipv6}{mask} = $1; }
		}
		elsif ($line =~ /^gateway\s+(\S+)$/) {
			$net{ipv4}{gateway} = $1 if $current_proto eq 'inet';
		}
		elsif ($line =~ /^dns-nameservers\s+(\S+)/) {
			if    ($current_proto eq 'inet')  { $net{ipv4}{dns} = $1; }
			elsif ($current_proto eq 'inet6') { $net{ipv6}{dns} = $1; }
		}
		elsif ($line =~ /^wpa-ssid\s+(.+)$/) {
			$net{ssid} = $1;
		}
		elsif ($line =~ /^wpa-psk\s+(.+)$/) {
			$net{wpa} = $1;
		}
	}
	close($fh);
	return %net;
}

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
