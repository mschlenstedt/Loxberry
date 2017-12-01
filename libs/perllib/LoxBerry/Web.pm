our $VERSION = "0.31_06";
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
	# print STDERR "current \$lang: $LoxBerry::Web::lang\n";
	# Return if $lang is already set
	if ($LoxBerry::Web::lang) {
		return $LoxBerry::Web::lang;
	}
	# Get lang from query 
	my $query = CGI->new();
	my $querylang = $query->param('lang');
	if ($querylang) 
		{ $LoxBerry::Web::lang = substr $querylang, 0, 2;
		  # print STDERR "\$lang in CGI: $LoxBerry::Web::lang";
		  return $LoxBerry::Web::lang;
	}
	# If nothing found, get language from system settings
	my  $syscfg = new Config::Simple("$LoxBerry::System::lbhomedir/config/system/general.cfg");
	$LoxBerry::Web::lang = $syscfg->param("BASE.LANG");
	# print STDERR "\$lang from general.cfg: $LoxBerry::Web::lang";
	return substr($LoxBerry::Web::lang, 0, 2);
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
	my ($pagetitle, $helpurl, $helptemplate) = @_;
	LoxBerry::Web::head($pagetitle);
	LoxBerry::Web::pagestart($pagetitle, $helpurl, $helptemplate);
}


#####################################################
# Page-Footer-Sub
#####################################################

sub lbfooter 
{
	LoxBerry::Web::pageend();
	LoxBerry::Web::foot();
	
	}

	
#####################################################
# head
#####################################################
sub head
{

	print STDERR "== head == prints html head including <body> start =================\n";
	my $templatetext;
	my ($pagetitle) = @_;

	my $lang = lblanguage();
	print STDERR "\nDetected language: $lang\n";
	our $template_title = $pagetitle ? LoxBerry::System::lbfriendlyname() . " " . $pagetitle : LoxBerry::System::lbfriendlyname() . " " . $main::template_title;
	print STDERR "friendlyname: " . LoxBerry::System::lbfriendlyname() . "\n";
	
	my $templatepath;
	my $headobj;
	
	$templatepath = $templatepath = "$LoxBerry::System::lbstemplatedir/head.html";
	if (! -e "$LoxBerry::System::lbstemplatedir/head.html") {
		confess ("ERROR: Missing head template $templatepath \n");
	}
	
	# Get the HTML::Template object for the header
	$headobj = HTML::Template->new(
		filename => $templatepath,
		global_vars => 1,
		 loop_context_vars => 1,
		die_on_bad_params => 0,
	);
	
	LoxBerry::Web::readlanguage($headobj);
	
	$headobj->param( TEMPLATETITLE => $template_title);
	$headobj->param( LANG => $lang);
	
	print "Content-Type: text/html\n\n";
	print $headobj->output();
	undef $headobj;
}

