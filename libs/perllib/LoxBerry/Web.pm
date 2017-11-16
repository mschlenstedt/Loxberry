our $VERSION = "0.30_02";
$VERSION = eval $VERSION;
# Please change version number (numbering after underscore) on EVERY change - keep it two-digits as recommended in perlmodstyle
# Major.Minor represents LoxBerry version (e.g. 0.23 = LoxBerry V0.2.3)

use strict;
no strict "refs"; # Currently header/footer template replacement regex needs this. Ideas?

use Config::Simple;
use CGI;
use LoxBerry::System;
use Carp;
use HTML::Template;

package LoxBerry::Web;
use base 'Exporter';
our @EXPORT = qw (
		lblanguage
		get_plugin_icon
		%SL
		%L
);


##################################################################
# This code is executed on every use
##################################################################

my $lang;
our %SL; # Shortcut for System language phrases
our %L;  # Shortcut for Plugin language phrases

# Finished everytime code execution
##################################################################


##################################################################
# Get LoxBerry URL parameter or System language
##################################################################
sub lblanguage 
{
	# Return if $lang is already set
	if ($lang) {
		return $lang;
	}
	# Get lang from query 
	my $query = CGI->new();
	my $querylang = $query->param('lang');
	if ($querylang) 
		{ $lang = substr $querylang, 0, 2;
		  return $lang;
	}
	# If nothing found, get language from system settings
	my  $syscfg = new Config::Simple("$LoxBerry::System::lbhomedir/config/system/general.cfg");
	$lang = $syscfg->param("BASE.LANG");
	return substr($lang, 0, 2);
}

#####################################################
# Page-Header-Sub
# Parameters:
# 	1. Page title (e.g. Plugin title)
# 	2. Help link
#	3. Help template file (without lang)
#	
#####################################################

