use strict;
use Config::Simple;
use CGI;
use LoxBerry::System;
use Carp;

package LoxBerry::Web;
use base 'Exporter';
our @EXPORT = qw (
		lblanguage
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
	my  $syscfg = new Config::Simple("$lbhomedir/config/system/general.cfg");
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
	my ($pagetitle, $helpurl, $helptemplate) = @_;
	
	my $templatetext;
	my $templatepath;
	my $lang = lblanguage();

	if (! defined $template_title) && (defined $pagetitle)) {
		our $template_title = $pagetitle;
	}
	
	if (! defined $helplink) && (defined $helpurl)) {
		our $helplink = $helpurl;
	}
	
	if (! defined $helptext) {
		if (-e "$lbtemplatedir/$lang/$helptemplate") {
			$templatepath = "$lbtemplatedir/$lang/$helptemplate";
		} elsif (-e "$lbtemplatedir/en/$helptemplate") {
			$templatepath = "$lbtemplatedir/en/$helptemplate";
		} elsif (-e "$lbtemplatedir/de/$helptemplate") {
			$templatepath = "$lbtemplatedir/de/$helptemplate";
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
			carp "Help template $templatepath could not be opened - continuing without help.\n";
			}
		} else {
			carp "Help template $templatepath could not be found - continuing without help.\n";
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
	if (-e "$lbhomedir/templates/system/$lang/header.html") {
		$templatepath = "$lbhomedir/templates/system/$lang/header.html";
	} elsif (-e "$lbhomedir/templates/system/en/header.html") {
		$templatepath = "$lbhomedir/templates/system/en/header.html";
	} elsif (-e "$lbhomedir/templates/system/de/header.html") {
		$templatepath = "$lbhomedir/templates/system/de/header.html";
	}
	
	if (! $templatepath) {
		confess "Missing header template for language $lang and all fallback languages - possibly an installation path issue.";
	}
		
	open(F, $templatepath) or confess "Could not read header template $templatepath - possibly a file access problem.";
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

sub footer 
{
	my $lang = lblanguage();
	if (open(F,"$lbhomedir/templates/system/$lang/footer.html")) {
		while (<F>) 
		{
			$_ =~ s/<!--\$(.*?)-->/${$1}/g;
			print $_;
		}
		close(F);
	} else {
		carp "Failed to open template system/$lang/footer.html\n";
	}
}


#####################################################
# Finally 1; ########################################
#####################################################
1;
