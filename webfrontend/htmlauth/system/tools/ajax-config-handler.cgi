#!/usr/bin/perl
use strict;
use warnings;
use CGI qw/:standard/;
use Scalar::Util qw(looks_like_number);
use LoxBerry::System;
# use LoxBerry::JSON;
use JSON;
			
my $version = "2.0.0.4"; # Version of this script
			
## ABOUT %response
## The END block sends the %response as json automatically
## The default, {error} = -1, sends a 500 Internal Server Error header
## All other {error} codes send a 200 OK message, but with your set {error} code to parse in JSON
## Set $response{customresponse} = 1 to NOT send the %response as json (to send 
## your own json). The {error} = -1 rule for the header still applies!
my %response;
$response{error} = -1;
$response{message} = "Unspecified error";

my $bins = LoxBerry::System::get_binaries();

my $cgi = CGI->new;
$cgi->import_names('R');

# Prevent 'only used once' warning
$R::action if 0;
$R::value if 0;

my $action = $R::action;
my $value = $R::value;

print STDERR "Action: $action // Value: $value\n";

if    ($action eq 'secupdates') { &secupdates; }
elsif ($action eq 'secupdates-autoreboot') { &secupdatesautoreboot; }
elsif ($action eq 'poweroff') { &poweroff; }
elsif ($action eq 'reboot') { &reboot; }
elsif ($action eq 'ping') { $response{message} = "pong"; $response{error} = 0; exit; }
elsif ($action eq 'lbupdate-reltype') { &lbupdate; }
elsif ($action eq 'lbupdate-installtype') { &lbupdate; }
elsif ($action eq 'lbupdate-installtime') { &lbupdate; }
elsif ($action eq 'lbupdate-runcheck') { &lbupdate; }
elsif ($action eq 'lbupdate-runinstall') {  &lbupdate; }
elsif ($action eq 'lbupdate-updateself') {  &lbupdate; }
elsif ($action eq 'lbupdate-resetver') { change_generalcfg("BASE.VERSION", $value) if ($value); }
elsif ($action eq 'lbupdate-setmaxversion') { change_generaljson("Update->max_version", $value) ; }
elsif ($action eq 'plugin-loglevel') { plugindb_update('loglevel', $R::pluginmd5, $R::value); }
elsif ($action eq 'plugin-autoupdate') { plugindb_update('autoupdate', $R::pluginmd5, $R::value) if ($R::value); }
elsif ($action eq 'testenvironment') {  &testenvironment; }
elsif ($action eq 'changelanguage') { change_generalcfg("BASE.LANG", $value);}
elsif ($action eq 'plugininstall-status') { plugininstall_status(); }
elsif ($action eq 'pluginsupdate-check') { pluginsupdate_check(); }
elsif ($action eq 'get-clouddnsdata') { get_clouddnsdata($value); }

else   { 
	$response{error} = 1; 
	$response{message} = "<red>Action not supported.</red>"
}

exit;

################################
# unattended-upgrades setting
################################
sub secupdates
{
	print STDERR "ajax-config-handler: ajax secupdates\n";
	print STDERR "Value is: $value\n";
	
	if (!looks_like_number($value) && $value ne 'query') 
		{ $response{message} = "<red>Value $value not supported.</red>"; 
		  $response{error} = 1;
		  return();}
	
	my $aptfile = "/etc/apt/apt.conf.d/02periodic";
	open(FILE, $aptfile) || die "File not found";
	flock(FILE,1);
	my @lines = <FILE>;
	close(FILE);

	my $querystring;
	my $queryresult;
	
	my @newlines;
	foreach(@lines) {
		if (begins_with($_, "APT::Periodic::Unattended-Upgrade"))
			{   # print STDERR "############ FOUND #############";
				# if ($value eq 'query') {
					# my ($querystring, $queryresult) = split / /;
					# print STDERR "### QUERY result: " . $queryresult . "\n";
					# $queryresult =~ s/[\$"#@~!&*()\[\];.,:?^ `\\\/]+//g;
					# # print "option-secupdates-" . $queryresult;
				# } else {
				$_ = "APT::Periodic::Unattended-Upgrade \"$value\";\n"; 
				#}
			}
		if (begins_with($_, "APT::Periodic::Update-Package-Lists") && $value ne 'query')
			{   # print STDERR "############ FOUND #############";
				$_ = "APT::Periodic::Update-Package-Lists \"$value\";\n";
			}
		push(@newlines,$_);
	}

	if ($value ne 'query') {
		eval {
			open(FILE, '>', $aptfile);
			flock(FILE,2);
			print FILE @newlines;
			close(FILE);
			$response{message} = "Change of APT::Periodic::Unattended-Upgrade to $value written successfully";
			$response{error} = 0;
		};
		if ($@) {
			$response{message} = "ERROR: Change of APT::Periodic::Unattended-Upgrade to $value: $!";
			$response{error} = 1;
		}
		
	}
}

