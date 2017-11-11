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
# use Config::Simple;
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

#our $cfg;
#our $phrase;
#our $namef;
#our $value;
#our %query;
#our $lang;
#our $template_title;
#our $installdir;
#our $languagefile;
#my  @fields;
#my  $error;
#our $table;
#my  @result;
#my  $i;
#our $ssid;
#our $version;
#our $ENV;

##########################################################################
# Read Settings
##########################################################################

# Version of this script
my $version = LoxBerry::System::pluginversion() . ".2";

# Start with HTML header
print $cgi->header(
         -type    =>      'text/html',
         -charset =>      'utf-8'
);

# Get language from GET, POST or System setting (from LoxBerry::Web)
my $lang = lblanguage();

#$cfg             = new Config::Simple('../../../../config/system/general.cfg');
#$installdir      = $cfg->param("BASE.INSTALLFOLDER");
#$lang            = $cfg->param("BASE.LANG");

##########################################################################
# Initialize html templates
##########################################################################

# See http://www.perlmonks.org/?node_id=65642

# Main
$maintemplate = HTML::Template->new(
	filename => "$lbstemplatedir/multi/changehostname.html",
	global_vars => 1,
	loop_context_vars => 1,
	die_on_bad_params => 0,
	# associate => %pcfg,
);

$maintemplate->param( LBSLOGDIR => $lbslogdir);

&translations;

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

# In LoxBerry V0.2.x we use the old LoxBerry::Web header

# LoxBerry::Web::lbheader("$T{TXT0000} - $T{TXT0009}"));

$maintemplate->param( lbhostname => $oldname );

if (length($newname) > 0) { $maintemplate->param( lbnewhostname => $newname ); }
					else {  $maintemplate->param( lbnewhostname => `hostname`); }
$maintemplate->param( errormessage => '<tr><td colspan="2"><font color="red">' . $emsg . '</font></td></tr>' );

print $maintemplate->output;

# $template_title = $phrase->param("TXT0000") . " - " . $phrase->param("TXT0009");

# Print Template
#open(F,"$installdir/templates/system/$lang/lshwnetwork.html") || die "Missing template system/$lang/lshwnetwork.html";
#  while (<F>) {
#    $_ =~ s/<!--\$(.*?)-->/${$1}/g;
#    print $_;
#  }
#close(F);

exit;

##########################################################################
# Save data
##########################################################################
sub save 
{

$newname = $R::lbnewhostname;

chomp $newname;

print STDERR "hostname $oldname\n";
print STDERR "newname $newname\n";

if ($newname eq $oldname) { $emsg = "Du hast keinen neuen Namen eingegeben. Es ist nichts passiert."; }
if (length($newname) < 1) { $emsg = "Du musst im Feld etwas eingeben."; }
if (length($newname) > 63) { $emsg = "Dein Hostname ist zu lang. Er darf maximal 63 Zeichen haben."; }

$_ = $newname;
if (! /^[A-Za-z0-9-.]+$/ ) { $emsg = "In einem Host- oder Domänennamen dürfen nur vorkommen: A-Z, 0-9, -, und ggf. Domänenpunkte."; }

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

# Finished-Template
$maintemplate = HTML::Template->new(
	filename => "$lbstemplatedir/multi/changehostname.html",
	global_vars => 1,
	loop_context_vars => 1,
	die_on_bad_params => 0,
	# associate => %pcfg,
);

$maintemplate->param( CHANGED => 1 );
$maintemplate->param( changedname => $changedname );
$maintemplate->param( successfullchanged => $successfullchanged );
print $maintemplate->output;

exit;

}




##########################################################################
# Translations
##########################################################################

sub translations 
{
	my $languagefileplugin;
	# Read transations
	# Read English language as default
	$languagefileplugin 	= "$lbstemplatedir/en/language.dat";
	Config::Simple->import_from($languagefileplugin, \%T);

	# Read foreign language if exists and not English
	$languagefileplugin = "$lbstemplatedir/$lang/language.dat";
	# Now overwrite phrase variables with user language
	if ((-e $languagefileplugin) and ($lang ne 'en')) {
		Config::Simple->import_from($languagefileplugin, \%T);
	}

	# Parse phrase variables to html templates
	while (my ($name, $value) = each %T){
		$maintemplate->param("T::$name" => $value);
	}
}
