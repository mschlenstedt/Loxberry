#!/usr/bin/perl
use strict;
use warnings;
use CGI::Carp qw(fatalsToBrowser);
use CGI qw/:standard/;
use Scalar::Util qw(looks_like_number);
# use Switch;
# use AptPkg::Config;
use LoxBerry::System;

my $bins = LoxBerry::System::get_binaries();
# print STDERR "Das Binary zu Grep ist $bins->{GREP}.";
# system("$bins->{ZIP} myarchive.zip *");

print header;

my $action = param('action');
my $value = param('value');

print STDERR "Action: $action // Value: $value\n";

if    ($action eq 'secupdates') { &secupdates; }
elsif ($action eq 'secupdates-autoreboot') { &secupdatesautoreboot; }
elsif ($action eq 'poweroff') { &poweroff; }
elsif ($action eq 'reboot') { &reboot; }
elsif ($action eq 'lbupdate-reltype') { &lbupdate; }
elsif ($action eq 'lbupdate-installtype') { &lbupdate; }
elsif ($action eq 'lbupdate-installtime') { &lbupdate; }
elsif ($action eq 'lbupdate-runcheck') { &lbupdate; }
elsif ($action eq 'lbupdate-runinstall') { &lbupdate; }

else   { print "<red>Action not supported.</red>"; }

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
		print FILE @newlines;
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
					$queryresult =~ s/[\$"#@~!&*()\[\];.,:?^ `\\\/]+//g;
					print "secupdates-autoreboot-" . $queryresult;
				} else {
					$_ = $value eq "false" ? "Unattended-Upgrade::Automatic-Reboot-WithUsers \"false\";\n" : "Unattended-Upgrade::Automatic-Reboot-WithUsers \"true\";\n";}
			}
		push(@newlines,$_);
	}

	if ($value ne 'query') {
		open(FILE, '>', $aptfile) || die "File not found";
		print FILE @newlines;
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
		system("sudo $lbhomedir/sbin/loxberryupdatecheck.pl output=json");
	}
	
	if ($action eq 'lbupdate-runinstall') {
		exec("sudo $lbhomedir/sbin/loxberryupdatecheck.pl output=json update=1 dryrun=1");
		exit(1);
	}
	
	
	if ($action eq 'lbupdate-reltype') {
		if ($value eq 'release' || $value eq 'prerelease' || $value eq 'latest') { 
			change_generalcfg('UPDATE.RELEASETYPE', $value);
		}
	return;
	}

	if ($action eq 'lbupdate-installtype') {
		if ($value eq 'disabled' || $value eq 'notify' || $value eq 'install') { 
			change_generalcfg('UPDATE.INSTALLTYPE', $value);
		}
	return;
	}

	if ($action eq 'lbupdate-installtime') {
		if ($value eq '1' || $value eq '7' || $value eq '30') { 
			unlink "$lbhomedir/system/cron/cron.daily/lbupdate" if (-e "$lbhomedir/system/cron/cron.daily/lbupdate");
			unlink "$lbhomedir/system/cron/cron.weekly/lbupdate" if (-e "$lbhomedir/system/cron/cron.weekly/lbupdate");
			unlink "$lbhomedir/system/cron/cron.monthly/lbupdate" if (-e "$lbhomedir/system/cron/cron.monthly/lbupdate");
			
			if ($value eq '1') {
				symlink "$lbshtmlauthdir/tools/lbupdate.sh", "$lbhomedir/system/cron/cron.daily/lbupdate.sh" or print STDERR "Error linking $lbhomedir/system/cron/cron.daily/lbupdate.sh";
			} elsif ($value eq '7') {
				symlink "$lbshtmlauthdir/tools/lbupdate.sh", "$lbhomedir/system/cron/cron.weekly/lbupdate.sh" or print STDERR "Error linking $lbhomedir/system/cron/cron.weekly/lbupdate.sh";;
			} elsif ($value eq '30') {
				symlink "$lbshtmlauthdir/tools/lbupdate.sh", "$lbhomedir/system/cron/cron.monthly/lbupdate.sh" or print STDERR "Error linking $lbhomedir/system/cron/cron.monthly/lbupdate.sh";;
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
	print STDERR "ajax-config-handler: ajax poweroff\n";
	system("sudo $bins->{POWEROFF}");
}

############################################
# reboot
############################################
sub reboot
{
	print STDERR "ajax-config-handler: ajax reboot\n";
	system("sudo $bins->{REBOOT}");
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