############################################
# unattended-upgrades auto-reboot setting
############################################
sub secupdatesautoreboot
{
	print STDERR "ajax-config-handler: secupdates-autoreboot\n";
	print STDERR "Value is: $value\n";
	
	if ($value ne "true" && $value ne "false" && $value ne "query") { 
		$response{message} = "<red>Value not supported.</red>"; 
		$response{error} = 1;
		return();
	}
	
	my $aptfile = "/etc/apt/apt.conf.d/50unattended-upgrades";
	open(FILE, $aptfile) || die "File not found";
	flock(FILE,1);
	my @lines = <FILE>;
	close(FILE);

	my $querystring;
	my $queryresult;
	
	my @newlines;
	foreach(@lines) {
		if (begins_with($_, "Unattended-Upgrade::Automatic-Reboot-WithUsers")) { 
			# print STDERR "############ FOUND #############";
			# if ($value eq 'query') {
				# my ($querystring, $queryresult) = split / /;
				# # print STDERR "### QUERY result: " . $queryresult . "\n";
				# $queryresult =~ s/[\$"#@~!&*()\[\];.,:?^ `\\\/]+//g; #" Syntax highlighting fix for UltraEdit
				# print "secupdates-autoreboot-" . $queryresult;
			# } else {
				$_ = $value eq "false" ? "Unattended-Upgrade::Automatic-Reboot-WithUsers \"false\";\n" : "Unattended-Upgrade::Automatic-Reboot-WithUsers \"true\";\n";
			# }
		}
		push(@newlines,$_);
	}

	if ($value ne 'query') {
		eval {
			open(FILE, '>', $aptfile);
			flock(FILE,2);
			print FILE @newlines;
			close(FILE);
			$response{message} = "Change of Unattended-Upgrade::Automatic-Reboot-WithUsers to $value written successfully";
			$response{error} = 0;
		};
		if ($@) {
			$response{message} = "ERROR: Change of Unattended-Upgrade::Automatic-Reboot-WithUsers to $value: $!";
			$response{error} = 1;
		}
	}
}

