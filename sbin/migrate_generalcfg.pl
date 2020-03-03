#!/usr/bin/perl
use strict;
use LoxBerry::System;
use LoxBerry::JSON;
use Config::Simple;
use URI::Escape;

my $version = "2.0.2.2";

my $lbsconfigdir = $ENV{'LBSCONFIG'};	
if (! $lbsconfigdir ) {
	print STDERR "LoxBerry::System::General: Warn: lbsconfigdir needs to be loaded from LoxBerry::System (performance)\n";
	$lbsconfigdir = $LoxBerry::System::lbsconfigdir;
}
if(!$lbsconfigdir) {
	die "CRITICAL: Could not aquire lbsconfigdir. Terminating.\n";
}

my $generaljson = $lbsconfigdir.'/general.json';
my $generalcfg = $lbsconfigdir.'/general.cfg';

# DEBUG
# Create a backup of general.json
use File::Copy;
copy $generaljson, $generaljson.".".time.".old";

# Open general.json
# We do not use LoxBerry::System::General here, as it immedately would overwrite the old general.cfg
# with the legacy file creation
my $jsonobj = LoxBerry::JSON->new();
my $json = $jsonobj->open( filename => $generaljson);
if( !$json) {
	die "CRITICAL: general.json could not be loaded. Terminating.\n";
}

# Open general.cfg
my %cfg;
print STDERR "general.cfg: $lbsconfigdir\n";
Config::Simple->import_from( $generalcfg, \%cfg ) or die "CRITICAL: $generalcfg could not be loaded. Terminating.\n";


migrate_base();
migrate_update();
migrate_webserver();
migrate_network();
migrate_ssdp();
migrate_timeserver();
migrate_miniserver();

$jsonobj->write();


exit(0);

# =========================================================
# migrate_generalcfg 
# =========================================================
sub migrate_base 
{
	## Migrating [BASE]
	my $b;
	$b->{Version} = $cfg{'BASE.VERSION'};
	$b->{Sendstatistic} = LoxBerry::System::is_enabled( $cfg{'BASE.SENDSTATISTIC'} ) ? 1 : 0;
	$b->{Systemloglevel} = $cfg{'BASE.SYSTEMLOGLEVEL'};
	$b->{Startsetup} = $cfg{'BASE.STARTSETUP'};
	$b->{Lang} = $cfg{'BASE.LANG'};
	$b->{Clouddnsuri} = $cfg{'BASE.CLOUDDNS'};
	$json->{Base} = $b;
	# Miniserver count MINISERVERS not migrated
	# Installation folder INSTALLFOLDER not migrated
}

sub migrate_update
{
	## Migrating [UPDATE]
	my $u;
	$u->{Interval} = $cfg{'UPDATE.INTERVAL'};
	$u->{Releasetype} = $cfg{'UPDATE.RELEASETYPE'};
	$u->{Installtype} = $cfg{'UPDATE.INSTALLTYPE'};
	$u->{Latestsha} = $cfg{'UPDATE.LATESTSHA'};
	$u->{Failedscript} = $cfg{'UPDATE.FAILED_SCRIPT'} if( !defined $u->{Failedscript} );
	$u->{Branch} = $cfg{'UPDATE.BRANCH'} if( !defined $u->{Branch} );
	$u->{Dryrun} = $cfg{'UPDATE.DRYRUN'} if( !defined $u->{Dryrun} );
	$u->{Keepupdatefiles} = $cfg{'UPDATE.KEEPUPDATEFILES'} if( !defined $u->{Keepupdatefiles} );
	$u->{Keepinstallfiles} = $cfg{'UPDATE.KEEPINSTALLFILES'} if( !defined $u->{Keepinstallfiles} );
	$json->{Update} = $u;
}

sub migrate_webserver
{
	## Migrating [WEBSERVER]
	my $w;
	$w->{Port} = $cfg{'WEBSERVER.PORT'};
	$w->{Porthttps} = 443;
	$json->{Webserver} = $w;
}

sub migrate_network
{
	## Migrating [NETWORK]
	my $n;
	$n->{Ipv4}->{Type} = $cfg{'NETWORK.TYPE'};
	$n->{Ipv4}->{Ipaddress} = $cfg{'NETWORK.IPADDRESS'};
	$n->{Ipv4}->{Mask} = $cfg{'NETWORK.MASK'};
	$n->{Ipv4}->{Dns} = $cfg{'NETWORK.DNS'};
	$n->{Ipv4}->{Gateway} = $cfg{'NETWORK.GATEWAY'};
		
	$n->{Ipv6}->{Type} = $cfg{'NETWORK.TYPE_IPv6'};
	$n->{Ipv6}->{Ipaddress} = $cfg{'NETWORK.IPADDRESS_IPv6'};
	$n->{Ipv6}->{Mask} = $cfg{'NETWORK.MASK_IPv6'};
	$n->{Ipv6}->{Dns} = $cfg{'NETWORK.DNS_IPv6'};
	$n->{Ipv6}->{Privacyext} = $cfg{'NETWORK.PRIVACYEXT_IPv6'};
	
	$n->{Interface} = $cfg{'NETWORK.INTERFACE'};
	$n->{Friendlyname} = $cfg{'NETWORK.FRIENDLYNAME'};
	$n->{Ssid} = $cfg{'NETWORK.SSID'};
	$n->{Wpa} = $cfg{'NETWORK.WPA'};
	$json->{Network} = $n;
}