#####################################################
# pagestart
#####################################################
sub pagestart
{
	print STDERR "== pagestart == prints page including panels =================\n";
	my $templatetext;
	
	my ($pagetitle, $helpurl, $helptemplate, $page) = @_;
	
	if (!$page) {
		$page = "main1";
	} 
	
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
		print STDERR "-- PLUGIN Help Template --\n";
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
		print STDERR "-- SYSTEM Help Template --\n";
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
		if ($templatepath && $helptemplate ne '<!--$helptext-->') {
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
		} elsif ($helptemplate eq '<!--$helptext-->') {
			$templatetext = '<!--$helptext-->';
		} else {
			Carp::carp ("Help template \$templatepath is empty - continuing without help.\n");
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
	
	$templatepath = $templatepath = "$LoxBerry::System::lbstemplatedir/pagestart.html";
	if (! -e "$LoxBerry::System::lbstemplatedir/pagestart.html") {
		confess ("ERROR: Missing pagestart template " . $templatepath . "\n");
	}
	
	# System language is "hardcoded" to file language_*.ini
	my $langfile  = "$LoxBerry::System::lbstemplatedir/lang/language";
	
	# Get the HTML::Template object for the header
	$headerobj = HTML::Template->new(
		filename => $templatepath,
		global_vars => 1,
		 loop_context_vars => 1,
		die_on_bad_params => 0,
	);
	
	LoxBerry::Web::readlanguage($headerobj);
	
	print STDERR "template_title: $template_title\n";
	print STDERR "helplink:       $helplink\n";
	# print STDERR "helptext:       $helptext\n";
	print STDERR "Home string: " . $LoxBerry::Web::SL{'HEADER.PANEL_HOME'} . "\n";
	
	$headerobj->param( 	TEMPLATETITLE => $template_title, 
						HELPLINK => $helplink, 
						HELPTEXT => $helptext, 
						PAGE => $page,
						LANG => $lang );

	# If a navigation bar is defined
	if (%main::navbar) {
		# navbar is defined as HASH
		my $topnavbar = '<div data-role="navbar">' . 
			'	<ul>';
		my $topnavbar_haselements = undef;
		foreach my $element (sort keys %main::navbar) {
			my $btnactive;
			my $btntarget;
			if ($main::navbar{$element}{active} eq 1) {
				$btnactive = ' class="ui-btn-active"';
			} else { $btnactive = undef; 
			}
			if ($main::navbar{$element}{target}) {
				$btntarget = ' target="' . $main::navbar{$element}{target} . '"';
			}
			
			if ($main::navbar{$element}{Name}) {
				$topnavbar .= '		<li><a href="' . $main::navbar{$element}{URL} . '"' . $btntarget . $btnactive . '>' . $main::navbar{$element}{Name} . '</a></li>';
				$$topnavbar_haselements = 1;
			}
		}
		$topnavbar .=  '	</ul>' .
			'</div>';	
		if ($topnavbar_haselements) {
			$headerobj->param ( TOPNAVBAR => $topnavbar);
		}
		%main::navbar = undef;
	} elsif ($main::navbar) {
		# navbar is defined as plain STRING
		$headerobj->param ( TOPNAVBAR => $main::navbar);
		$main::navbar = undef;
	} else {
		$headerobj->param ( TOPNAVBAR => "");
	}
	
	# <div data-role="navbar">
	# <ul>
		# <li><a href="#">First</a></li>
		# <li><a href="#">Second</a></li>
		# <li><a href="#">Third</a></li>
	# </ul>
	# </div>
				
	print $headerobj->output();
	undef $headerobj;
}


#####################################################
# pageend
#####################################################
sub pageend
{
	my $lang = lblanguage();
	my $templatepath = "$LoxBerry::System::lbstemplatedir/pageend.html";
	my $pageendobj = HTML::Template->new(
		filename => $templatepath,
		global_vars => 0,
		 loop_context_vars => 0,
		die_on_bad_params => 0,
	);
	$pageendobj->param( LANG => $lang);
	print $pageendobj->output();
}

#####################################################
# foot
#####################################################
sub foot
{
	my $lang = lblanguage();
	my $templatepath = "$LoxBerry::System::lbstemplatedir/foot.html";
	my $footobj = HTML::Template->new(
		filename => $templatepath,
		global_vars => 0,
		 loop_context_vars => 0,
		die_on_bad_params => 0,
	);
	$footobj->param( LANG => $lang);
	print $footobj->output();
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
		Carp::carp("WARNING: \$langfile is empty, setting to language.ini. If file is missing, error will occur.");
		$langfile = "language.ini"; }
	# if ($issystem and %SL) { return %SL; }
	# if (!$issystem and %L) { return %L; }

	# SYSTEM Language
	if ($issystem) {
		
		# System language is "hardcoded" to file language_*.ini
		my $langfile  = "$LoxBerry::System::lbstemplatedir/lang/language";
		
		if (!%SL) {
			# Read English language as default
			# Missing phrases in foreign language will fall back to English

			Config::Simple->import_from($langfile . "_en.ini", \%SL) or Carp::carp(Config::Simple->error());

			# Read foreign language if exists and not English and overwrite English strings
			$langfile = $langfile . "_" . $lang . ".ini";
			if ((-e $langfile) and ($lang ne 'en')) {
				Config::Simple->import_from($langfile, \%SL) or Carp::carp(Config::Simple->error());
			}
			if (!%SL) {
				Carp::confess ("ERROR: Could not read any language phrases. Exiting.\n");
			}
		}
		
		while (my ($name, $value) = each %SL) {
			$template->param("$name" => $value);
		}
		return %SL;
	
	} else {
	# PLUGIN language
		# Plugin language got in format language.ini
		# Need to re-parse the name
		$langfile =~ s/\.[^.]*$//;
		$langfile  = "$LoxBerry::System::lbtemplatedir/$langfile";
		
		# Read English language as default
		# Missing phrases in foreign language will fall back to English
		if (!%L) {
			Config::Simple->import_from($langfile . "_en.ini", \%L) or Carp::carp(Config::Simple->error());
		
			# Read foreign language if exists and not English and overwrite English strings
			$langfile = $langfile . "_" . $lang . ".ini";
			if ((-e $langfile) and ($lang ne 'en')) {
				Config::Simple->import_from($langfile, \%L) or Carp::carp(Config::Simple->error());
			}
			if (! %L) {
				Carp::confess ("ERROR: Could not read any language phrases. Exiting.\n");
			}
		}
		while (my ($name, $value) = each %L) {
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