############################################
# lbupdate
############################################
sub lbupdate
{
	print STDERR "ajax-config-handler: lbupdate\n";
	
	if ($action eq 'lbupdate-runcheck') {
		my $output = qx { sudo $lbhomedir/sbin/loxberryupdatecheck.pl output=json };
		$response{error} = 0;
		$response{customresponse} = 1;
		$response{output} = $output;
		exit(0);
		
	}
	
	if ($action eq 'lbupdate-runinstall') {
		my $output = qx {sudo $lbhomedir/sbin/loxberryupdatecheck.pl output=json update=1};
		$response{error} = 0;
		$response{customresponse} = 1;
		$response{output} = $output;
		exit(0);
	}
	
	
	if ($action eq 'lbupdate-reltype') {
		if ($value eq 'release' || $value eq 'prerelease' || $value eq 'latest') { 
			change_generalcfg('UPDATE.RELEASETYPE', $value);
			$response{error} = 0;
			$response{message} = "Changed release type to $value";
		}
	return;
	}

	if ($action eq 'lbupdate-installtype') {
		unlink "$lbhomedir/system/cron/cron.daily/loxberryupdate_cron" if (-e "$lbhomedir/system/cron/cron.daily/loxberryupdate_cron");
		unlink "$lbhomedir/system/cron/cron.weekly/loxberryupdate_cron" if (-e "$lbhomedir/system/cron/cron.weekly/loxberryupdate_cron");
		unlink "$lbhomedir/system/cron/cron.monthly/loxberryupdate_cron" if (-e "$lbhomedir/system/cron/cron.monthly/loxberryupdate_cron");
		if ($value eq 'notify' || $value eq 'install') {
			if ($R::installtime eq '1') {
				symlink "$lbssbindir/loxberryupdate_cron.sh", "$lbhomedir/system/cron/cron.daily/loxberryupdate_cron" or print STDERR "Error linking $lbhomedir/system/cron/cron.daily/loxberryupdate_cron";
			} elsif ($R::installtime eq '7') {
				symlink "$lbssbindir/loxberryupdate_cron.sh", "$lbhomedir/system/cron/cron.weekly/loxberryupdate_cron" or print STDERR "Error linking $lbhomedir/system/cron/cron.weekly/loxberryupdate_cron";
			} elsif ($R::installtime eq '30') {
				symlink "$lbssbindir/loxberryupdate_cron.sh", "$lbhomedir/system/cron/cron.monthly/loxberryupdate_cron" or print STDERR "Error linking $lbhomedir/system/cron/cron.monthly/loxberryupdate_cron";
			}
		}
		if ($value eq 'disable' || $value eq 'notify' || $value eq 'install') { 
			my $ret = change_generalcfg('UPDATE.INSTALLTYPE', $value);
			if (!$ret) {
				$response{error} = 1;
				$response{message} = "Error changing lbupdate-installtype";
			} else {
				$response{error} = 0;
				$response{message} = "lbupdate-installtype changed to $value";
			}
		}
	return;
	}

	if ($action eq 'lbupdate-installtime') { 
		unlink "$lbhomedir/system/cron/cron.daily/loxberryupdate_cron" if (-e "$lbhomedir/system/cron/cron.daily/loxberryupdate_cron");
		unlink "$lbhomedir/system/cron/cron.weekly/loxberryupdate_cron" if (-e "$lbhomedir/system/cron/cron.weekly/loxberryupdate_cron");
		unlink "$lbhomedir/system/cron/cron.monthly/loxberryupdate_cron" if (-e "$lbhomedir/system/cron/cron.monthly/loxberryupdate_cron");
		if (($value eq '1' || $value eq '7' || $value eq '30') && ($R::installtype eq 'install' || $R::installtype eq 'notify')) {	
			if ($value eq '1') {
				symlink "$lbssbindir/loxberryupdate_cron.sh", "$lbhomedir/system/cron/cron.daily/loxberryupdate_cron" or print STDERR "Error linking $lbhomedir/system/cron/cron.daily/loxberryupdate_cron";
			} elsif ($value eq '7') {
				symlink "$lbssbindir/loxberryupdate_cron.sh", "$lbhomedir/system/cron/cron.weekly/loxberryupdate_cron" or print STDERR "Error linking $lbhomedir/system/cron/cron.weekly/loxberryupdate_cron";
			} elsif ($value eq '30') {
				symlink "$lbssbindir/loxberryupdate_cron.sh", "$lbhomedir/system/cron/cron.monthly/loxberryupdate_cron" or print STDERR "Error linking $lbhomedir/system/cron/cron.monthly/loxberryupdate_cron";
			}
			my $ret = change_generalcfg('UPDATE.INTERVAL', $value);
			if (!$ret) {
				$response{error} = 1;
				$response{message} = "Error changing lbupdate-installtime";
			} else {
				$response{error} = 0;
				$response{message} = "lbupdate-installtime changed to $value";
			}
		}
	return;
	}

	if ($action eq 'lbupdate-updateself') {
		my $output = qx { sudo $lbhomedir/sbin/loxberryupdatecheck.pl querytype=updateself};
		my $ret = $? >> 8;
		if($ret != 0) {
			require LoxBerry::Web;
			$response{error} = 1;
			$response{logfile_button_html} = LoxBerry::Web::logfile_button_html( PACKAGE => 'LoxBerry Update', NAME => 'check' );
		} else {
			$response{error} = 0;
		}	
		$response{customresponse} = 0;
		$response{output} = $output;

		return;
	}




}

