# Please increment version number on EVERY change 
# Major.Minor represents LoxBerry version (e.g. 0.3.1.12 = LoxBerry V0.3.1 the 12th change)

use strict;
use Carp;
use LoxBerry::System;
use Config::Simple;
use File::Copy qw(copy);


################################################################
package LoxBerry::CreateConfig;
our $VERSION = "0.3.1.1";
our $DEBUG;

if (! $LoxBerry::System::lbhomedir || $LoxBerry::System::lbhomedir eq "") {
	Carp::confess  "Loxberry Home not set."
}

my $defcfg_file = "$LoxBerry::System::lbsconfigdir/general.cfg.default";
my $syscfg_file = "$LoxBerry::System::lbsconfigdir/general.cfg";
my $defmail_file = "$LoxBerry::System::lbsconfigdir/mail.cfg.default";
my $sysmail_file = "$LoxBerry::System::lbsconfigdir/mail.cfg";

#######################################################################
sub update_configs
{
LoxBerry::CreateConfig::update_generalcfg();
LoxBerry::CreateConfig::update_mailcfg();


}


# general.cfg
sub update_generalcfg
{

	Carp::confess "$defcfg_file not found" if (! -e $defcfg_file);

	# If general.cfg does not exist, simply copy the default file
	if (! -e $syscfg_file) {
		File::Copy::copy ("$defcfg_file", "$syscfg_file") or Carp::confess "Could not copy $defcfg_file to $syscfg_file";
		return 1;
	}

	tie my %Default, "Config::Simple", $defcfg_file;
	tie my %Config, "Config::Simple", $syscfg_file;
	
	print STDERR "Base Version is $Config{'BASE.VERSION'}\n"; 

	# Copy all missing keys from default to config
	foreach my $setting (keys %Default) {
		if (! $Config{$setting} ) {
			print STDERR "Setting missing or empty key $setting to $Default{$setting}\n";
			$Config{$setting} = $Default{$setting};
		}
	}
	
	# Setting or changing other keys
	# ....
	# Important: Variables and functions must be called with their package name,
	# 			 e.g. $LoxBerry::System::lbhomedir or File::Copy::copy.
	
	

	tied(%Config)->write();

}

# mail.cfg
sub update_mailcfg
{

# If general.cfg does not exist, simply copy the default file
	if (! -e $sysmail_file) {
		File::Copy::copy ("$defmail_file", "$sysmail_file") or Carp::confess "Could not copy $defcfg_file to $syscfg_file";
		return 1;
	}

	tie my %Default, "Config::Simple", $defmail_file;
	tie my %Config, "Config::Simple", $sysmail_file;
	
	# Copy all missing keys from default to config
	foreach my $setting (keys %Default) {
		if (! $Config{$setting} ) {
			print STDERR "Setting missing or empty key $setting to $Default{$setting}\n";
			$Config{$setting} = $Default{$setting};
		}
	}
}



#####################################################
# Finally 1; ########################################
#####################################################
1;
