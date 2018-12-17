#!/usr/bin/perl

# Copyright 2017-2018 Michael Schlenstedt, michael@loxberry.de
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

my $logfilename = "$lbhomedir/log/system_tmpfs/loxberryid.log";
my $log = LoxBerry::Log->new ( package => "core", name => "loxberryid", filename => $logfilename, append => 1, addtime => 1 );

$log->loglevel(6);
LOGSTART "LogBerry setloxberryid";
$log->stdout(1);

my $cfg      = new Config::Simple("$lbsconfigdir/general.cfg");
my $sendstat = is_enabled( $cfg->param("BASE.SENDSTATISTIC") );
my $version  = $cfg->param("BASE.VERSION");
my $curlbin  = $cfg->param("BINARIES.CURL");

my ($ver_major, $ver_minor, $ver_sub) = split (/\./, trim($version));

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
	open($fh, "<", "$lbsconfigdir/loxberryid.cfg") or 
		do {
			LOGCRIT "Cannot write $lbsconfigdir/loxberryid.cfg: $!";
			exit(1);
		};
	flock($fh,2);
	my $lbid = <$fh>;
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
	my $url = "https://stats.loxberry.de/collect.php?id=$lbid&version=$version&ver_major=$ver_major&ver_minor=$ver_minor&ver_sub=$ver_sub&architecture=$architecture";
	my $output = qx { $curlbin -f -k -s -S --stderr - --show-error -o /dev/null "$url" };
	$exitcode  = $? >> 8;
	if ($exitcode != 0 ) {
		LOGCRIT "ERROR $exitcode sending statistics to $url\n$output\n";
	} else {
	LOGOK "Sent request successfully: $url\n";
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
		
		my $output = qx { $curlbin -f -k -s -S --stderr - --show-error "$url" };
		$exitcode  = $? >> 8;
		if ($exitcode != 0 ) {
			LOGCRIT "ERROR $exitcode sending statistics to $url\n$output\n";	
		} else {
		LOGOK "Successfully sent plugin request for $plugin->{PLUGINDB_TITLE}: $url\n$output\n";
		}
	}
	
	
}
LOGEND "Finished successfully.";
exit;

#
# Subs
#

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