############################################
# poweroff
############################################
sub poweroff
{
	print STDERR "ajax-config-handler: ajax poweroff - Forking poweroff\n";
	# LOGINF "Forking poweroff ...";
	$response{error} = 0;
	$response{message} = "ajax-config-handler: Executing poweroff forked...";
		
	my $pid = fork();
	if (not defined $pid) {
		$response{error} = 1;
		$response{message} = "ajax-config-handler: Cannot fork poweroff.";
		print STDERR $response{message};
		# LOGCRIT "Cannot fork poweroff.";
	} 
	if (not $pid) {	
		# LOGINF "Executing poweroff forked...";
		print STDERR $response{message};
		
		exec("$lbhomedir/sbin/sleeper.sh sudo $bins->{POWEROFF} </dev/null >/dev/null 2>&1 &");
		exit(0);
	}
	exit(0);
}

############################################
# reboot
############################################
sub reboot
{
	print STDERR "ajax-config-handler: ajax reboot\n";
	# LOGINF "Forking reboot ...";
	$response{error} = 0;
	$response{message} = "ajax-config-handler: Executing reboot forked...";
		
	my $pid = fork();
	if (not defined $pid) {
		# LOGCRIT "Cannot fork reboot.";
		$response{error} = 1;
		$response{message} = "ajax-config-handler: Cannot fork reboot.";
		print STDERR $response{message};
	}
	if (not $pid) {
		# LOGINF "Executing reboot forked...";
		print STDERR $response{message};
		exec("$lbhomedir/sbin/sleeper.sh sudo $bins->{REBOOT} </dev/null >/dev/null 2>&1 &");
		exit(0);
	}
	exit(0);
}

###################################################################
# Change Plugin log and Update settings
###################################################################
sub plugindb_update
{
	my ($action, $md5, $value) = @_;
	require LoxBerry::System::PluginDB;
	my $plugin = LoxBerry::System::PluginDB->plugin( md5 => $md5 );
	if(!$plugin) {
		$response{error} = 1;
		$response{message} = "plugindatabase: Plugin not found";
		return;
	}
	if ($action eq 'autoupdate') {
		$plugin->{autoupdate} = $value;
	}
	elsif ($action eq 'loglevel') {
		$plugin->{loglevel} = $value;
	}
	$plugin->save();
	$response{error} = 0;
	$response{message} = "plugindatabase: $action updated";
}

############################################
# pluginsupdate_check
############################################
sub pluginsupdate_check
{
	print STDERR "ajax-config-handler: ajax pluginsupdate_check\n";
	# LOGINF "Forking reboot ...";
	qx($lbhomedir/sbin/pluginsupdate.pl --checkonly >/dev/null 2>&1);
	if ($? ne 0) {
		$response{error} = -1;
		$response{message} = "Could not check plugin update status";
		exit (1);
	}
	
	$response{error} = 0;
	$response{message} = "Pluginsupdate checked successfully.";
	exit;
}

###################################################################
# test environment variables
###################################################################
sub testenvironment
{
# Script to test environment variables inside of the webserver and system() call

print "<h2>TEST 1 with system()</h2>";
print "ajax-config-handler: TESTENVIRONMENT (lbhomedir is $lbhomedir)<br>";
system("sudo $lbhomedir/sbin/testenvironment.pl");
print "ajax-config-handler: Finished.<br>";

print "<h2>TEST 2 with qx{}</h2>";
print "ajax-config-handler: TESTENVIRONMENT (lbhomedir is $lbhomedir)<br>";
my $output = qx{sudo $lbhomedir/sbin/testenvironment.pl};
print $output;
print "ajax-config-handler: Finished.<br>";

}

