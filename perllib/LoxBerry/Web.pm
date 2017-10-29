our $VERSION = "0.23_03";
$VERSION = eval $VERSION;
# Please change version number (numbering after underscore) on EVERY change - keep it two-digits as recommended in perlmodstyle
# Major.Minor represents LoxBerry version (e.g. 0.23 = LoxBerry V0.2.3)

use strict;
no strict "refs"; # Currently header/footer template replacement regex needs this. Ideas?

use Config::Simple;
use CGI;
use LoxBerry::System;
use Carp;

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
	
	our $template_title = $pagetitle ? $pagetitle : $main::template_title;
	our $helplink = $helpurl ? $helpurl : $main::helplink;
	
	my $templatepath;
	
	
	if (! defined $main::helptext) {
		if (-e "$LoxBerry::System::lbtemplatedir/$lang/$helptemplate") {
			$templatepath = "$LoxBerry::System::lbtemplatedir/$lang/$helptemplate";
		} elsif (-e "$LoxBerry::System::lbtemplatedir/en/$helptemplate") {
			$templatepath = "$LoxBerry::System::lbtemplatedir/en/$helptemplate";
		} elsif (-e "$LoxBerry::System::lbtemplatedir/de/$helptemplate") {
			$templatepath = "$LoxBerry::System::lbtemplatedir/de/$helptemplate";
		}
		
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
		our $helptext = $templatetext;
	}
	
	# LoxBerry Header
	$templatepath = undef;
	if (-e "$LoxBerry::System::lbhomedir/templates/system/$lang/header.html") {
		$templatepath = "$LoxBerry::System::lbhomedir/templates/system/$lang/header.html";
	} elsif (-e "$LoxBerry::System::lbhomedir/templates/system/en/header.html") {
		$templatepath = "$LoxBerry::System::lbhomedir/templates/system/en/header.html";
	} elsif (-e "$LoxBerry::System::lbhomedir/templates/system/de/header.html") {
		$templatepath = "$LoxBerry::System::lbhomedir/templates/system/de/header.html";
	}
	
	if (! $templatepath) {
		confess ("Missing header template for language $lang and all fallback languages - possibly an installation path issue.");
	}
		
	open(F, $templatepath) or confess ("Could not read header template $templatepath - possibly a file access problem.");
	while (<F>) 
	{
		$_ =~ s/<!--\$(.*?)-->/${$1}/g;
		print $_;
	}
	close(F);
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
