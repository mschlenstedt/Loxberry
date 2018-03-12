#!/usr/bin/perl

# Copyright 2018 Michael Schlenstedt, michael@loxberry.de
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

use Config::Simple;
use warnings;
use strict;

##########################################################################
# Variables
##########################################################################

my $helpurl = "http://www.loxwiki.eu/display/LOXBERRY/LoxBerry";

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
our $helplink;
our $installfolder;
our $languagefile;

##########################################################################
# Read Settings
##########################################################################

# Version of this script
my $version = "1.0.0.0";

$cfg = new Config::Simple("$lbhomedir/config/system/general.cfg");

##########################################################################
# Language Settings
##########################################################################

$lang = lblanguage();

##########################################################################
# Netshare Config
##########################################################################

if ( !-e "$lbhomedir/data/system/netshares.dat" ) {
        open(F,">$lbhomedir/data/system/netshares.dat");
        print F <<EOF;
#
# Database for Net Shares
#
#  0: Server
#  1: Type
#  2: Name
#  3: User
#  4: Password
#
# Delimiter: | (Pipe)
#
EOF
        close (F);
	qx ("chmod 600 $lbhomedir/data/system/netshares.dat);
}

##########################################################################
# Main program
##########################################################################

# Get CGI
our  $cgi = CGI->new;

# Get all Network shares
my @netshares = LoxBerry::Storage::get_netshares(0, 1);

my $maintemplate = HTML::Template->new(
		filename => "$lbstemplatedir/netshares.html",
		global_vars => 1,
		loop_context_vars => 1,
		die_on_bad_params=> 0,
		associate => $cfg,
		%htmltemplate_options,
		# debug => 1,
		);
	
my %SL = LoxBerry::System::readlanguage($maintemplate);

# Print Template
$template_title = $SL{'COMMON.LOXBERRY_MAIN_TITLE'} . ": " . $SL{'NETSHARES.WIDGETLABEL'};

LoxBerry::Web::lbheader();

# Add new server?
if ($cgi->param("a") eq "add") {
	$maintemplate->param("ADD", 1);
} else {
	$maintemplate->param("FORM", 1);
	$maintemplate->param("NETSHARES", \@netshares);
}

# Save new server
if ($cgi->param("saveformdata")) {
	$maintemplate->param("FORM", 1);

	# Credits
	my $file=$cgi->param("serverip");
	my $username=$cgi->param("username");
	my $password=$cgi->param("password");
	my $type=$cgi->param("type");
	my $shortname=$cgi->param("servername");
        open(F,">$lbhomedir/system/samba/credentials/$file");
        print F <<EOF;
uid=1001
gid=1001
username="$username"
password="$password"
EOF
        close (F);

	qx(ln -f -s /media/$type/$file $lbhomedir/system/storage/$type/$file);
	qx(ln -f -s /media/$type/$file $lbhomedir/system/storage/$type/$shortname);
}

print $maintemplate->output();
undef $maintemplate;			

LoxBerry::Web::lbfooter();

exit;