sub plugininstall_status
{
	print STDERR "plugininstall-status: $R::value\n";
	# Quick safety check
	if (index($R::value, '/') ne -1) {
		$response{error} = -1;
		$response{message} = "Invalid request";
		exit;
	}
	if (! -e "/tmp/$R::value") {
		$response{error} = -1;
		$response{message} = "File not found";
		exit;
	}
	open (my $fh, "<", "/tmp/$R::value");
	flock($fh, 1);
	my $status = <$fh>;
	close ($fh);
	chomp $status;
	print $cgi->header;
	print $status;
	exit;
}

################################################
# get_clouddnsdata
# Returns first matching miniserver data as json 
# for a # provided MAC address 
# Example see miniserver.html
# /admin/system/tools/ajax-config-handler.cgi?action=get-clouddnsdata&value=504f90123456
# Will return on success
# {"Name":"miniservername","Note":"MSnote","UseCloudDNS":"on","IPAddress":"79.194.49.50","Admin_uri":"loginname_uri","Port":80,"CloudURLFTPPort":"21","Credentials_RAW":"loginname:pass","CloudURL":"504f90123456","Credentials":"loginname_uri:pass_uri","Pass_RAW":"pass","Pass":"pass_uri","Admin_RAW":"dev"}
# and on error
# {"error":"Miniserver not found: 504F90123456. Please check and save your config."}
################################################
sub get_clouddnsdata
{
	my $mac = uc $R::value;
	#print STDERR "ajax-config-handler: ajax get_clouddnsdata for ${mac}";
	my %miniservers = LoxBerry::System::get_miniservers();
  	
	if (! %miniservers) 
	{
	    exit 1;
		
	}
	foreach my $ms (sort keys %miniservers) 
	{
		if ( uc "$miniservers{$ms}{CloudURL}" eq "$mac" )
		{
			#my $j = new JSON;
   			$response{error} = 0;
			$response{customresponse} = 1;
			$response{output} = encode_json($miniservers{$ms});
		    exit;
		}
	}
	$response{error} = $mac;
	$response{message} = "Miniserver with mac $mac not found";
	
	exit;
}


###################################################################
# change general.cfg (internal function)
###################################################################
sub change_generalcfg
{
	my ($key, $val) = @_;
	if (!$key) {
		return undef;
	}
	my $cfg = new Config::Simple("$lbsconfigdir/general.cfg") or return undef;

	if (!$val) {
		# Delete key
		$cfg->delete($key);
	} else {
		$cfg->param($key, $val);
	}
	$cfg->write() or return undef;
	$response{error} = 0;
	$response{message} = "OK";
	return 1;
}

###################################################################
# change general.json (internal function)
###################################################################
sub change_generaljson
{
	require LoxBerry::JSON;
	# $LoxBerry::JSON::DEBUG = 1;
	my ($key, $val) = @_;
	if (!$key) {
		return undef;
	}
	my $jsonobj = LoxBerry::JSON->new();
	my $cfg = $jsonobj->open(filename => "$lbsconfigdir/general.json") or return undef;

	my @keytree = split /->/, $key;
	my $currelem = $cfg;

	for my $elem ( 0 ... (scalar @keytree)-2 ) {
		if(! $currelem->{$keytree[$elem]}) {
			# print STDERR "Tree element $keytree[$elem] not existing -> creating\n";
			my %newtree = ();
			$currelem->{$keytree[$elem]} = \%newtree;
			$currelem = $currelem->{$keytree[$elem]};
		} else {
			$currelem = $currelem->{$keytree[$elem]};
		}
	}
	
	if (!$val) {
		# print STDERR "Deleting value\n";
		# $currelem->{$keytree[-1]} = undef;
		delete $currelem->{$keytree[-1]};
	} else {
		$currelem->{$keytree[-1]} = $val;
	}
	
	$jsonobj->write();
	$response{error} = 0;
	$response{message} = "OK";
	return 1;
}

END {

	if($response{error} == -1) {
		print $cgi->header(
			-type => 'application/json',
			-charset => 'utf-8',
			-status => '500 Internal Server Error',
		);	
	} else {
		print $cgi->header(
			-type => 'application/json',
			-charset => 'utf-8',
			-status => '200 OK',
		);	
	}

	if (!$response{customresponse}) {
		print encode_json(\%response);
	} else {
		print $response{output};
	}
	exit($response{error});

}