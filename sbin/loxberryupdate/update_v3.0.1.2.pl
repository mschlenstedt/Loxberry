#!/usr/bin/perl

# Input parameters from loxberryupdate.pl:
# 	release: the final version update is going to (not the version of the script)
#   logfilename: The filename of LoxBerry::Log where the script can append
#   updatedir: The directory where the update resides
#   cron: If 1, the update was triggered automatically by cron

use LoxBerry::Update;
use LoxBerry::JSON;
use LoxBerry::System;

init();

my ($exitcode, $debver)=execute("cat /etc/os-release | grep VERSION_ID= | cut -d '=' -f 2 | cut -d '\"' -f 2");
chomp($debver)
if ($debver -eq "12") {
	LOGINF "COnfigure PHP and install missing php püackages...";
	($exitcode)=execute("curl -sL https://packages.sury.org/php/apt.gpg | gpg --dearmor | tee /usr/share/keyrings/deb.sury.org-php.gpg >/dev/null");
	($exitcode)=execute("echo \"deb [signed-by=/usr/share/keyrings/deb.sury.org-php.gpg] https://packages.sury.org/php/ $(lsb_release -sc) main\" > /etc/apt/sources.list.d/php.list");
	apt_install("php7.4-bz2 php7.4-cgi  php7.4-cli php7.4-curl php7.4-json php7.4-mbstring php7.4-mysql php7.4-opcache php7.4-readline php7.4-soap php7.4-sqlite3 php7.4-xml php7.4-zip php8.2-bz2 php8.2-cgi php8.2-cli php8.2-curl php8.2-mbstring php8.2-mysql php8.2-opcache php8.2-readline php8.2-soap php8.2-sqlite3 php8.2-xml php8.2-zip ");
}

LOGOK "Done.";

## If this script needs a reboot, a reboot.required file will be created or appended
# LOGWARN "Update file $0 requests a reboot of LoxBerry. Please reboot your LoxBerry after the installation has finished.";
# reboot_required("LoxBerry Update requests a reboot.");

LOGOK "Update script $0 finished." if ($errors == 0);
LOGERR "Update script $0 finished with errors." if ($errors != 0);

# End Skript for reboot
# Just to remeber for the next Major update: Exit this script with 250 or 250 will popup a "reboot.force" messages,
# because update process will continue after reboot the loxberry

exit($errors);
