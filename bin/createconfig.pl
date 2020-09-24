#!/usr/bin/perl

use strict;
use LoxBerry::System;
use LoxBerry::System::General;
use LoxBerry::JSON;
use File::Copy qw(copy);

# Version of this script
my $version = "2.0.2.1";

# Functions to copy or update config files
# This is called in the index.cgi and on every LoxBerry Update.

if (! $lbsconfigdir || $lbsconfigdir eq "") {
	die "<CRIT> Loxberry System Config dir (lbsconfigdir) not set.\n";
}

my %folderinfo = LoxBerry::System::diskspaceinfo($lbsconfigdir);
if (%folderinfo && $folderinfo{available} < 2048) {
	print STDERR "Free disk space below 2 MB. Update of configfiles skipped!\n";
	exit(1);
}

my $defgeneralcfg_file = "$lbsconfigdir/general.cfg.default";
my $sysgeneralcfg_file = "$lbsconfigdir/general.cfg";
my $defgeneraljson_file = "$lbsconfigdir/general.json.default";
my $sysgeneraljson_file = "$lbsconfigdir/general.json";
my $defmail_file = "$lbsconfigdir/mail.json.default";
my $sysmail_file = "$lbsconfigdir/mail.json";
my $defhtusers_file = "$lbsconfigdir/htusers.dat.default";
my $syshtusers_file = "$lbsconfigdir/htusers.dat";
my $defsecurepin_file = "$lbsconfigdir/securepin.dat.default";
my $syssecurepin_file = "$lbsconfigdir/securepin.dat";


# Call all routines for different config files
	update_generaljson();
	update_generalcfg();
	update_mailcfg();
	update_htusers();
	update_securepin();

########################################################
# general.cfg
########################################################
sub update_generalcfg
{
	# --> LoxBerry 2.0.2 - with general.json not required anymore


	# if (copydefault( $defgeneralcfg_file , $sysgeneralcfg_file )) 
		# { return 1; }
	
	
	# tie my %Default, "Config::Simple", $defgeneralcfg_file;
	# tie my %Config, "Config::Simple", $sysgeneralcfg_file;
	
	# print STDERR "<INFO> Base Version is $Config{'BASE.VERSION'}\n"; 

	# # Copy all missing keys from default to config
	# foreach my $setting (keys %Default) {
		# if (! $Config{$setting} ) {
			# print STDERR "<INFO> Setting missing or empty key $setting to $Default{$setting}\n";
			# $Config{$setting} = $Default{$setting};
		# }
	# }
	
	# # Setting or changing other keys
	# # ....

	# tied(%Config)->write();

}

########################################################
# general.json
########################################################
sub update_generaljson
{

	if (copydefault( $defgeneraljson_file , $sysgeneraljson_file )) 
	{ 
		my $syscfgobj = LoxBerry::System::General->new();
		my $syscfgobj->_json2cfg();
		return 1; 
	}
	
	my $defcfgobj = LoxBerry::JSON->new();
	my $syscfgobj = LoxBerry::System::General->new();
	
	my $defcfg = $defcfgobj->open(filename => $defgeneraljson_file, readonly => 1);
	my $syscfg = $syscfgobj->open(writeonclose => 0);
	
	# Merging default config to general.json
	use Hash::Merge;
	my $merger = Hash::Merge->new('LEFT_PRECEDENT');
	$merger->set_clone_behavior(0);
	$syscfgobj->{jsonobj} = $merger->merge( $syscfg, $defcfg );
	$syscfgobj->write();
}


########################################################
# mail.json
########################################################
sub update_mailcfg
{

	if (copydefault( $defmail_file , $sysmail_file )) 
		{ 	`chmod 0600 $sysmail_file`;
			return 1; }
	
	my $defmailobj = LoxBerry::JSON->new();
	my $sysmailobj = LoxBerry::JSON->new();
	
	my $defmcfg = $defmailobj->open(filename => $defmail_file, readonly => 1);
	my $sysmcfg = $sysmailobj->open(filename => $sysmail_file, writeonclose => 1);
	
	# This definitely will fail if the json holds an array instead of an object
	foreach my $firstkey (keys %$defmcfg) {
		print "$firstkey: $defmcfg->{$firstkey}\n";
		eval {
			foreach my $secondkey (keys %{$defmcfg->{$firstkey}}) {
				#print "firstkey|secondkey $firstkey|$secondkey: " . $defmcfg->{$firstkey}->{$secondkey} . "\n";
				if ( ! defined $sysmcfg->{$firstkey}->{$secondkey} ) {
					print "Setting $firstkey|$secondkey to $defmcfg->{$firstkey}->{$secondkey}\n";
					$sysmcfg->{$firstkey}->{$secondkey} = $defmcfg->{$firstkey}->{$secondkey};
				}
			}
		};
		
		if (! defined $sysmcfg->{$firstkey}) {
			print "Setting $firstkey to $defmcfg->{$firstkey}\n";
			$sysmcfg->{$firstkey} = $defmcfg->{$firstkey};
		}
		
	}
	`chmod 0600 $sysmail_file`;
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

