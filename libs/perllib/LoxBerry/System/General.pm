#!/usr/bin/perl

#use Carp;
use warnings;
use strict;

package LoxBerry::System::General;
use parent 'LoxBerry::JSON';

our $VERSION = "2.0.2.2";
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
		print STDERR "write: call _json2cfg\n" if $DEBUG;
		$self->_json2cfg();
	}
	return $changed;
}

sub _json2cfg
{
	my $self = shift;
	print STDERR "Re-Create general.cfg\n" if $DEBUG;
		
	## Section [BASE]
	my @base;
	my $b = $self->{jsonobj}->{Base};
	push( @base, '[BASE]' );
	push( @base, 'VERSION='.$b->{Version} );
	push( @base, 'SENDSTATISTIC='.$b->{Sendstatistic} );
	push( @base, 'SYSTEMLOGLEVEL='.$b->{Systemloglevel} );
	push( @base, 'STARTSETUP='.$b->{Startsetup} );
	push( @base, 'LANG='.$b->{Lang} );
	push( @base, 'CLOUDDNS='.$b->{Clouddnsuri} );
	push( @base, 'INSTALLFOLDER='.$ENV{'LBHOMEDIR'});
	
	## Section [UPDATE]
	my @update;
	my $u = $self->{jsonobj}->{Update};
	push( @update, '[UPDATE]' );
	push( @update, 'INTERVAL='.$u->{Interval} );
	push( @update, 'RELEASETYPE='. $u->{Releasetype} );
	push( @update, 'INSTALLTYPE='. $u->{Installtype} );
	push( @update, 'LATESTSHA='. $u->{Latestsha} );
	push( @update, 'FAILED_SCRIPT='. $u->{Failedscript} ) if $u->{Failedscript};
	push( @update, 'BRANCH='. $u->{Branch} ) if $u->{Branch} ;
	push( @update, 'DRYRUN='. $u->{Dryrun} ) if $u->{Dryrun};
	push( @update, 'KEEPUPDATEFILES='. $u->{Keepupdatefiles} ) if $u->{Keepupdatefiles};
	push( @update, 'KEEPINSTALLFILES='. $u->{Keepinstallfiles} ) if $u->{Keepinstallfiles};
	
	## Section [WEBSERVER]
	my @webserver;
	my $w = $self->{jsonobj}->{Webserver};
	push( @webserver, '[WEBSERVER]' );
	push( @webserver, 'PORT=' . $w->{Port} );
	
	## Section [NETWORK]
	my @network;
	my $n = $self->{jsonobj}->{Network};
	push( @network, '[NETWORK]' );
	push( @network, 'TYPE='.$n->{Ipv4}->{Type} );
	push( @network, 'IPADDRESS='.$n->{Ipv4}->{Ipaddress} );
	push( @network, 'MASK='.$n->{Ipv4}->{Mask} );
	push( @network, 'DNS='.$n->{Ipv4}->{Dns} );
	push( @network, 'GATEWAY='.$n->{Ipv4}->{Gateway} );
	push( @network, 'TYPE_IPv6='.$n->{Ipv6}->{Type} );
	push( @network, 'IPADDRESS_IPv6='.$n->{Ipv6}->{Ipaddress} );
	push( @network, 'MASK_IPv6='.$n->{Ipv6}->{Mask} );
	push( @network, 'DNS_IPv6='.$n->{Ipv6}->{Dns} );
	push( @network, 'PRIVACYEXT_IPv6='.$n->{Ipv6}->{Privacyext} );
	push( @network, 'INTERFACE='.$n->{Interface} );
	push( @network, 'FRIENDLYNAME='.$n->{Friendlyname} );
	push( @network, 'SSID='.$n->{Ssid} );
	push( @network, 'WPA='.$n->{Wpa} );
	
	## Section [SSDP]
	my @ssdp;
	my $ssdp = $self->{jsonobj}->{Ssdp};
	push( @ssdp, '[SSDP]' );
	push( @ssdp, 'DISABLED=' . $ssdp->{Disabled} );
	push( @ssdp, 'UUID=' . $ssdp->{Uuid} );
	
	## Section [TIMESERVER]
	my @timeserver;
	my $ts = $self->{jsonobj}->{Timeserver};
	push( @timeserver, '[TIMESERVER]' );
	push( @timeserver, 'METHOD=' . $ts->{Method} );
	push( @timeserver, 'SERVER=' . $ts->{Ntpserver} );
	push( @timeserver, 'ZONE=' . $ts->{Timezone} );
	
	## Section [TIMESERVER]
	my @miniservers;
	my $miniserver = $self->{jsonobj}->{Miniserver};
	foreach my $msnr ( sort keys %$miniserver ) {
		push ( @miniservers, '[MINISERVER'.$msnr.']' );
		my $ms = $self->{jsonobj}->{Miniserver}->{$msnr};
		push ( @miniservers, 'NAME='.$ms->{Name} );
		push ( @miniservers, 'IPADDRESS='.$ms->{Ipaddress} );
		push ( @miniservers, 'ADMIN='.$ms->{Admin} );
		push ( @miniservers, 'ADMIN_RAW='.$ms->{Admin_raw} );
		push ( @miniservers, 'PASS='.$ms->{Pass} );
		push ( @miniservers, 'PASS_RAW='.$ms->{Pass_raw} );
		push ( @miniservers, 'CREDENTIALS='.$ms->{Credentials} );
		push ( @miniservers, 'CREDENTIALS_RAW='.$ms->{Credentials_raw} );
		push ( @miniservers, 'NOTE='.$ms->{Note} );
		push ( @miniservers, 'PORT='.$ms->{Port} );
		push ( @miniservers, 'USECLOUDDNS='.$ms->{Useclouddns} );
		push ( @miniservers, 'CLOUDURLFTPPORT='.$ms->{Cloudurlftpport} );
		push ( @miniservers, 'CLOUDURL='.$ms->{Cloudurl} );
		push ( @miniservers, '' );
	}
	
	# Set BASE.MINISERVERS
	push( @base, 'MINISERVERS=' . scalar keys %$miniserver );
	
	
	
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

	open( my $fh, '>', $self->{_generalcfg} );
	flock( $fh, 2 ); # Exclusive lock
	print $fh "# This file is generated automatically by changes of general.json\n";
	print $fh "# Manual changes will be overwritten.\n\n";
	print $fh join( "\n", @base );
	print $fh "\n\n";
	print $fh join( "\n", @update );
	print $fh "\n\n";
	print $fh join( "\n", @webserver );
	print $fh "\n\n";
	print $fh join( "\n", @network );
	print $fh "\n\n";
	print $fh join( "\n", @ssdp );
	print $fh "\n\n";
	print $fh join( "\n", @timeserver );
	print $fh "\n\n";
	print $fh join( "\n", @miniservers );
	close $fh;

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
