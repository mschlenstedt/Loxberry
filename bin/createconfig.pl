#!/usr/bin/perl

use strict;
use LoxBerry::System;
use Config::Simple;
use File::Copy qw(copy);


# Functions to copy or update config files
# This is called in the index.cgi and on every LoxBerry Update.


if (! $lbsconfigdir || $lbsconfigdir eq "") {
	die "<CRIT> Loxberry System Config dir (lbsconfigdir) not set.\n";
}

my $defgeneralcfg_file = "$lbsconfigdir/general.cfg.default";
my $sysgeneralcfg_file = "$lbsconfigdir/general.cfg";
my $defmail_file = "$lbsconfigdir/mail.cfg.default";
my $sysmail_file = "$lbsconfigdir/mail.cfg";
my $defhtusers_file = "$lbsconfigdir/htusers.dat.default";
my $syshtusers_file = "$lbsconfigdir/htusers.dat";
my $defsecurepin_file = "$lbsconfigdir/securepin.dat.default";
my $syssecurepin_file = "$lbsconfigdir/securepin.dat";


# Call all routines for different config files
	update_generalcfg();
	update_mailcfg();
	update_htusers();
	update_securepin();

########################################################
# general.cfg
########################################################
sub update_generalcfg
{

	if (copydefault( $defgeneralcfg_file , $sysgeneralcfg_file )) 
		{ return 1; }
	
	tie my %Default, "Config::Simple", $defgeneralcfg_file;
	tie my %Config, "Config::Simple", $sysgeneralcfg_file;
	
	print STDERR "<INFO> Base Version is $Config{'BASE.VERSION'}\n"; 

	# Copy all missing keys from default to config
	foreach my $setting (keys %Default) {
		if (! $Config{$setting} ) {
			print STDERR "<INFO> Setting missing or empty key $setting to $Default{$setting}\n";
			$Config{$setting} = $Default{$setting};
		}
	}
	
	# Setting or changing other keys
	# ....
	
	

	tied(%Config)->write();

}

########################################################
# mail.cfg
########################################################
sub update_mailcfg
{

	

	if (copydefault( $defmail_file , $sysmail_file )) 
		{ return 1; }
	
	tie my %Default, "Config::Simple", $defmail_file;
	tie my %Config, "Config::Simple", $sysmail_file;
	
	# Copy all missing keys from default to config
	foreach my $setting (keys %Default) {
		if (! $Config{$setting} ) {
			print STDERR "<INFO> Setting missing or empty key $setting to $Default{$setting}\n";
			$Config{$setting} = $Default{$setting};
		}
	}
	tied(%Config)->write();
}

sub update_htusers
{
	if (copydefault( $defhtusers_file , $syshtusers_file )) 
		{ return 1; }
	
}

sub update_securepin
{
	if (copydefault( $defsecurepin_file , $syssecurepin_file )) 
		{ return 1; }
}



# 1. Parameter is source (.default file)
# 2. Parameter is destination (the users config file)
# Only copys file, if users config does not exist
# returns 1 if file was comied, otherwise undef
sub copydefault
{
	my ($template, $config) = @_;
	if (! -e "$config") {
		copy ("$template", "$config") or die "<ERROR> Could not copy $template to $config\n";
		print STDERR "<OK> Copied $template to $config.\n";
		return 1;
	}
}

