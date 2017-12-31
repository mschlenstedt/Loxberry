#!/usr/bin/perl

# Copyright 2017 CF for LoxBerry, christiantf@gmx.at
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
use Config::Simple '-strict';
use LoxBerry::System;
use LoxBerry::Web;
use HTML::Entities;
use CGI;
use warnings;
use strict;

##########################################################################
# Variables
##########################################################################

my $helplink = "http://www.loxwiki.eu/display/LOXBERRY/LoxBerry";
my $helptemplate = "help_myloxberry.html";
my $template_title;
my $error;

my $cfg;

##########################################################################
# Read Settings
##########################################################################

# Version of this script
my $version = "0.3.1-dev1";

my $sversion = LoxBerry::System::lbversion();

$cfg             = new Config::Simple("$lbsconfigdir/general.cfg");

#########################################################################
# Parameter
#########################################################################

# Import form parameters to the namespace R
my $cgi = CGI->new;
$cgi->import_names('R');
# Example: Parameter lang is now $R::lang

if ($R::action && $R::action eq "setvalue") {
	&ajax;
}

if ($R::action && $R::action eq "download") {
	&download;
}


##########################################################################
# Language Settings
##########################################################################

if ($R::lang) {
	# Nice feature: We override language detection of LoxBerry::Web
	$LoxBerry::Web::lang = substr($R::lang, 0, 2);
}
# If we did the 'override', lblanguage will give us that language
my $lang = lblanguage();

our $maintemplate = HTML::Template->new(
				filename => "$lbstemplatedir/translate.html",
				global_vars => 1,
				loop_context_vars => 1,
				die_on_bad_params=> 0,
				associate => $cfg,
				#debug => 1,
				#stack_debug => 1,
				);

our %SL = LoxBerry::Web::readlanguage($maintemplate);

$template_title = "$SL{'COMMON.LOXBERRY_MAIN_TITLE'}: $SL{'TRANSLATE.WIDGETLABEL'} v$sversion";

##########################################################################
# Main program
##########################################################################

#########################################################################
# What should we do
#########################################################################

our %navbar;
$navbar{10}{Name} = $SL{'TRANSLATE.WIDGETLABEL_SYSTEM'};
$navbar{10}{URL} = 'translate.cgi';
 
# $navbar{20}{Name} = $SL{'TRANSLATE.WIDGETLABEL_PLUGIN'};
# $navbar{20}{URL} = 'translate.cgi?form=plugin';
 
$navbar{100}{Name} = $SL{'TRANSLATE.WIDGETLABEL_TRANSLATIONGUIDE'};
$navbar{100}{URL} = 'http://www.loxwiki.eu:80/x/QgZ7AQ';
$navbar{100}{target} = '_blank'; 

$navbar{10}{active} = 1;   
   
&form;

exit;

#####################################################
# Form / Menu
#####################################################

sub form {

	$maintemplate->param( "FORM", 1);
	$maintemplate->param ("SELFURL", $ENV{REQUEST_URI});

	my %srclanguages = (
		'en'  => 'English',
	#	'de'  => 'German',
	);
	my $sourcelang = $cgi->popup_menu(
				-name   => 'sourcelang',
				-id => 'sourcelang',
				-tabindex => 1,
				-values => [sort keys %srclanguages],
				-labels => \%srclanguages
   );
	$maintemplate->param ( 'sourcelang', $sourcelang);
	
	my $destlang = $cgi->textfield(
			-name=>'destlang',
			-id=>'destlang',
			-tabindex=>2,
		    -value=>'',
		    -size=>10,
		    -maxlength=>2
	);
	$maintemplate->param ( 'destlang', $destlang);
	
	my @langarray;
	
	if ($R::sourcelang) {
		my $srclangfile = "$lbstemplatedir/lang/language_" . $R::sourcelang . ".ini";
		my $destlangfile = "$lbstemplatedir/lang/language_" . $R::destlang . ".ini" if ($R::destlang && length($R::destlang) == 2);
		if (length($R::sourcelang) == 2) { 
			@langarray = readfile($srclangfile, $destlangfile);
		}
	}
		
	
	$maintemplate->param ( 'langarray' => \@langarray);
	
	# Print Template
	LoxBerry::Web::lbheader($template_title, $helplink, $helptemplate);
	print $maintemplate->output();
	LoxBerry::Web::lbfooter();
	exit;

}

#####################################################
# 
# Subroutines
#
#####################################################

