#!/usr/bin/perl

# Copyright 2017 CF
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
use HTML::Template;
use warnings;
use strict;
no strict "refs"; # we need it for template system

print STDERR "LoxBerry::System\n";
print STDERR "lbhomedir: $lbhomedir\n";
print STDERR "lbslogdir: $lbslogdir\n";

##########################################################################
# Variables
##########################################################################

our  $cgi = CGI->new;
our $cgi->import_names('R');
my  %T;
my $topmenutemplate;
my $maintemplate;
my $footertemplate;
my $emsg;
my $oldname;
my $newname;
my $successfulchanged = 0;

##########################################################################
# Read Settings
##########################################################################

# Version of this script
my $version = LoxBerry::System::lbversion() . ".3";

# Start with HTML header
print $cgi->header(
         -type    =>      'text/html',
         -charset =>      'utf-8'
);

# Get language from GET, POST or System setting (from LoxBerry::Web)
my $lang = lblanguage();

##########################################################################
# Initialize html templates
##########################################################################

# See http://www.perlmonks.org/?node_id=65642

# Main
$maintemplate = HTML::Template->new(
	filename => "$lbstemplatedir/changehostname.html",
	global_vars => 1,
	loop_context_vars => 1,
	die_on_bad_params => 0,
);

$maintemplate->param( LBSLOGDIR => $lbslogdir);

my %Phrases = LoxBerry::System::readlanguage($maintemplate);

#########################################################################
# Parameter
#########################################################################

$oldname = `hostname`;
chomp $oldname;

##########################################################################
# Process form data
##########################################################################

if (defined $R::btnsubmit) {
	# Data were posted - save 
	print STDERR "POST\n";
	&save;
}

$maintemplate->param( STARTUP => 1 );

##########################################################################
# Main program
##########################################################################

$maintemplate->param( lbhostname => $oldname );

if (length($newname) gt 0) { $maintemplate->param( lbnewhostname => $newname ); }
					else {  $maintemplate->param( lbnewhostname => `hostname`); }
$maintemplate->param( errormessage => '<tr><td colspan="2"><font color="red">' . $emsg . '</font></td></tr>' );

print $maintemplate->output;

exit;

##########################################################################
# Save data
##########################################################################
sub save 
{

	$newname = $R::lbnewhostname;

	chomp $newname;

	print STDERR "hostname $oldname\n";
	print STDERR "newname $newname (len: " . length($newname) . ")\n";

	if ($newname eq $oldname) { $emsg = $Phrases{'NETWORK_CHANGEHOSTNAME.SUBMIT_ERROR_SIMILAR'}; }
	elsif (length($newname) < 1) { $emsg = $Phrases{'NETWORK_CHANGEHOSTNAME.SUBMIT_ERROR_EMPTY'}; }
	elsif (length($newname) > 63) { $emsg = $Phrases{'NETWORK_CHANGEHOSTNAME.SUBMIT_ERROR_HOSTNAME_TOO_LONG'}; }

	$_ = $newname;
	if (! /^[A-Za-z0-9-.]+$/ && !$emsg) { $emsg = $Phrases{'NETWORK_CHANGEHOSTNAME.SUBMIT_ERROR_INVALIDCHARS'}; }

	print STDERR "\$emsg: $emsg\n";

	if ($emsg ne "") 
		{ return(); }

	# Syntax ok - let's do it
	print STDERR "CHANGE CALLED\n";
	my @result = system("sudo $lbhomedir/sbin/changehostname.sh $newname > $lbslogdir/changehostname.log 2>&1");
	# print STDERR "system Errorcode: $?\n";
	my $changedname = `hostname`;
	chomp $changedname;
	my $successfullchanged;
	if ($newname eq $changedname) { $successfullchanged = 1; 
									print STDERR "New name is equal old name\n";}

	$maintemplate->param( CHANGED => 1 );
	$maintemplate->param( changedname => $changedname );
	$maintemplate->param( successfullchanged => $successfullchanged );
	print $maintemplate->output;

	exit;
}
