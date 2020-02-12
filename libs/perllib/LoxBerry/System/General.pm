#!/usr/bin/perl

#use Carp;
use warnings;
use strict;

package LoxBerry::System::General;
use parent 'LoxBerry::JSON';

our $VERSION = "2.0.2.1";
our $DEBUG;


sub open
{
	my $self = shift;
	if ($DEBUG) {
		print STDERR "LoxBerry::System::General: DEBUG is enabled\n";
		$LoxBerry::JSON::DEBUG = 1;
	}
	$self->_get_configdir();

	return $self->SUPER::open( filename => $self->{_generaljson}, @_);
	
	
}

sub write
{
	my $self = shift;
	my $changed = $self->SUPER::write();
	
	if ($changed) {
		print "write: call _json2cfg\n";
		$self->_json2cfg();
	}
	return $changed;
}

sub _json2cfg
{

	my @output;
	print "Re-Create general.cfg\n" if $DEBUG;
	
	# Binaries section STATIC
	my $binaries = <<'EOF';
[BINARIES]
FIND=/usr/bin/find
GREP=/bin/grep
TAR=/bin/tar
NTPDATE=/usr/sbin/ntpdate
UNZIP=/usr/bin/unzip
MAIL=/usr/bin/mailx
BASH=/bin/bash
APT=/usr/bin/apt-get
ZIP=/usr/bin/zip
GZIP=/bin/gzip
CHOWN=/bin/chown
SUDO=/usr/bin/sudo
DPKG=/usr/bin/dpkg
REBOOT=/sbin/reboot
WGET=/usr/bin/wget
CURL=/usr/bin/curl
CHMOD=/bin/chmod
SENDMAIL=/usr/sbin/sendmail
AWK=/usr/bin/awk
DOS2UNIX=/usr/bin/dos2unix
BZIP2=/bin/bzip2
DATE=/bin/date
POWEROFF=/sbin/poweroff

EOF

	# my $









}

sub _get_configdir
{
	my $self = shift;
	my $lbsconfigdir = $ENV{'LBSCONFIG'};	
	if (! $lbsconfigdir ) {
		print STDERR "LoxBerry::System::General: Warn: lbsconfigdir needs to be loaded from LoxBerry::System (performance)\n" if ($DEBUG);
		require LoxBerry::System;
		$lbsconfigdir = $LoxBerry::System::lbsconfigdir;
	}
	if(!$lbsconfigdir) {
		die "Could not aquire lbsconfigdir. Terminated.\n";
	}
	$self->{_lbsconfigdir} = $lbsconfigdir;
	$self->{_generaljson} = $self->{_lbsconfigdir}.'/general.json';
	$self->{_generalcfg} = $self->{_lbsconfigdir}.'/general.cfg';
}



# # Every unknown method is an object property
# our $AUTOLOAD;
# sub AUTOLOAD {
	# my $self = shift;
	# my $propvalue = shift;
	# # Remove qualifier from original method name
	# my $called = $AUTOLOAD =~ s/.*:://r;
	
	# if(! defined $propvalue) {
		# return $self->{$called};
	# } else {
		# $self->{$called} = $propvalue;
	# }
# }

# sub DESTROY 
# { 
	# my $self = shift;
	# my $changed = $self->SUPER::DESTROY();
	# if ($changed) {
		# print "DESTROY: call _json2cfg (changed: $changed)\n";
		# $self->_json2cfg();
	# }
# } 



#####################################################
# Finally 1; ########################################
#####################################################
1;
