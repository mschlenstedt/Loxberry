#!/usr/bin/perl

# Input parameters from loxberryupdate.pl:
# 	release: the final version update is going to (not the version of the script)
#   logfilename: The filename of LoxBerry::Log where the script can append
#   updatedir: The directory where the update resides
#   cron: If 1, the update was triggered automatically by cron

use LoxBerry::Update;

init();

LOGINF "Installing Node.js V12...";

LOGINF "Adding Node.js repository key to LoxBerry keyring...";
my $output = qx { curl -s https://deb.nodesource.com/gpgkey/nodesource.gpg.key | apt-key add - };
my $exitcode  = $? >> 8;
if ($exitcode != 0) {
		LOGERR "Error adding Node.js repo key to LoxBerry - Error $exitcode";
		LOGDEB $output;
	        $errors++;
	} else {
        	LOGOK "Node.js repo key added successfully.";
	}
LOGINF "Adding Yarn repository key to LoxBerry keyring...";
my $output = qx { curl -sL https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add - };
my $exitcode  = $? >> 8;
if ($exitcode != 0) {
		LOGERR "Error adding Yarn repo key to LoxBerry - Error $exitcode";
		LOGDEB $output;
	        $errors++;
	} else {
        	LOGOK "Yarn repo key added successfully.";
	}

LOGINF "Adding Node.js V12.x repository to LoxBerry...";
qx { echo 'deb https://deb.nodesource.com/node_12.x buster main' > /etc/apt/sources.list.d/nodesource.list };
qx { echo 'deb-src https://deb.nodesource.com/node_12.x buster main' >> /etc/apt/sources.list.d/nodesource.list };

if ( ! -e '/etc/apt/sources.list.d/nodesource.list' ) {
	LOGERR "Error adding Node.js repo to LoxBerry - Repo file missing";
        $errors++;
} else {
	LOGOK "Node.js repo added successfully.";
}

unlink("/etc/apt/sources.list.d/yarn.list");
LOGINF "Adding Yarn repository to LoxBerry...";
my $output = qx { echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list };
my $exitcode  = $? >> 8;
if ($exitcode != 0) {
	LOGERR "Error adding Yarn repo to LoxBerry - Error $exitcode";
	LOGDEB $output;
        $errors++;
} else {
	LOGOK "Yarn repo added successfully.";
}

LOGINF "Update apt Database";
apt_update("update");

LOGINF "Installing Node.js and Yarn packages...";
apt_install("nodejs yarn");

LOGINF "Testing Node.js...";
LOGDEB `node $lbshtmlauthdir/testing/nodejs_hello.js`;

## If this script needs a reboot, a reboot.required file will be created or appended
#LOGWARN "Update file $0 requests a reboot of LoxBerry. Please reboot your LoxBerry after the installation has finished.";
#reboot_required("LoxBerry Update requests a reboot.");

apt_update("clean");

LOGOK "Update script $0 finished." if ($errors == 0);
LOGERR "Update script $0 finished with errors." if ($errors != 0);

# End of script
exit($errors);
