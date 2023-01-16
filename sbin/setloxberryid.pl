#!/usr/bin/perl

# Copyright 2017-2020 Michael Schlenstedt, michael@loxberry.de
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

use LoxBerry::Log;
use Getopt::Long;
use LWP::UserAgent;
use LoxBerry::JSON;

my $logfilename = "$lbhomedir/log/system_tmpfs/loxberryid.log";
my $log = LoxBerry::Log->new ( package => "core", name => "loxberryid", filename => $logfilename, append => 1, addtime => 1 );

$log->loglevel(6);
LOGSTART "LogBerry setloxberryid";
$log->stdout(1);

my $jsonparser = LoxBerry::JSON->new();
my $cfg = $jsonparser->open(filename => "$lbsconfigdir/general.json", readonly => 1);
my $sendstat = is_enabled( $cfg->{"Base"}->{"Sendstatistic"} );
my $version = $cfg->{"Base"}->{"Version"};
my $lang = $cfg->{"Base"}->{"Lang"};
my $country = $cfg->{"Base"}->{"Country"};
my $curlbin = `which curl`;
undef $jsonparser;

my ($ver_major, $ver_minor, $ver_sub) = split (/\./, trim($version));

## Delete invalid lbid's (VMs not having deleted the lbid)
if (-e "$lbsconfigdir/loxberryid.cfg") {
	open($fh, "<", "$lbsconfigdir/loxberryid.cfg") or 
		do {
			LOGCRIT "Cannot open $lbsconfigdir/loxberryid.cfg: $!";
			exit(1);
		};
	my $epoch_timestamp = (stat($fh))[9];
	close $fh;
	unlink "$lbsconfigdir/loxberryid.cfg" if ($epoch_timestamp == "1517978534");
	unlink "$lbsconfigdir/loxberryid.cfg" if ($epoch_timestamp == "1521542625");
}
	
# Create new ID if no exists
if (!-e "$lbsconfigdir/loxberryid.cfg" && $sendstat) {

	create_loxberryid();
	
}

