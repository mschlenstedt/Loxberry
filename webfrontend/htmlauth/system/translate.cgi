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
print STDERR "Execute translate.cgi\n#####################\n";
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

my $helplink = "https://www.loxwiki.eu/x/QgZ7AQ";
my $helptemplate = "help_translate.html";
my $template_title;
my $error;
my $plugin;
my $system;
my $form="";
my $cfg;

##########################################################################
# Read Settings
##########################################################################

# Version of this script
my $version = "1.4.1.1";

my $sversion = LoxBerry::System::lbversion();

$cfg = new Config::Simple("$lbsconfigdir/general.cfg");

#########################################################################
# Parameter
#########################################################################
mes "Initialize CGI and import names";

# Import form parameters to the namespace R
my $cgi = CGI->new;
$cgi->import_names('R');
# Example: Parameter lang is now $R::lang
$R::form if (0);
$form = $R::form if $R::form;

if ($form eq 'plugin' || (defined $R::plugin && $R::plugin ne "undefined") || $R::pluginform) {
	$plugin = 1;
	print STDERR "Translate: is plugin\n";
} else { 
	$system = 1;
	print STDERR "Translate: is system\n";
}

if ($R::action && $R::action eq "setvalue") {
	mes "ajax setvalue";
	&ajax;
	exit;
}

if ($R::action && $R::action eq "download") {
	mes "download";
	&download;
	exit;
}