sub lbheader 
{
	print STDERR "== lbheader =============================================================\n";
	my $templatetext;
	
	my ($pagetitle, $helpurl, $helptemplate) = @_;

	my $lang = lblanguage();
	print STDERR "\nDetected language: $lang\n";
	our $template_title = $pagetitle ? LoxBerry::System::lbfriendlyname() . " " . $pagetitle : LoxBerry::System::lbfriendlyname() . " " . $main::template_title;
	print STDERR "friendlyname: " . LoxBerry::System::lbfriendlyname() . "\n";
	our $helplink = $helpurl ? $helpurl : $main::helplink;
	
	my $templatepath;
	my $ismultilang;
	our $helptext; 
	our %HelpPhrases;
	my $helpobj;
	my $headerobj;
	my $langfile;
	
	my $systemcall = LoxBerry::System::is_systemcall();
	
	# Help for plugin calls
	if (! defined $main::helptext and !$systemcall) {
		if (-e "$LoxBerry::System::lbtemplatedir/help/$helptemplate") {
			$templatepath = "$LoxBerry::System::lbtemplatedir/help/$helptemplate";
			$langfile = "$LoxBerry::System::lbtemplatedir/lang/$helptemplate";
			$ismultilang = 1;
		} elsif (-e "$LoxBerry::System::lbtemplatedir/$lang/$helptemplate") {
			$templatepath = "$LoxBerry::System::lbtemplatedir/$lang/$helptemplate";
		} elsif (-e "$LoxBerry::System::lbtemplatedir/en/$helptemplate") {
			$templatepath = "$LoxBerry::System::lbtemplatedir/en/$helptemplate";
		} elsif (-e "$LoxBerry::System::lbtemplatedir/de/$helptemplate") {
			$templatepath = "$LoxBerry::System::lbtemplatedir/de/$helptemplate";
		}
	}
	
	# Help for system calls
	if (! defined $main::helptext and $systemcall) {
		print STDERR "-- System Help Template --\n";
		if (-e "$LoxBerry::System::lbstemplatedir/help/$helptemplate") {
			$templatepath = "$LoxBerry::System::lbstemplatedir/help/$helptemplate";
			$langfile = "$LoxBerry::System::lbstemplatedir/lang/$helptemplate";
			$ismultilang = 1;
		} elsif (-e "$LoxBerry::System::lbstemplatedir/$lang/help/$helptemplate") {
			$templatepath = "$LoxBerry::System::lbstemplatedir/$lang/help/$helptemplate";
		} elsif (-e "$LoxBerry::System::lbstemplatedir/en/help/$helptemplate") {
			$templatepath = "$LoxBerry::System::lbstemplatedir/en/help/$helptemplate";
		} elsif (-e "$LoxBerry::System::lbstemplatedir/de/help/$helptemplate") {
			$templatepath = "$LoxBerry::System::lbstemplatedir/de/help/$helptemplate";
		}
	}
	
	## This is a multi-lang template in HTML::Template ("Loxberry 0.3x mode")
	## 
	if ($ismultilang) {
				
		print STDERR "We are in MULTILANG help mode\n";
		# Strip file extension
		$langfile =~ s/\.[^.]*$//;
		
		# Read English language as default
		# Missing phrases in foreign language will fall back to English
		my $lang_en = $langfile . "_en.ini";
		print STDERR "English language file: $lang_en\n";
		
		Config::Simple->import_from($lang_en, \%HelpPhrases) or Carp::carp(Config::Simple->error());
		
		# Read foreign language if exists and not English
		$langfile = $langfile . "_" . $lang . ".ini";
		print STDERR "Foreign language file: $langfile\n";
		
		# Now overwrite phrase variables with user language
		if ((-e $langfile) and ($lang ne 'en')) {
			Config::Simple->import_from($langfile, \%HelpPhrases) or Carp::carp(Config::Simple->error());
		}
		
		# Get another HTML::Template object for the help
		$helpobj = HTML::Template->new(
			filename => $templatepath,
			global_vars => 1,
			loop_context_vars => 1,
			die_on_bad_params=> 0,
			# associate => $langini,
			);
		
		# Insert LangPhrases
		while (my ($name, $value) = each %HelpPhrases){
			$helpobj->param("$name" => $value);
		}
					
		$helptext = $helpobj->output();
		undef $helpobj;
		undef %HelpPhrases;
	} else
	{
	## This is the legacy help generation
		print STDERR "We are in LEGACY help mode\n";
		print STDERR "templatepath: $templatepath\n";
		if ($templatepath) {
			if (open(F,"$templatepath")) {
				my @help = <F>;
				foreach (@help)
				{
					s/[\n\r]/ /g;
					$templatetext = $templatetext . $_;
				}
				close(F);
			} else {
			Carp::carp ("Help template $templatepath could not be opened - continuing without help.\n");
			}
		} else {
			Carp::carp ("Help template $templatepath could not be found - continuing without help.\n");
		}
		
		if (! $templatetext) {
			if ($lang eq 'de') {
				$templatetext = "Keine Hilfe verf&uumlgbar.";
			} else {
				$templatetext = "No further help available.";
			}
		}
		$helptext = $templatetext;
	}
	# Help is now in $helptext
	
	
	###################
	## LoxBerry Header
	$templatepath = $templatepath = "$LoxBerry::System::lbstemplatedir/header.html";
	if (! -e "$LoxBerry::System::lbstemplatedir/header.html") {
		confess ("ERROR: Missing header template " . $LoxBerry::System::lbstemplatedir . "\n");
	}
	
			
	# System language is "hardcoded" to file language_*.ini
	my $langfile  = "$LoxBerry::System::lbstemplatedir/lang/language";
	
	# Read English language as default
	# Missing phrases in foreign language will fall back to English
	Config::Simple->import_from($langfile . "_en.ini", \%SL) or Carp::carp(Config::Simple->error());

	# Read foreign language if exists and not English and overwrite English strings
	$langfile = $langfile . "_" . $lang . ".ini";
	if ((-e $langfile) and ($lang ne 'en')) {
		Config::Simple->import_from($langfile, \%SL) or Carp::carp(Config::Simple->error());
	}
	if (! %SL) {
		Carp::confess ("ERROR: Could not read any language phrases. Exiting.\n");
	}
	# Get the HTML::Template object for the header
	$headerobj = HTML::Template->new(
		filename => $templatepath,
		global_vars => 1,
		 loop_context_vars => 1,
		die_on_bad_params => 0,
	);
	while (my ($name, $value) = each %SL){
	 	 $headerobj->param("$name" => $value);
	 }

	print STDERR "template_title: $template_title\n";
	print STDERR "helplink:       $helplink\n";
	# print STDERR "helptext:       $helptext\n";
	print STDERR "Home string: " . $LoxBerry::Web::SL{'HEADER.PANEL_HOME'} . "\n";
	
	$headerobj->param( TEMPLATETITLE => $template_title);
	$headerobj->param( HELPLINK => $helplink);
	$headerobj->param( HELPTEXT => $helptext);
	$headerobj->param( LANG => $lang);
	

	print "Content-Type: text/html\n\n";
	print $headerobj->output();
	undef $headerobj;

}