# Send ID to loxberry.de for usage statistics. Nothing more than Date/Time (in Unixformat) and
# the randomly ID will be send. No personal data, no data of your LoxBerry.
if ($sendstat) {
	
	GetOptions (
		'delay=i' => \$delay,
		'wait=i' => \$wait,
	);
	
	if ($wait && $wait > 0) {
		LOGINF "Called with wait time - sleeping for $wait seconds...";
		sleep($wait);
	}
	
	if ($delay && $delay > 0) {
		my $random = int(rand($delay));
		LOGINF "Called with delay to max. $delay seconds - sleeping randomly for $random seconds...";
		sleep($random);
		LOGINF "Continuing.";
	}
	
	# Init LWP::UserAgent
	my $ua = new LWP::UserAgent;
	$ua->timeout(15);
	$ua->ssl_opts( SSL_verify_mode => 0, verify_hostname => 0 );
	
	my $lbid;

	# Two tries
	for( my $try = 1; $try <= 2; $try++ ) {
	
		LOGOK "Try $try...";
		
		open($fh, "<", "$lbsconfigdir/loxberryid.cfg") or 
			do {
				LOGCRIT "Cannot read $lbsconfigdir/loxberryid.cfg: $!";
				exit(1);
			};
		flock($fh,2);
		$lbid = <$fh>;
		flock($fh,8);
		close($fh);
		
		# Architecture
		my $architecture;
		$architecture = "ARM" if (-e "$lbsconfigdir/is_raspberry.cfg");
		$architecture = "x86" if (-e "$lbsconfigdir/is_x86.cfg");
		$architecture = "x64" if (-e "$lbsconfigdir/is_x64.cfg");
		$architecture = "Virtuozzo" if (-e "$lbsconfigdir/is_virtuozzo.cfg");
		$architecture = "Odroid" if (-e "$lbsconfigdir/is_odroidxu3xu4.cfg");
		
		# Send LoxBerry version info
		my $url = "https://stats.loxberry.de/collect.php?id=$lbid&version=$version&ver_major=$ver_major&ver_minor=$ver_minor&ver_sub=$ver_sub&architecture=$architecture&lang=$lang&country=$country";
		
		my $response = $ua->get($url);
		
		if ( !$response->is_success ) {
			LOGERR "ERROR sending statistics: HTTP ".$response->code." ".$response->message."\n$url\n".$response->decoded_content;
			if ( $response->code eq "409" ) {
				LOGWARN "The used LoxBerry ID is blacklisted. That means, your LoxBerry ID is not unique. To fix this, we re-create a new LoxBerry ID for you.";
				create_loxberryid();
			}
		} else {
			LOGOK "Sent request successfully: HTTP ".$response->code." ".$response->message."\n$url";
			last;
		}
		
	}
	
	# Send Plugin version info
	my @plugins = LoxBerry::System::get_plugins();
	foreach my $plugin (@plugins) {
		# print STDERR "$plugin->{PLUGINDB_NO} $plugin->{PLUGINDB_TITLE} $plugin->{PLUGINDB_VERSION}\n";
		my ($ver_major, $ver_minor, $ver_sub) = split (/\./, trim($plugin->{PLUGINDB_VERSION}));
		my $url = "https://stats.loxberry.de/collectplugin.php" .
			"?uid=$lbid" .
			"&pluginmd5=" . uri_escape($plugin->{PLUGINDB_MD5_CHECKSUM}) .  
			"&plugintitle=" . uri_escape($plugin->{PLUGINDB_TITLE}) . 
			"&pluginname=" . uri_escape($plugin->{PLUGINDB_NAME}) . 
			"&plugindir=" . uri_escape($plugin->{PLUGINDB_FOLDER}) . 
			"&pluginauthor=" . uri_escape($plugin->{PLUGINDB_AUTHOR_NAME}) . 
			"&pluginemail=" . uri_escape($plugin->{PLUGINDB_AUTHOR_EMAIL}) . 
			"&ver_major=" . uri_escape($ver_major) . 
			"&ver_minor=" . uri_escape($ver_minor) . 
			"&ver_sub=" . uri_escape($ver_sub) . 
			"&version=" . uri_escape($plugin->{PLUGINDB_VERSION}); 
		
		my $response = $ua->get($url);
				
		if ( !$response->is_success ) {
			LOGCRIT "Error sending plugin statistics: HTTP ".$response->code." ".$response->message."\n$url\n".$response->decoded_content;	
		} else {
			LOGOK "Successfully sent plugin request for $plugin->{PLUGINDB_TITLE}: HTTP ".$response->code." ".$response->message."\n$url";
		}
	}
	
	# Send LoxBerry XL usage 
	if( -e '/dev/shm/loxberryxl.tmp' ) {
		my ($ver_major, $ver_minor, $ver_sub, $ver_sub2) = split (/\./, trim(LoxBerry::System::read_file('/dev/shm/loxberryxl.tmp')));
		LOGINF "LoxBerry XL version used is $ver_major.$ver_minor.$ver_sub.$ver_sub2";
		my $url = "https://stats.loxberry.de/collectplugin.php" .
			"?uid=$lbid" .
			"&pluginmd5=60dec737f394cd77cf6d79613d8a7247" .  
			"&plugintitle=" . uri_escape('LoxBerry XL') . 
			"&pluginname=loxberry_xl" . 
			"&plugindir=loxberry_xl" . 
			"&pluginauthor=". uri_escape('LoxBerry-Team') . 
			"&pluginemail=" . uri_escape('info@loxberry.de') . 
			"&ver_major=" . uri_escape($ver_major) . 
			"&ver_minor=" . uri_escape($ver_minor) . 
			"&ver_sub=" . uri_escape($ver_sub) . 
			"&version=" . uri_escape("$ver_major.$ver_minor.$ver_sub.$ver_sub2"); 
		my $response = $ua->get($url);
		if ( !$response->is_success ) {
			LOGCRIT "Error sending LoxBerry XL statistics: HTTP ".$response->code." ".$response->message."\n$url\n".$response->decoded_content;	
		} else {
			LOGOK "Successfully sent LoxBerry XL request: HTTP ".$response->code." ".$response->message."\n$url";
		}
		unlink '/dev/shm/loxberryxl.tmp';
	}
	
	
}
LOGEND "Finished successfully.";
exit;

#
# Subs
#

# Write new id to file
sub create_loxberryid {

LOGINF "Creating new random ID";

	open($fh, ">", "$lbsconfigdir/loxberryid.cfg") or 
		do {
			LOGCRIT "Cannot write $lbsconfigdir/loxberryid.cfg: $!";
			exit(1);
		};
    flock($fh,2);
    print $fh generate(128);
    flock($fh,8);
	close($fh);

}

# Create Random ID
sub generate {
        local($e) = @_;
        my($zufall,@words,$more);

        if($e =~ /^\d+$/){
                $more = $e;
        }else{
                $more = "8";
        }

        @words = qw(A B C D E F G H I J K L M N O P Q R S T U V W X Y Z a b c d e f g h i j k l m n o p q r s t u v w x y z 0 1 2 3 4 5 6 7 8 9);

        foreach (1..$more){
                $zufall .= $words[int rand($#words+1)];
        }

        return($zufall);
}
