#!/usr/bin/perl
use strict;
use LoxBerry::System;
use LoxBerry::JSON;
use Config::Simple;
use URI::Escape;

my $version = "2.0.2.1";

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

migrate_generalcfg();
exit(0);

# =========================================================
# migrate_generalcfg 
# =========================================================
sub migrate_generalcfg 
{
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
		
	
	## Migrating [BASE]
	my $b;
	$b->{Version} = $cfg{'BASE.VERSION'};
	$b->{SendStatistic} = LoxBerry::System::is_enabled( $cfg{'BASE.SENDSTATISTIC'} ) ? 1 : 0;
	$b->{SystemLoglevel} = $cfg{'BASE.SYSTEMLOGLEVEL'};
	$b->{StartSetup} = $cfg{'BASE.STARTSETUP'};
	$b->{Lang} = $cfg{'BASE.LANG'};
	$b->{CloudDNSURI} = $cfg{'BASE.CLOUDDNS'};
	$json->{Base} = $b;
	# Miniserver count MINISERVERS not migrated
	# Installation folder INSTALLFOLDER not migrated
	
	## Migrating [UPDATE]
	my $u;
	$u->{Interval} = $cfg{'UPDATE.INTERVAL'};
	$u->{ReleaseType} = $cfg{'UPDATE.RELEASETYPE'};
	$u->{InstallType} = $cfg{'UPDATE.INSTALLTYPE'};
	$u->{LatestSHA} = $cfg{'UPDATE.LATESTSHA'};
	$u->{FailedScript} = $cfg{'UPDATE.FAILED_SCRIPT'};
	$u->{Branch} = $cfg{'UPDATE.BRANCH'};
	$u->{DryRun} = $cfg{'UPDATE.DRYRUN'};
	$u->{KeepUpdateFiles} = $cfg{'UPDATE.KEEPUPDATEFILES'};
	$u->{KeepInstallFiles} = $cfg{'UPDATE.KEEPINSTALLFILES'};
	$json->{Update} = $u;
	
	## Migrating [WEBSERVER]
	my $w;
	$w->{Port} = $cfg{'WEBSERVER.PORT'};
	$w->{PortHttps} = 443;
	$json->{Webserver} = $w;
	
	## Migrating [NETWORK]
	my $n;
	$n->{IPv4}->{Type} = $cfg{'NETWORK.TYPE'};
	$n->{IPv4}->{IPAddress} = $cfg{'NETWORK.IPADDRESS'};
	$n->{IPv4}->{Mask} = $cfg{'NETWORK.MASK'};
	$n->{IPv4}->{DNS} = $cfg{'NETWORK.DNS'};
	$n->{IPv4}->{Gateway} = $cfg{'NETWORK.GATEWAY'};
		
	$n->{IPv6}->{Type} = $cfg{'NETWORK.TYPE_IPv6'};
	$n->{IPv6}->{IPAddress} = $cfg{'NETWORK.IPADDRESS_IPv6'};
	$n->{IPv6}->{Mask} = $cfg{'NETWORK.MASK_IPv6'};
	$n->{IPv6}->{DNS} = $cfg{'NETWORK.DNS_IPv6'};
	$n->{IPv6}->{PrivacyExt} = $cfg{'NETWORK.PRIVACYEXT_IPv6'};
	
	$n->{Interface} = $cfg{'NETWORK.INTERFACE'};
	$n->{FriendlyName} = $cfg{'NETWORK.FRIENDLYNAME'};
	$n->{SSID} = $cfg{'NETWORK.SSID'};
	$n->{WPA} = $cfg{'NETWORK.WPA'};
	$json->{Network} = $n;
	
	## Migrating SSDP
	my $ssdp;
	$ssdp->{Disabled} = $cfg{'SSDP.DISABLED'};
	$ssdp->{UUID} = $cfg{'SSDP.UUID'};
	$json->{SSDP} = $ssdp;
	
	## Migrating Timeserver
	my $ts;
	$ts->{Method} = $cfg{'TIMESERVER.METHOD'};
    $ts->{NTPServer} = $cfg{'TIMESERVER.SERVER'};
    $ts->{TimeMSNo} = 1;
    $ts->{Timezone} = $cfg{'TIMESERVER.ZONE'};

	## Migrating Miniserver
	# We duplicate code from LoxBerry::System::read_generalcfg
	my $miniservercount = $cfg{'BASE.MINISERVERS'};
	for (my $msnr = 1; $msnr <= $miniservercount; $msnr++) {
		my $ms;
		$ms->{Name} = $cfg{"MINISERVER$msnr.NAME"};
		$ms->{IPAddress} = $cfg{"MINISERVER$msnr.IPADDRESS"};
		$ms->{Admin} = $cfg{"MINISERVER$msnr.ADMIN"};
		$ms->{Admin_RAW} = URI::Escape::uri_unescape($ms->{Admin});
		$ms->{Pass} = $cfg{"MINISERVER$msnr.PASS"};
		$ms->{Pass_RAW} = URI::Escape::uri_unescape($ms->{Pass});
		$ms->{Credentials} = $ms->{Admin} . ':' . $ms->{Pass};
		$ms->{Credentials_RAW} = $ms->{Admin_RAW} . ':' . $ms->{Pass_RAW};
		$ms->{Note} = $cfg{"MINISERVER$msnr.NOTE"};
		$ms->{Port} = $cfg{"MINISERVER$msnr.PORT"};
		$ms->{PortHttps} = $cfg{"MINISERVER$msnr.PORTHTTPS"};
		$ms->{PreferHttps} = $cfg{"MINISERVER$msnr.PREFERHTTPS"};
		$ms->{UseCloudDNS} = $cfg{"MINISERVER$msnr.USECLOUDDNS"};
		$ms->{CloudURLFTPPort} = $cfg{"MINISERVER$msnr.CLOUDURLFTPPORT"};
		$ms->{CloudURL} = $cfg{"MINISERVER$msnr.CLOUDURL"};
		$ms->{SecureGateway} = $cfg{"MINISERVER$msnr.SECUREGATEWAY"};
		$ms->{EncryptResponse} = $cfg{"MINISERVER$msnr.ENCRYPTRESPONSE"};
		
		my $transport;
		my $port;
		if( is_enabled( $ms->{PreferHttps} ) ) {
			$transport = 'https';
			$port = $ms->{PortHttps};
		} else {
			$transport = 'http';
			$port = $ms->{Port};
		}
		$ms->{Transport} = $transport;
		
		# Check if ip format is IPv6
		my $IPv6Format = '0';
		my $ipaddress = $ms->{IPAddress};
		if( is_enabled($ms->{UseCloudDNS}) or index( $ipaddress, ':' ) != -1 ) {
			$IPv6Format = '1';
		}
		
		$ms->{IPv6Format} = $IPv6Format;
		if( !is_enabled($ms->{UseCloudDNS}) ) {
			$ipaddress = $IPv6Format eq '1' ? '['.$ipaddress.']' : $ipaddress;
			my $port = is_enabled($ms->{PreferHttps}) ? $ms->{PortHttps} : $ms->{Port};
			$ms->{FullURI} = $transport.'://'.$ms->{Credentials}.'@'.$ipaddress.':'.$port;
			$ms->{FullURI_RAW} = $transport.'://'.$ms->{Credentials_RAW}.'@'.$ipaddress.':'.$port;
		} else {
			$ms->{FullURI} = "";
			$ms->{FullURI_RAW} = "";
		}
		# Save hash in msno
		$json->{Miniserver}->{$msnr} = $ms;
	}

	$jsonobj->write();
}	

