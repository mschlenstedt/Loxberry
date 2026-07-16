#!/usr/bin/perl

# Input parameters from loxberryupdate.pl:
# 	release: the final version update is going to (not the version of the script)
#   logfilename: The filename of LoxBerry::Log where the script can append
#   updatedir: The directory where the update resides
#   cron: If 1, the update was triggered automatically by cron

use LoxBerry::Update;
use LoxBerry::System;

init();

# ---------------------------------------------------------------------------
# Make the new Python libraries (libs/pythonlib) importable system-wide.
#
# libs/ is rsync'd normally, so libs/pythonlib/install_pth.py is already in
# place here. install_pth.py writes a loxberry.pth into the dist-packages of
# the running python3, so any Python program can do "from loxberry import
# system". The .pth lives OUTSIDE the rsync tree and is per-python-version,
# which is exactly why it must be (re)written by this versioned update script
# (also after a distro upgrade that ships a new python3).
# ---------------------------------------------------------------------------

my $pylib = "$lbhomedir/libs/pythonlib";

if ( -e "$pylib/install_pth.py" ) {
	LOGINF "Installing loxberry.pth for the system python3...";
	execute(
		command => "python3 $pylib/install_pth.py --libdir $pylib",
		log     => $log,
	);
} else {
	LOGWARN "$pylib/install_pth.py not found - skipping Python .pth install.";
}

LOGOK "Update script $0 finished." if ( $errors == 0 );
LOGERR "Update script $0 finished with errors." if ( $errors != 0 );

exit($errors);