#####################################################
# Page-Footer-Sub
#####################################################

sub lbfooter 
{
	my $lang = lblanguage();
	# if (open(F,"$LoxBerry::System::lbhomedir/templates/system/$lang/footer.html")) {
		# while (<F>) 
		# {
			# $_ =~ s/<!--\$(.*?)-->/${$1}/g;
			# print $_;
		# }
		# close(F);
	# } else {
		# Carp::carp ("Failed to open template system/$lang/footer.html\n");
	# }

	# Get the HTML::Template object for the header
	my $footerobj = HTML::Template->new(
		filename => "$LoxBerry::System::lbstemplatedir/footer.html",
		global_vars => 1,
		 loop_context_vars => 1,
		die_on_bad_params => 0,
	);
	$footerobj->param( LANG => $lang);
	print $footerobj->output();
	
	
	}

#####################################################
# readlanguage
# Read the language for a plugin 
# Example Call:
# my %Phrases = LoxBerry::Web::readlanguage($template, "language.ini");
#####################################################
sub readlanguage
{
	my ($template, $langfile) = @_;

	my $lang = LoxBerry::Web::lblanguage();
	my $issystem = LoxBerry::System::is_systemcall();

	# Return if we already have them in memory.
	if (!$template) { Carp::confess("ERROR: $template is empty."); }
	if (!$issystem and !$langfile) { 
		Carp::carp("WARNING: $langfile is empty, setting to language.ini. If file is missing, error will occur.");
		$langfile = "language.ini"; }
	if ($issystem and %SL) { return %SL; }
	if (!$issystem and %L) { return %L; }

	# SYSTEM Language
	if ($issystem) {
		
		# System language is "hardcoded" to file language_*.ini
		my $langfile  = "$LoxBerry::System::lbstemplatedir/lang/language";
		
		# Read English language as default
		# Missing phrases in foreign language will fall back to English
		Config::Simple->import_from($langfile . "_en.ini", \%SL) or Carp::carp(Config::Simple->error());

		# Read foreign language if exists and not English and overwrite English strings
		$langfile = $langfile . "_" . $lang . ".ini";
		if ((-e $langfile) and ($lang ne 'en')) {
			Config::Simple->import_from($langfile, \%SL) or Carp::carp(Config::Simple->error());
		}
		if (! %SL) {
			Carp::confess ("ERROR: Could not read any language phrases. Exiting.\n");
		}
		
		while (my ($name, $value) = each %SL){
			$template->param("$name" => $value);
		}
		return %SL;
	
	} else 
	# PLUGIN language
		{
		# Plugin language got in format language.ini
		# Need to re-parse the name
		$langfile =~ s/\.[^.]*$//;
		$langfile  = "$LoxBerry::System::lbtemplatedir/$langfile";
		
		# Read English language as default
		# Missing phrases in foreign language will fall back to English
		Config::Simple->import_from($langfile . "_en.ini", \%L) or Carp::carp(Config::Simple->error());

		# Read foreign language if exists and not English and overwrite English strings
		$langfile = $langfile . "_" . $lang . ".ini";
		if ((-e $langfile) and ($lang ne 'en')) {
			Config::Simple->import_from($langfile, \%L) or Carp::carp(Config::Simple->error());
		}
		if (! %L) {
			Carp::confess ("ERROR: Could not read any language phrases. Exiting.\n");
		}

		while (my ($name, $value) = each %L){
			$template->param("$name" => $value);
		}
		return %L;
	
	
	}
}

################################################################
# get_plugin_icon - Returns the Web path to the Plugin logo
# Input: Size as number in pixels
# Output: Absolute HTTP path to the Plugin icon (without server)
################################################################

sub get_plugin_icon
{
	my ($iconsize) = @_;
	$iconsize = defined $iconsize ? $iconsize : 64;
	if 		($iconsize > 256) { $iconsize = 512; }
	elsif	($iconsize > 128) { $iconsize = 256; }
	elsif	($iconsize > 64) { $iconsize = 128; }
	else					{ $iconsize = 64; }
	
	my $logopath = "$LoxBerry::System::lbhomedir/webfrontend/html/system/images/icons/$LoxBerry::System::lbplugindir/icon_$iconsize.png";
	my $logopath_web = "/system/images/icons/$LoxBerry::System::lbplugindir/icon_$iconsize.png";
	
	if (-e $logopath) { 
		return $logopath_web;
	}
	return undef;
}

#####################################################
# Finally 1; ########################################
#####################################################
1;
