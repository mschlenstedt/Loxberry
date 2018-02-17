#!/usr/bin/perl
use strict;
use warnings;
#use CGI::Carp qw(fatalsToBrowser);
use CGI qw/:standard/;
use Scalar::Util qw(looks_like_number);
# use Switch;
# use AptPkg::Config;
use LoxBerry::System;

my $bins = LoxBerry::System::get_binaries();

my $cgi = CGI->new;
$cgi->import_names('R');

#print $cgi->header;


# Prevent 'only used once' warning
$R::action if 0;
$R::value if 0;

my $action = $R::action;
my $value = $R::value;

print STDERR "Action: $action // Value: $value\n";

if    ($action eq 'secupdates') { print $cgi->header; &secupdates; }
elsif ($action eq 'secupdates-autoreboot') { print $cgi->header; &secupdatesautoreboot; }
elsif ($action eq 'poweroff') { print $cgi->header; &poweroff; }
elsif ($action eq 'reboot') { print $cgi->header; &reboot; }
elsif ($action eq 'ping') { print $cgi->header; print "pong"; exit; }
elsif ($action eq 'lbupdate-reltype') { print $cgi->header; &lbupdate; }
elsif ($action eq 'lbupdate-installtype') { print $cgi->header; &lbupdate; }
elsif ($action eq 'lbupdate-installtime') { print $cgi->header; &lbupdate; }
elsif ($action eq 'lbupdate-runcheck') { print $cgi->header('application/json;charset=utf-8'); &lbupdate; }
elsif ($action eq 'lbupdate-runinstall') { print $cgi->header('application/json;charset=utf-8'); &lbupdate; }
elsif ($action eq 'plugin-loglevel') {print $cgi->header; plugindb_update('loglevel', $R::pluginmd5, $R::value); }
elsif ($action eq 'plugin-autoupdate') {print $cgi->header; plugindb_update('autoupdate', $R::pluginmd5, $R::value); }
elsif ($action eq 'testenvironment') { print $cgi->header; &testenvironment; }
elsif ($action eq 'changelanguage') { print $cgi->header; change_generalcfg("BASE.LANG", $value);}
elsif ($action eq 'notify-deletekey') {print $cgi->header; notifydelete();}
elsif ($action eq 'plugininstall-status') { plugininstall_status(); }
else   { print $cgi->header; print "<red>Action not supported.</red>"; }

exit;