sub readfile {

	my ($srcfile, $destfile) = @_;
	
	my @langarray = ();
	my $currsection = "";
	my $tabindex = 100;
	
	tie my %srclang, "Config::Simple", $srcfile if ($srcfile && -e $srcfile);
	tie my %destlang, "Config::Simple", $destfile if ($destfile && -e $destfile);
	
	foreach my $key (sort keys %srclang) {
		my %langhash;
		#encode_entities
		my ($thissection) = split(/\./, $key);
		# print STDERR "Key: $key Section: " . $thissection . "\n";
		if ($thissection ne $currsection) {
			print STDERR "Section $thissection (key is $key)\n";
			$langhash{'SECTION'} = $thissection;
			$currsection = $thissection;
			push(@langarray, \%langhash);
			redo;			
		}
		
		$langhash{'KEY'} = encode_entities($key);
		if(ref($srclang{$key}) eq 'ARRAY') {
			my $srcstring = getstringfromarray($srclang{$key});
			$langhash{'TEXT'} = encode_entities($srcstring, '<>&"');
			$langhash{'TEXT_ERROR'} = $SL{'TRANSLATE.ERROR_SOURCEFILE'};
			print STDERR "Error in source language $srcfile Key $key\n";
		} else {
			$langhash{'TEXT'} = encode_entities($srclang{$key}, '<>&"');
		}
		if(ref($destlang{$key}) eq 'ARRAY') {
			my $dststring = getstringfromarray($destlang{$key});
			$langhash{'TRANSLATION'} = encode_entities($dststring, '<>&"');
			$langhash{'TRANSLATION_ERROR'} = $SL{'TRANSLATE.ERROR_DESTFILE'};
			print STDERR "Error in destination language $destfile Key $key\n";
		} else {
			$langhash{'TRANSLATION'} = encode_entities($destlang{$key}, '<>&"');
		}
		$langhash{'CELL_EMPTY'} = "CellEmpty" if (!$destlang{$key});
		$langhash{'CELL_EQUAL'} = "CellEqual" if ($destlang{$key} && $srclang{$key} eq $destlang{$key});
		$tabindex++;
		$langhash{'TABINDEX'} = $tabindex;
		
		#if (! $Config{$setting} ) {
		#	print STDERR "<INFO> Setting missing or empty key $setting to $Default{$setting}\n";
		#	$Config{$setting} = $Default{$setting};
		push(@langarray, \%langhash);
	}
	return @langarray;
}

sub ajax
{
	print STDERR "ajax called.\n";
	my $cfg;
	my $isnew;
	if ($R::action eq "setvalue" && length($R::destlang) == 2) {
		my $filename = "$lbstemplatedir/lang/language_" . $R::destlang . ".ini";
		if(! -e $filename) {
			$isnew=1;
			$cfg = new Config::Simple(syntax=>'ini');
		}	
		
		$cfg = new Config::Simple($filename) if (! $isnew);
		$cfg->param($R::key, $R::text);
		$cfg->write() if (! $isnew);
		$cfg->write($filename) if ($isnew);
		print $cgi->header('text/html');
		print "OK";
		exit(0);
	}
}

sub getstringfromarray
{
	my $str;
	$str .= $_[0][0] if ($_[0][0]);
	$str .= ", " . $_[0][1] if ($_[0][1]);
	$str .= ", " . $_[0][2] if ($_[0][2]);
	$str .= ", " . $_[0][3] if ($_[0][3]);
	$str .= ", " . $_[0][4] if ($_[0][4]);
	$str .= ", " . $_[0][5] if ($_[0][5]);
	$str .= ", " . $_[0][6] if ($_[0][6]);
	$str .= ", " . $_[0][7] if ($_[0][7]);
	$str .= ", " . $_[0][8] if ($_[0][8]);
	$str .= ", " . $_[0][9] if ($_[0][9]);
	$str .= ", " . $_[0][10] if ($_[0][10]);
	$str .= ", " . $_[0][11] if ($_[0][11]);
	$str .= ", " . $_[0][12] if ($_[0][12]);
	$str .= ", " . $_[0][13] if ($_[0][13]);
	$str .= ", " . $_[0][14] if ($_[0][14]);
	$str .= ", " . $_[0][15] if ($_[0][15]);
	$str .= ", " . $_[0][16] if ($_[0][16]);
	$str .= ", " . $_[0][17] if ($_[0][17]);
	$str .= ", " . $_[0][18] if ($_[0][18]);
	$str .= ", " . $_[0][19] if ($_[0][19]);
	$str .= ", " . $_[0][20] if ($_[0][20]);
	
	
	print STDERR "getstringfromarray: String: $str\n";
	return $str;
}

sub download
{
	my $filename = "$lbstemplatedir/lang/language_" . $R::destlang . ".ini" if ($R::destlang);
	
	if (!$R::destlang || ! -e $filename) {
		$cgi->header->status('405 Method Not Allowed');
		print $cgi->header('text/plain');
		exit(1);
	}
	my $suggestedfilename = "language_" . $R::destlang . ".ini";
	my $filecontent;
	
	open(my $fh, "<" , $filename) or 
		do {
			$cgi->header->status('500 Cannot read file');
			print $cgi->header('text/plain');
			exit(1);
		};
	{ 
		local $/;
		$filecontent = <$fh>; 
	}
	close ($fh);
	print $cgi->header( 
			-type => 'application/x-download',
			-attachment => $suggestedfilename,
			-charset => 'utf-8',
		);
	print $filecontent;
	exit(0);

}