if ($R::action && $R::action eq "getlangfiles") {
	mes "ajax getlangfiles";
	&getlangfiles (1);
	exit;
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
our %SL = LoxBerry::System::readlanguage($maintemplate);
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
 
$navbar{20}{Name} = $SL{'TRANSLATE.WIDGETLABEL_PLUGIN'};
$navbar{20}{URL} = 'translate.cgi?form=plugin';
 
$navbar{99}{Name} = $SL{'TRANSLATE.WIDGETLABEL_TRANSLATIONGUIDE'};
$navbar{99}{URL} = 'http://www.loxwiki.eu:80/x/QgZ7AQ';
$navbar{99}{target} = '_blank'; 

if ($plugin) {
	$navbar{20}{active} = 1;
} else {
	$navbar{10}{active} = 1;   
}

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
	$maintemplate->param( "SYSTEM", 1) if ($system);
	$maintemplate->param( "PLUGIN", 1) if ($plugin);
	
	$maintemplate->param( "FORM", 1);
	$maintemplate->param ("SELFURL", $ENV{REQUEST_URI});

	# Extra controls for plugins
	my $pluginlist;
	my $languagefilelist;
	
	if ($plugin) {
		
		my @plugins = LoxBerry::System::get_plugins();
		my %pluginlist;
		$pluginlist{0} = $SL{'TRANSLATE.LABEL_SELECT_PLUGIN'} . "...";
		foreach my $pluginentry (@plugins) {
			$pluginlist{$pluginentry->{PLUGINDB_FOLDER}} = $pluginentry->{PLUGINDB_TITLE};
		}
		
		$pluginlist = $cgi->popup_menu(
				-name   => 'plugin',
				-id => 'plugin',
				-tabindex => 1,
				-values => [sort keys %pluginlist],
				-labels => \%pluginlist
				 
		);
		$maintemplate->param ( 'pluginselection', $pluginlist);
	
		# $languagefilelist = $cgi->popup_menu(
				# -name   => 'languagefile',
				# -id => 'languagefile',
				# -tabindex => 2,
				# #-values => [''],
				# #-labels => \%pluginlist
		# );

	}
	
	# Common (System AND Plugin)
	
	$languagefilelist = getlangfiles(undef);
	$maintemplate->param ( 'languagefileselection', $languagefilelist);
	
	my %srclanguages = (
		'en'  => 'English',
	#	'de'  => 'German',
	);
	my $sourcelang = $cgi->popup_menu(
				-name   => 'sourcelang',
				-id => 'sourcelang',
				-tabindex => 3,
				-values => [sort keys %srclanguages],
				-labels => \%srclanguages
   );
	$maintemplate->param ( 'sourcelang', $sourcelang);
	
	my @values = LoxBerry::Web::iso_languages(0, 'values');
	my %labels = LoxBerry::Web::iso_languages(0, 'labels');
	
	# Removes English (the element with index 1) from the list as dest lang
	splice @values, 1, 1;
	
	my $destlang = $cgi->popup_menu( 
			-name => 'destlang',
			id => 'destlang',
			-labels => \%labels,
			-values => \@values,
			-tabindex => 4,
	);
	$maintemplate->param('destlang', $destlang);
	
	my @langarray;
	mes "Define filenames";
	if ($R::sourcelang && length($R::sourcelang) == 2) {
		my $srclangfile;
		my $destlangfile;
		my $langfile = substr($R::languagefile, 0, rindex($R::languagefile, "_"));
			
		if ($system) {
			$srclangfile = "$lbstemplatedir/lang/" . $langfile . "_" . $R::sourcelang . ".ini";
			$destlangfile = "$lbstemplatedir/lang/" . $langfile . "_" . $R::destlang . ".ini" if ($R::destlang && length($R::destlang) == 2);
		} elsif ($plugin) {
			$srclangfile = "$lbhomedir/templates/plugins/$R::plugin/lang/" . $langfile . "_" . $R::sourcelang . ".ini";
			$destlangfile = "$lbhomedir/templates/plugins/$R::plugin/lang/" . $langfile . "_" . $R::destlang . ".ini" if ($R::destlang && length($R::destlang) == 2);
		}
		print STDERR "Source lang file : $srclangfile\n";
		print STDERR "Dest lang file   : $destlangfile\n";
		mes "readfile";
		@langarray = readfile($srclangfile, $destlangfile);
		mes "readfile finished";
		
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
	my %dest = readinputfile($destfile, "DEST", 'fixerrors');
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
	my ($filename, $keyprefix, $fixerrors) = @_;
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
		my $fullkey = "$currsection.$key";
		$phrase = trim($phrase);
		
		# Do some checks
		my $doublecount = $phrase =~ tr/\"//; 
		my $commacount = $phrase =~ tr/,//; 
		my $escapecount = $phrase =~ tr/\\//;
		my $extradoublecount = $doublecount;
		$extradoublecount-- if substr($phrase, 0, 1) eq '"';
		$extradoublecount-- if substr($phrase, -1, 1) eq '"';
		
		# How many double-quotes?
		$result{$fullkey}{$keyprefix . '_' . 'WARNING'} .= "Uneven double quotation marks<br>" if ($doublecount%2 == 1);
		$result{$fullkey}{$keyprefix . '_' . 'WARNING'} .= "Double quotation marks required if comma in string<br>" if ($commacount > 0 && $doublecount < 2 && !$fixerrors);
		$result{$fullkey}{$keyprefix . '_' . 'WARNING'} .= "No semicolon allowed at the end<br>" if (substr($phrase, -2, 2) eq '";' && !$fixerrors);
		#$result{$fullkey}{$keyprefix . '_' . 'WARNING'} .= "Double quotation marks in phrase need to be escaped with backslash<br>" if ($extradoublecount > 0);
		#$result{$fullkey}{$keyprefix . '_' . 'WARNING'} .= "Backslashes need to be escaped with backslash<br>" if ($escapecount > 0);
		
		if (substr($phrase, -2, 2) eq '";' && $fixerrors) {
			# Some programmer used "; - strip semicolon
			$phrase = substr($phrase, 0, -1);
		}
				
		if (substr($phrase, 0, 1) eq '"' and substr($phrase, -1, 1) eq '"') {
			# Strip doublequotes
			$phrase = substr($phrase, 1, -1);
		}
		
		$result{$fullkey}{'KEY'} = $key;
		$result{$fullkey}{'SECTION'} = $currsection;
		$result{$fullkey}{$keyprefix . '_' . 'TEXT'} = $phrase;
		$result{$fullkey}{$keyprefix . '_' . 'LINENUMBER'} = $i;
		
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
		my $srcfilename;
		my $destfilename;
		my $langfile = substr($R::languagefile, 0, rindex($R::languagefile, "_"));
		if ($system) {
			$srcfilename = "$lbstemplatedir/lang/" . $langfile . "_" . $R::srclang . ".ini";
			$destfilename = "$lbstemplatedir/lang/" . $langfile . "_" . $R::destlang . ".ini";
		} elsif ($plugin && $R::languagefile) {
			$srcfilename = "$lbhomedir/templates/plugins/$R::plugin/lang/" . $langfile . "_" . $R::srclang . ".ini";
			$destfilename = "$lbhomedir/templates/plugins/$R::plugin/lang/" . $langfile . "_" . $R::destlang . ".ini" if ($R::destlang && length($R::destlang) == 2);	
		}	
		
		if(! -e $srcfilename) {
			print $cgi->header('text/plain');
			print "Source file does not exist\n";
			print "Srcfilename: $srcfilename";
			exit(1);
		}	
		
		mes "readinputfile SRC";
		my %src = readinputfile($srcfilename, "SRC");
		mes "readinputfile DEST";
		my %dest = readinputfile($destfilename, "DEST");
		mes "set new key/value to hash";
		$R::text if (0);
		$R::key if (0);
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
		flock($fh, 2);
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
	my $filename;
	my $suggestedfilename;
	my $langfile = substr($R::languagefile, 0, rindex($R::languagefile, "_"));
	$suggestedfilename = $langfile . "_" . $R::destlang . ".ini";
	if ($system) {
		$filename = "$lbstemplatedir/lang/" . $langfile . "_" . $R::destlang . ".ini" if ($R::destlang && length($R::destlang) == 2);
	} elsif ($plugin) {
		$filename = "$lbhomedir/templates/plugins/$R::plugin/lang/" . $langfile . "_" . $R::destlang . ".ini" if ($R::destlang && length($R::destlang) == 2);	
	}
	
	if (!$R::destlang || ! -e $filename) {
		print $cgi->header('text/plain', '405 Method Not Allowed');
		print '405 Method Not Allowed';
		exit(1);
	}
	
	my $filecontent;
	
	open(my $fh, "<" , $filename) or 
		do {
			print $cgi->header('text/plain', '500 Cannot read file');
			print '500 Cannot read file';
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

sub getlangfiles
{
	
	my $langdir;
	my ($ajax) = @_;
	
	# return if (! $R::plugin);
	
	if($plugin) {
		$langdir = "$lbhomedir/templates/plugins/$R::plugin/lang/";
	} 
	if ($system) {
		$langdir = "$lbstemplatedir/lang/";
		
	}
	my $globfilter = $langdir . "*_en.ini";
	my @files = glob($globfilter);
	my @filenames;
	# my %filenames;
	print STDERR "Lang filelist:\n";
	#push @filenames, "Select file ...";
	if ($system and -e $langdir . "language_en.ini") {
		# Init the main language file as preselected language
		push @filenames, "language_en.ini";
	}
	
	foreach my $file (@files) {
        print STDERR "Filename: $file\n";
		next if ($system and $file eq $langdir . "language_en.ini");
		my $rpos = rindex($file, '/');
		$file = substr $file, $rpos+1;
		push @filenames, $file;
    }
	
	use Data::Dumper;
	print STDERR Dumper(\@filenames);
	
	my $languagefilelist = $cgi->popup_menu(
				-name => 'languagefile',
				-id => 'languagefile',
				-tabindex => 2,
				#-values => [sort keys %filenames],
				-values => \@filenames,
				#-values => [''],
				#-labels => \%filenames,
		);
		
	print $cgi->header('text/html') if ($ajax);
	print $languagefilelist if ($ajax);
	return $languagefilelist if (! $ajax);
	exit;


}
