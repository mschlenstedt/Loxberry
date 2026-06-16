#!/usr/bin/perl

use strict;
use warnings;
use LoxBerry::Update;

init();

LOGINF "Installing network interfaces write helper permissions...";

my $helper = "$lbhomedir/sbin/network-interfaces-write.pl";
my $sudoers = "$lbhomedir/system/sudoers/lbdefaults";
my $needle = 'loxberry ALL = NOPASSWD: /opt/loxberry/sbin/network-interfaces-write.pl';

if (! -e $helper) {
	LOGERR "Missing helper: $helper";
	$errors++;
} else {
	system("chown root:root '$helper' >>'$logfilename' 2>&1");
	if (($? >> 8) != 0) {
		LOGERR "Could not set owner root:root on $helper";
		$errors++;
	}

	system("chmod 0755 '$helper' >>'$logfilename' 2>&1");
	if (($? >> 8) != 0) {
		LOGERR "Could not set mode 0755 on $helper";
		$errors++;
	} else {
		LOGOK "Helper permissions set successfully.";
	}
}

LOGINF "Checking sudoers lbdefaults entry...";

if (! -e $sudoers) {
	LOGERR "Missing sudoers template: $sudoers";
	$errors++;
} else {
	local $/;
	open(my $fh, '<', $sudoers) or do {
		LOGERR "Could not read $sudoers: $!";
		$errors++;
	};

	if (!$errors) {
		my $content = <$fh>;
		close($fh);

		if ($content !~ /^\Q$needle\E$/m) {
			LOGINF "Adding sudoers entry for network interfaces writer.";

			$content =~ s/\s*\z/\n/;
			$content .= "$needle\n";

			open(my $out, '>', $sudoers) or do {
				LOGERR "Could not write $sudoers: $!";
				$errors++;
			};

			if (!$errors) {
				print $out $content;
				close($out);
			}
		} else {
			LOGOK "Sudoers entry already exists.";
		}
	}

	if (!$errors) {
		system("chown root:root '$sudoers' >>'$logfilename' 2>&1");
		system("chmod 0440 '$sudoers' >>'$logfilename' 2>&1");

		system("visudo -cf '$sudoers' >>'$logfilename' 2>&1");
		if (($? >> 8) != 0) {
			LOGERR "Sudoers syntax check failed for $sudoers";
			$errors++;
		} else {
			LOGOK "Sudoers syntax check successful.";
			copy_to_loxberry('/system/sudoers/lbdefaults');
		}
	}
}

if ($errors) {
	LOGERR "Update script $0 finished with errors.";
	exit(251);
} else {
	LOGOK "Update script $0 finished successfully.";
	exit(250);
}