sub migrate_ssdp
{
	## Migrating SSDP
	my $ssdp;
	$ssdp->{Disabled} = $cfg{'SSDP.DISABLED'};
	$ssdp->{Uuid} = $cfg{'SSDP.UUID'};
	$json->{Ssdp} = $ssdp;
}

sub migrate_timeserver
{
	## Migrating [TIMESERVER]
	my $ts;
	$ts->{Method} = $cfg{'TIMESERVER.METHOD'};
    $ts->{Ntpserver} = $cfg{'TIMESERVER.SERVER'};
    $ts->{Timemsno} = 1;
    $ts->{Timezone} = $cfg{'TIMESERVER.ZONE'};
	$json->{Timeserver} = $ts;
}

sub migrate_miniserver
{
	## Migrating [MINISERVER]
	# We duplicate code from LoxBerry::System::read_generalcfg
	my $miniservercount = $cfg{'BASE.MINISERVERS'};
	for (my $msnr = 1; $msnr <= $miniservercount; $msnr++) {
		my $ms;
		$ms->{Name} = $cfg{"MINISERVER$msnr.NAME"};
		$ms->{Ipaddress} = $cfg{"MINISERVER$msnr.IPADDRESS"};
		$ms->{Admin} = $cfg{"MINISERVER$msnr.ADMIN"};
		$ms->{Admin_raw} = URI::Escape::uri_unescape($ms->{Admin});
		$ms->{Pass} = $cfg{"MINISERVER$msnr.PASS"};
		$ms->{Pass_raw} = URI::Escape::uri_unescape($ms->{Pass});
		$ms->{Credentials} = $ms->{Admin} . ':' . $ms->{Pass};
		$ms->{Credentials_raw} = $ms->{Admin_raw} . ':' . $ms->{Pass_raw};
		$ms->{Note} = $cfg{"MINISERVER$msnr.NOTE"};
		$ms->{Port} = $cfg{"MINISERVER$msnr.PORT"};
		$ms->{Porthttps} = $cfg{"MINISERVER$msnr.PORTHTTPS"};
		$ms->{Preferhttps} = $cfg{"MINISERVER$msnr.PREFERHTTPS"};
		$ms->{Useclouddns} = $cfg{"MINISERVER$msnr.USECLOUDDNS"};
		$ms->{Cloudurlftpport} = $cfg{"MINISERVER$msnr.CLOUDURLFTPPORT"};
		$ms->{Cloudurl} = $cfg{"MINISERVER$msnr.CLOUDURL"};
		$ms->{Securegateway} = $cfg{"MINISERVER$msnr.SECUREGATEWAY"};
		$ms->{Encryptresponse} = $cfg{"MINISERVER$msnr.ENCRYPTRESPONSE"};
		
		my $transport;
		my $port;
		if( is_enabled( $ms->{Preferhttps} ) ) {
			$transport = 'https';
			$port = $ms->{Porthttps};
		} else {
			$transport = 'http';
			$port = $ms->{Port};
		}
		$ms->{Transport} = $transport;
		
		# Check if ip format is IPv6
		my $IPv6Format = '0';
		my $ipaddress = $ms->{Ipaddress};
		if( is_enabled($ms->{Useclouddns}) or index( $ipaddress, ':' ) != -1 ) {
			$IPv6Format = '1';
		}
		
		$ms->{Ipv6format} = $IPv6Format;
		if( !is_enabled($ms->{Useclouddns}) ) {
			$ipaddress = $IPv6Format eq '1' ? '['.$ipaddress.']' : $ipaddress;
			my $port = is_enabled($ms->{Preferhttps}) ? $ms->{Porthttps} : $ms->{Port};
			$ms->{Fulluri} = $transport.'://'.$ms->{Credentials}.'@'.$ipaddress.':'.$port;
			$ms->{Fulluri_raw} = $transport.'://'.$ms->{Credentials_raw}.'@'.$ipaddress.':'.$port;
		} else {
			$ms->{Fulluri} = "";
			$ms->{Fulluri_raw} = "";
		}
		# Save hash in msno
		$json->{Miniserver}->{$msnr} = $ms;
	}
}	

