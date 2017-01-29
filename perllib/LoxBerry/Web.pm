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
# 	1. Help template file
#	2. Help link
#####################################################

sub lbheader 
{
	my ($helptemplate, $helplink) = @_;
	
	my $helptext;
	# Create Help page
	# $helplink = "http://www.loxwiki.eu:80/display/LOXBERRY/Miniserverbackup";
	
	if (-e $helptemplate) {
		if (open(F,"$helptemplate")) {
			my @help = <F>;
			foreach (@help)
			{
				s/[\n\r]/ /g;
				$helptext = $helptext . $_;
			}
			close(F);
		} else {
		carp "Help template $helptemplate could not be opened - continuing without help.\n";
		}
	} else {
		carp "Help template $helptemplate could not be found - continuing without help.\n";
	}
	
	# LoxBerry Header
	my $lang = lblanguage();
	open(F,"$lbhomedir/templates/system/$lang/header.html") || die "Missing template system/$lang/header.html";
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