################################
# unattended-upgrades setting
################################
sub secupdates
{
	print STDERR "ajax-config-handler: ajax secupdates\n";
	print STDERR "Value is: $value\n";
	
	if (!looks_like_number($value) && $value ne 'query') 
		{ print "<red>Value not supported.</red>"; 
		  return();}
	
	my $aptfile = "/etc/apt/apt.conf.d/02periodic";
	open(FILE, $aptfile) || die "File not found";
	my @lines = <FILE>;
	close(FILE);

	my $querystring;
	my $queryresult;
	
	my @newlines;
	foreach(@lines) {
		if (begins_with($_, "APT::Periodic::Unattended-Upgrade"))
			{   # print STDERR "############ FOUND #############";
				if ($value eq 'query') {
					my ($querystring, $queryresult) = split / /;
					print STDERR "### QUERY result: " . $queryresult . "\n";
					$queryresult =~ s/[\$"#@~!&*()\[\];.,:?^ `\\\/]+//g;
					print "option-secupdates-" . $queryresult;
				} else {
					$_ = "APT::Periodic::Unattended-Upgrade \"$value\";\n"; }
			}
		if (begins_with($_, "APT::Periodic::Update-Package-Lists") && $value ne 'query')
			{   # print STDERR "############ FOUND #############";
				$_ = "APT::Periodic::Update-Package-Lists \"$value\";\n";
			}
		push(@newlines,$_);
	}

	if ($value ne 'query') {
		open(FILE, '>', $aptfile) || die "File not found";
		flock(FILE,2);
		print FILE @newlines;
		flock(FILE,8);
		close(FILE);
	}
}

############################################
# unattended-upgrades auto-reboot setting
############################################
sub secupdatesautoreboot
{
	print STDERR "ajax-config-handler: secupdates-autoreboot\n";
	print STDERR "Value is: $value\n";
	
	if ($value ne "true" && $value ne "false" && $value ne "query") 
		{ print "<red>Value not supported.</red>"; 
		  return();}
	
	my $aptfile = "/etc/apt/apt.conf.d/50unattended-upgrades";
	open(FILE, $aptfile) || die "File not found";
	my @lines = <FILE>;
	close(FILE);

	my $querystring;
	my $queryresult;
	
	my @newlines;
	foreach(@lines) {
		if (begins_with($_, "Unattended-Upgrade::Automatic-Reboot-WithUsers"))
			{   # print STDERR "############ FOUND #############";
				if ($value eq 'query') {
					my ($querystring, $queryresult) = split / /;
					# print STDERR "### QUERY result: " . $queryresult . "\n";
					$queryresult =~ s/[\$"#@~!&*()\[\];.,:?^ `\\\/]+//g; #" Syntax highlighting fix for UltraEdit
					print "secupdates-autoreboot-" . $queryresult;
				} else {
					$_ = $value eq "false" ? "Unattended-Upgrade::Automatic-Reboot-WithUsers \"false\";\n" : "Unattended-Upgrade::Automatic-Reboot-WithUsers \"true\";\n";}
			}
		push(@newlines,$_);
	}

	if ($value ne 'query') {
		open(FILE, '>', $aptfile) || die "File not found";
		flock(FILE,2);
		print FILE @newlines;
		flock(FILE,8);
		close(FILE);
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
		print $output;
		exit(0);
		
	}
	
	if ($action eq 'lbupdate-runinstall') {
		my $output = qx {sudo $lbhomedir/sbin/loxberryupdatecheck.pl output=json update=1};
		print $output;
		exit(0);
	}
	
	
	if ($action eq 'lbupdate-reltype') {
		if ($value eq 'release' || $value eq 'prerelease' || $value eq 'latest') { 
			change_generalcfg('UPDATE.RELEASETYPE', $value);
			print "Changed release type to $value";
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
		if ($value eq 'disabled' || $value eq 'notify' || $value eq 'install') { 
			change_generalcfg('UPDATE.INSTALLTYPE', $value);
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
			change_generalcfg('UPDATE.INTERVAL', $value);
		}
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
	my $pid = fork();
	if (not defined $pid) {
		print STDERR "ajax-config-handler: Cannot fork poweroff.";
		# LOGCRIT "Cannot fork poweroff.";
	} 
	if (not $pid) {	
		# LOGINF "Executing poweroff forked...";
		print STDERR "Executing poweroff forked...";
		
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
	my $pid = fork();
	if (not defined $pid) {
		# LOGCRIT "Cannot fork reboot.";
		print STDERR "Cannot fork reboot.";
	}
	if (not $pid) {
		# LOGINF "Executing reboot forked...";
		print STDERR "Executing reboot forked...";
		exec("$lbhomedir/sbin/sleeper.sh sudo $bins->{REBOOT} </dev/null >/dev/null 2>&1 &");
		exit(0);
	}
	exit(0);
}

###################################################################
# change general.cfg
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
	return 1;
}

###################################################################
# Change Plugin log and Update settings
###################################################################
sub plugindb_update
{
	my ($action, $md5, $value) = @_;

	my @plugin_new;
	my $dbchanged;
	
	my @plugins = LoxBerry::System::get_plugins(1);
	foreach my $plugin (@plugins) {
		my $pluginline;
		if ($plugin->{PLUGINDB_COMMENT}) {
			$pluginline = "$plugin->{PLUGINDB_COMMENT}\n";
			push(@plugin_new, $pluginline);
			next;
		}
		if ($plugin->{PLUGINDB_MD5_CHECKSUM} eq $md5) {
			if ($action eq 'autoupdate' && $plugin->{PLUGINDB_AUTOUPDATE} ne $value) {
				$plugin->{PLUGINDB_AUTOUPDATE} = $value;
				$dbchanged = 1;
			} 
			if ($action eq 'loglevel' && $plugin->{PLUGINDB_LOGLEVEL} ne $value) {
				$plugin->{PLUGINDB_LOGLEVEL} = $value;
				$dbchanged = 1;
			}
		}
		$pluginline = 
			$plugin->{PLUGINDB_MD5_CHECKSUM} . "|" . 
			$plugin->{PLUGINDB_AUTHOR_NAME} . "|" . 
			$plugin->{PLUGINDB_AUTHOR_EMAIL} . "|" . 
			$plugin->{PLUGINDB_VERSION} . "|" . 
			$plugin->{PLUGINDB_NAME} . "|" . 
			$plugin->{PLUGINDB_FOLDER} . "|" . 
			$plugin->{PLUGINDB_TITLE} . "|" . 
			$plugin->{PLUGINDB_INTERFACE} . "|" . 
			$plugin->{PLUGINDB_AUTOUPDATE} . "|" . 
			$plugin->{PLUGINDB_RELEASECFG} . "|" . 
			$plugin->{PLUGINDB_PRERELEASECFG} . "|" . 
			$plugin->{PLUGINDB_LOGLEVEL} . "\n";
		push(@plugin_new, $pluginline);
	}
	
	if ($dbchanged) {
		open(my $fh, '>', "$lbsdatadir/plugindatabase.dat");
		flock($fh,2);
		print $fh @plugin_new;
		flock($fh,8);
		close($fh);
		#print STDERR "plugindatabase VALUES CHANGED.\n";
		
	} else {
		#print STDERR "plugindatabase nothing changed.\n";
	}
}

###################################################################
# Delete notify
###################################################################
sub notifydelete
{
	require LoxBerry::Log;
	
	my $key = $R::value;
	$key =~ s/[\/\\]//g;
	
	LoxBerry::Log::delete_notification_key($key);
	
}

###################################################################
# test environment variables
###################################################################
sub testenvironment
{
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
		print $cgi->header(-type => 'text/html;charset=utf-8',
							-status => "500 Invalid request",
		);
		exit;
	}
	if (! -e "/tmp/$R::value") {
		print $cgi->header(-type => 'text/html;charset=utf-8',
							-status => "404 File not found",
		);
		exit;
	}
	open (my $fh, "<", "/tmp/$R::value");
	my $status = <$fh>;
	close ($fh);
	chomp $status;
	print $cgi->header;
	print $status;
	exit;
}