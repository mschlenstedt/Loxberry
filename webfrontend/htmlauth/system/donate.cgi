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
use LoxBerry::System;
use LoxBerry::Web;
use CGI::Carp qw(fatalsToBrowser);
use CGI qw/:standard/;
use Config::Simple;
use warnings;
use strict;

##########################################################################
# Variables
##########################################################################

my $helpurl = "https://wiki.loxberry.de/spenden/start";

our $lang;
our $phrase;
our $namef;
our $value;
our %query;
our $template_title;
our $help;
our @help;
our $helptext;
our $helplink;
our $languagefile;
our $bins = LoxBerry::System::get_binaries();

##########################################################################
# Read Settings
##########################################################################

# Version of this script
my $version = "3.0.0.0";

#########################################################################
# Parameter
#########################################################################

##########################################################################
# Language Settings
##########################################################################

$lang = lblanguage();

##########################################################################
# Main program
##########################################################################

my $maintemplate = HTML::Template->new(
		filename => "$lbstemplatedir/donate.html",
		global_vars => 1,
		loop_context_vars => 1,
		die_on_bad_params=> 0,
		%htmltemplate_options,
		# debug => 1,
		);
	
my %SL = LoxBerry::System::readlanguage($maintemplate);

# Read Donors and create Template Loop
my $file = "$lbsdatadir/donors.dat";
my $url = "https://raw.githubusercontent.com/mschlenstedt/Loxberry/master/data/system/donors.dat";
my @lines;
my @donorlist;
my $counter = 0;

# Download newest donors list if older than 3 days
my $mtime = ( stat($file) )[9];
my $now = time();
if ($now > $mtime+259200 || !-e $file) {
	my $resp = `$bins->{CURL} -q --connect-timeout 2 --max-time 5 --retry 2 -LfksSo $file $url 2>&1`;
}

# Read list in reverse order
open (FH, '<', $file);
@lines = reverse <FH>;
close(FH);

foreach (@lines) {
	my %donor;
	my ($date,$name,$comment) = split(/;/,$_);
	$counter++;
	$donor{NAME} = $name;
	$donor{DATE} = $date;
	$donor{COMMENT} = $comment;
	push(@donorlist, \%donor);
}
$maintemplate->param(DONORLIST => \@donorlist);
$maintemplate->param(COUNTER => $counter);

# Print Template
$template_title = $SL{'COMMON.LOXBERRY_MAIN_TITLE'} . ": " . $SL{'DONATE.WIDGETLABEL'};
LoxBerry::Web::lbheader($template_title, $helpurl);
print $maintemplate->output();
undef $maintemplate;			
LoxBerry::Web::pageend();
LoxBerry::Web::foot();

exit;
