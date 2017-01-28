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

##################################################################
