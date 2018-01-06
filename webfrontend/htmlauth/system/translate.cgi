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
# use LoxBerry::System;
use LoxBerry::Web;
use LoxBerry::TimeMes;
use HTML::Entities;
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use warnings;
use strict;

##########################################################################
# Variables
##########################################################################

mes "Start";

my $helplink = "http://www.loxwiki.eu/display/LOXBERRY/LoxBerry";
my $helptemplate = "help_myloxberry.html";
my $template_title;
my $error;

my $cfg;

##########################################################################
# Read Settings
##########################################################################

# Version of this script
my $version = "0.3.2.2";

my $sversion = LoxBerry::System::lbversion();

$cfg             = new Config::Simple("$lbsconfigdir/general.cfg");

#########################################################################
# Parameter
#########################################################################
mes "Initialize CGI and import names";

# Import form parameters to the namespace R
my $cgi = CGI->new;
$cgi->import_names('R');
# Example: Parameter lang is now $R::lang

if ($R::action && $R::action eq "setvalue") {
	mes "ajax setvalue";
	&ajax;
}

if ($R::action && $R::action eq "download") {
	mes "download";
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

mes "Initialize template";
our $maintemplate = HTML::Template->new(
				filename => "$lbstemplatedir/translate.html",
				global_vars => 1,
				loop_context_vars => 1,
				die_on_bad_params=> 0,
				associate => $cfg,
				%htmltemplate_options,
				#debug => 1,
				#stack_debug => 1,
	);

mes "readlanguage";
our %SL = LoxBerry::Web::readlanguage($maintemplate);
mes "set Template titles";
$template_title = "$SL{'COMMON.LOXBERRY_MAIN_TITLE'}: $SL{'TRANSLATE.WIDGETLABEL'} v$sversion";

##########################################################################
# Main program
##########################################################################

#########################################################################
# What should we do
#########################################################################
mes "Initialize NavBar";
our %navbar;
$navbar{10}{Name} = $SL{'TRANSLATE.WIDGETLABEL_SYSTEM'};
$navbar{10}{URL} = 'translate.cgi';
 
# $navbar{20}{Name} = $SL{'TRANSLATE.WIDGETLABEL_PLUGIN'};
# $navbar{20}{URL} = 'translate.cgi?form=plugin';
 
$navbar{100}{Name} = $SL{'TRANSLATE.WIDGETLABEL_TRANSLATIONGUIDE'};
$navbar{100}{URL} = 'http://www.loxwiki.eu:80/x/QgZ7AQ';
$navbar{100}{target} = '_blank'; 

$navbar{10}{active} = 1;   

mes "Call form";
&form;

mes "Before exit";
mesout;

exit;

#####################################################
# Form / Menu
#####################################################

sub form {

	mes "Create form elements";
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
	mes "Define filenames";
	if ($R::sourcelang) {
		my $srclangfile = "$lbstemplatedir/lang/language_" . $R::sourcelang . ".ini";
		my $destlangfile = "$lbstemplatedir/lang/language_" . $R::destlang . ".ini" if ($R::destlang && length($R::destlang) == 2);
		if (length($R::sourcelang) == 2) { 
			mes "readfile";
			@langarray = readfile($srclangfile, $destlangfile);
			mes "readfile finished";
		}
	}
	
	$maintemplate->param ( 'langarray' => \@langarray);
	
	mes "Print template";
	# Print Template
	LoxBerry::Web::lbheader($template_title, $helplink, $helptemplate);
	print $maintemplate->output();
	LoxBerry::Web::lbfooter();
	mes "Print template finished - before exit";
	mesout;
	exit;

}

#####################################################
# 
# Subroutines
#
#####################################################

sub readfile
{
	mes "readfile started";
	my ($srcfile, $destfile) = @_;
	mes "readinputfile SRC";
	my %src = readinputfile($srcfile, "SRC");
	mes "readinputfile DEST";
	my %dest = readinputfile($destfile, "DEST");
	my @merged;
	my $tabindex=100;
	
	mes "Loop keys";
	keys %src; # reset the internal iterator so a prior each() doesn't affect the loop
	foreach my $key (sort { $src{$a}{'SRC_LINENUMBER'} <=> $src{$b}{'SRC_LINENUMBER'} } keys %src)
	{ 	#print STDERR "Linenumber: " . $src{$key}{'SRC_LINENUMBER'} . "\n";
		my %line;
		$tabindex++;
		if ($src{$key}{'IS_SECTION'}) {
			$line{'SECTION'} = $key;
			push(@merged, \%line);
			next;
		}
		#encode_entities($srcstring, '<>&"');
		$line{'KEY'} = $src{$key}{'SECTION'} . '.' . $src{$key}{'KEY'};
		$line{'SRC_TEXT'} = encode_entities($src{$key}{'SRC_TEXT'}, '<>&"');
		$line{'SRC_WARNING'} = $src{$key}{'SRC_WARNING'};
		$line{'DEST_TEXT'} = encode_entities($dest{$key}{'DEST_TEXT'}, '<>&"');
		$line{'DEST_WARNING'} = $dest{$key}{'DEST_WARNING'};
		
		$line{'CELL_EMPTY'} = "CellEmpty" if (!$dest{$key}{'DEST_TEXT'});
		$line{'CELL_EQUAL'} = "CellEqual" if ($dest{$key}{'DEST_TEXT'} && $src{$key}{'SRC_TEXT'} eq $dest{$key}{'DEST_TEXT'});
		
		$line{'TABINDEX'} = $tabindex;
		push(@merged, \%line);
		
		#print STDERR "Key: $key Value SRC: $merged{$key}{'SRC_TEXT'} Value DEST: $merged{$key}{'DEST_TEXT'} \n";
	}
	mes "readfile returns merged";
	return @merged;
}

sub readinputfile
{
	my ($filename, $keyprefix) = @_;
	return undef if (! -e $filename);
	return undef if (! $keyprefix);
	
	$keyprefix = $keyprefix;
	
	open my $handle, '<', $filename;
	chomp(my @lines = <$handle>);
	close $handle;
	
	my %result;
	my $currsection="";
	
	for my $i (0 .. $#lines) {
		my $cl = trim($lines[$i]);
		if ($cl eq "") {
			# line is empty
			next;}
		if ( begins_with($cl, ';') or begins_with($cl, '//') or begins_with($cl, '#') or begins_with($cl, '/*') ) {
			# Comments
			next;
		}
		if ( substr($cl, 0, 1) eq '[' ) {
			# Section
			next if ( substr($cl, -1) ne ']' );
			$currsection=substr($cl, 1, -1);
			$result{$currsection}{'IS_SECTION'} = 1;
			$result{$currsection}{$keyprefix . '_' . 'LINENUMBER'} = $i;
			next;
		}
		
		my ($key, $phrase) = split(/=/, $cl, 2);
		$key = trim($key);
		$phrase = trim($phrase);
		
		if (substr($phrase, -1, 2) eq '";') {
			# Some programmer used "; - strip semicolon
			$phrase = substr($phrase, 0, -1);
		}
				
		if (substr($phrase, 0, 1) eq '"' and substr($phrase, -1, 1) eq '"') {
			# Strip doublequotes
			$phrase = substr($phrase, 1, -1);
		}
			
		my $fullkey = "$currsection.$key";
		
		$result{$fullkey}{'KEY'} = $key;
		$result{$fullkey}{'SECTION'} = $currsection;
		$result{$fullkey}{$keyprefix . '_' . 'TEXT'} = $phrase;
		$result{$fullkey}{$keyprefix . '_' . 'LINENUMBER'} = $i;
					
		# Do some checks
		# How many double-quotes?
		my $doubleqcount = $phrase =~ tr/\"//; 
		$result{$fullkey}{$keyprefix . '_' . 'WARNING'} = "Uneven doublequotes" if ($doubleqcount%2 == 1);
	}
	return %result;
	

}

sub ajax
{
	mes "ajax called";
	print STDERR "ajax called.\n";
	my $cfg;
	my $isnew;
	if ($R::action eq "setvalue" && length($R::destlang) == 2) {
		my $srcfilename = "$lbstemplatedir/lang/language_" . $R::srclang . ".ini";
		my $destfilename = "$lbstemplatedir/lang/language_" . $R::destlang . ".ini";
		
		if(! -e $srcfilename) {
			print $cgi->header('text/html');
			print "Source file does not exist";
			exit(1);
		}	
		
		mes "readinputfile SRC";
		my %src = readinputfile($srcfilename, "SRC");
		mes "readinputfile DEST";
		my %dest = readinputfile($destfilename, "DEST");
		mes "set new key/value to hash";
		$dest{$R::key}{'DEST_TEXT'} = $R::text;
		
		my @filecont;
		mes "looping keys to create content array";
		keys %src; # reset the internal iterator so a prior each() doesn't affect the loop
		foreach my $key (sort { $src{$a}{'SRC_LINENUMBER'} <=> $src{$b}{'SRC_LINENUMBER'} } keys %src)
		{ 	#print STDERR "Linenumber: " . $src{$key}{'SRC_LINENUMBER'} . "\n";
			my $line;
			if ($src{$key}{'IS_SECTION'}) {
				$line = "\n[" . $key . "]\n";
				push(@filecont, $line);
				next;
			}
		
			next if (!$dest{$key}{'DEST_TEXT'});
			$line = $src{$key}{'KEY'} . '="' . $dest{$key}{'DEST_TEXT'} . '"' . "\n";
			push(@filecont, $line);
		}	
		mes "open file for writing";
		open(my $fh, ">" , $destfilename) or 
		do {
			$cgi->header->status('500 Cannot write to file');
			print $cgi->header('text/plain');
			exit(1);
			};
		mes "write content";
		print $fh @filecont;
		mes "Close file";
		close $fh;
					
		print $cgi->header('text/html');
		print "OK";
		mes "OK printed - before exit";
		mesout;
		exit(0);
	}
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

