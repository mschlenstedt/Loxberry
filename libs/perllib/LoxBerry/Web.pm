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
);


##################################################################
# This code is executed on every use
##################################################################

my $lang;


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
	my $templatetext;
	
	my ($pagetitle, $helpurl, $helptemplate) = @_;

	my $lang = lblanguage();
	
	our $template_title = $pagetitle ? LoxBerry::System::lbfriendlyname . " " . $pagetitle : LoxBerry::System::lbfriendlyname . " " . $main::template_title;
	our $helplink = $helpurl ? $helpurl : $main::helplink;
	
	my $templatepath;
	my $ismultilang;
	our $helptext; 
	my %LangPhrases;
	my $helpobj;
	my $headerobj;
	
	my $systemcall = LoxBerry::System::is_systemcall();
	
	# For plugin calls
	if (! defined $main::helptext and !$systemcall) {
		if (-e "$LoxBerry::System::lbtemplatedir/help/$helptemplate") {
			$templatepath = "$LoxBerry::System::lbtemplatedir/help/$helptemplate";
			$ismultilang = 1;
		} elsif (-e "$LoxBerry::System::lbtemplatedir/$lang/$helptemplate") {
			$templatepath = "$LoxBerry::System::lbtemplatedir/$lang/$helptemplate";
		} elsif (-e "$LoxBerry::System::lbtemplatedir/en/$helptemplate") {
			$templatepath = "$LoxBerry::System::lbtemplatedir/en/$helptemplate";
		} elsif (-e "$LoxBerry::System::lbtemplatedir/de/$helptemplate") {
			$templatepath = "$LoxBerry::System::lbtemplatedir/de/$helptemplate";
		}
	}
	
	# For system calls
	if (! defined $main::helptext and $systemcall) {
		if (-e "$LoxBerry::System::lbstemplatedir/help/$helptemplate") {
			$templatepath = "$LoxBerry::System::lbstemplatedir/help/$helptemplate";
			$ismultilang = 1;
		} elsif (-e "$LoxBerry::System::lbstemplatedir/$lang/$helptemplate") {
			$templatepath = "$LoxBerry::System::lbstemplatedir/$lang/$helptemplate";
		} elsif (-e "$LoxBerry::System::lbstemplatedir/en/$helptemplate") {
			$templatepath = "$LoxBerry::System::lbstemplatedir/en/$helptemplate";
		} elsif (-e "$LoxBerry::System::lbstemplatedir/de/$helptemplate") {
			$templatepath = "$LoxBerry::System::lbstemplatedir/de/$helptemplate";
		}
	}
	
	## This is a multi-lang template in HTML::Template ("Loxberry 0.3x mode")
	## 
	if ($ismultilang) {
				
		# Strip file extension
		my $langfile  = "$LoxBerry::System::lbtemplatedir/lang/$templatepath";
		$langfile =~ s/\.[^.]*$//;
		
		# Read English language as default
		# Missing phrases in foreign language will fall back to English
		Config::Simple->import_from($langfile . "_en.ini", \%LangPhrases);

		# Read foreign language if exists and not English
		$langfile = $langfile . "_" . $lang . ".ini";
		# Now overwrite phrase variables with user language
		if ((-e $langfile) and ($lang ne 'en')) {
			Config::Simple->import_from($langfile, \%LangPhrases);
		}

		# Parse phrase variables to html templates
		# while (my ($name, $value) = each %LangPhrases){
		# 	$maintemplate->param("T::$name" => $value);
		#	#$headertemplate->param("T::$name" => $value);
		#	#$footertemplate->param("T::$name" => $value);
		#}
	
		# Get another HTML::Template object for the help
		$helpobj = HTML::Template->new(
			filename => $templatepath,
			global_vars => 1,
			# loop_context_vars => 1,
			die_on_bad_params => 0,
			associate => %LangPhrases
		);
		
		$helptext = $helpobj->output();
		undef $helpobj;
	} else
	## This is the legacy help generation
	{
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
	
			
	my $langfile  = "$LoxBerry::System::lbstemplatedir/lang/language";
	
	# Read English language as default
	# Missing phrases in foreign language will fall back to English
	Config::Simple->import_from($langfile . "_en.ini", \%LangPhrases);

	# Read foreign language if exists and not English and overwrite English strings
	$langfile = $langfile . "_" . $lang . ".ini";
	if ((-e $langfile) and ($lang ne 'en')) {
		Config::Simple->import_from($langfile, \%LangPhrases);
	}

	# Parse phrase variables to html templates
	# while (my ($name, $value) = each %LangPhrases){
	# 	$maintemplate->param("T::$name" => $value);
	#	#$headertemplate->param("T::$name" => $value);
	#	#$footertemplate->param("T::$name" => $value);
	#}

	# Get the HTML::Template object for the header
	$headerobj = HTML::Template->new(
		filename => $templatepath,
		global_vars => 1,
		# loop_context_vars => 1,
		die_on_bad_params => 0,
		associate => %LangPhrases
	);
	$headerobj->params( TEMPLATETITLE => $template_title);
	$headerobj->params( HELPLINK => $helplink);
	$headerobj->params( HELPTEXT => $helptext);
	
	print $headerobj->output();
	undef $headerobj;

}


#####################################################
# Page-Footer-Sub
#####################################################

sub lbfooter 
{
	my $lang = lblanguage();
	if (open(F,"$LoxBerry::System::lbhomedir/templates/system/$lang/footer.html")) {
		while (<F>) 
		{
			$_ =~ s/<!--\$(.*?)-->/${$1}/g;
			print $_;
		}
		close(F);
	} else {
		Carp::carp ("Failed to open template system/$lang/footer.html\n");
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
