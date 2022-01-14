#!/usr/bin/perl

# Copyright 2018-2020 Michael Schlenstedt, michael@loxberry.de
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
use LoxBerry::Storage;
use LoxBerry::Web;
use LoxBerry::Log;
use LoxBerry::JSON;
use Data::Dumper;
use warnings;
use strict;

##########################################################################
# Variables
##########################################################################

# Version of this script
my $version = "3.0.0.0";

##########################################################################
# Language Settings
##########################################################################

my $lang = lblanguage();

##########################################################################
# Main program
##########################################################################

# Get CGI
my  $cgi = CGI->new;

my $maintemplate = HTML::Template->new(
		filename => "$lbstemplatedir/format_device.html",
		global_vars => 1,
		loop_context_vars => 1,
		die_on_bad_params=> 0,
		# associate => $cfg,
		%htmltemplate_options,
		# debug => 1,
		);
	
my %SL = LoxBerry::System::readlanguage($maintemplate);

# Print Template
my $template_title = $SL{'COMMON.LOXBERRY_MAIN_TITLE'} . ": " . $SL{'USBSTORAGE.WIDGETLABEL'};

LoxBerry::Web::lbheader($template_title, 'nopanels', undef);

my $param_a=$cgi->param("a");
my $param_d=$cgi->param("d");

my @values;
my %labels;
my ($rc, $output) = execute( command => "lsblk -O -J" );
my $lsblk = decode_json( $output );
if ( $rc eq "0" ) {

	foreach my $blockdevice ( sort { $a->{name} cmp $b->{name} } @{$lsblk->{blockdevices}} ) {
		next if ($blockdevice->{kname} =~ /.*ram.*/); # skip ramdiscs
		$blockdevice->{model} = "Unknown" if !$blockdevice->{model};
		push (@values, $blockdevice->{path});
		$labels{$blockdevice->{path}} = "$SL{'USBSTORAGE.LABEL_DRIVE'} $blockdevice->{name}: $blockdevice->{model}, $SL{'USBSTORAGE.LABEL_SERIAL'}: $blockdevice->{serial}, $SL{'USBSTORAGE.LABEL_TYPE'}: $blockdevice->{type}, $SL{'USBSTORAGE.LABEL_SIZE'}: $blockdevice->{size}";
	   	foreach my $partition ( sort @{$blockdevice->{children}} ) {
			if ($partition->{mountpoint} eq "/" || $partition->{mountpoint} eq "/boot") { # Skip Root and Boot devices
				$labels{$blockdevice->{path}} = undef;
				my $i = 0;
				$i++ until $values[$i] eq "$blockdevice->{path}";
				splice(@values, $i, 1);
				last;
			}
			push (@values, $partition->{path});
			$labels{$partition->{path}} = "----> $SL{'USBSTORAGE.LABEL_PARTITION'} $partition->{name}: $partition->{label}, $SL{'USBSTORAGE.LABEL_TYPE'}: $partition->{fstype}, $SL{'USBSTORAGE.LABEL_SIZE'}: $partition->{fssize}, $SL{'USBSTORAGE.LABEL_USED'}: $partition->{'fsuse%'}";
		}
        }

}

if ( scalar (@values) eq 0 ) {
		push (@values, "none");
		$labels{'none'} = $SL{'USBSTORAGE.LABEL_NODEVICES'};
}

# Dropdown
my $dropdown = $cgi->popup_menu(
      -name    => 'devices',
      -id      => 'devices',
      -values  => \@values,
      -labels  => \%labels,
      -default => $param_d
  );
$maintemplate->param( DROPDOWN => $dropdown );

# Output Template
print $maintemplate->output();
exit;
