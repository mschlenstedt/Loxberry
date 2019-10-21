#!/usr/bin/perl

# Input parameters from loxberryupdate.pl:
# 	release: the final version update is going to (not the version of the script)
#   logfilename: The filename of LoxBerry::Log where the script can append
#   updatedir: The directory where the update resides
#   cron: If 1, the update was triggered automatically by cron

use LoxBerry::Update;
use LoxBerry::JSON;

init();

#
# Switching to rwth-aachen.de for the Rasbian Repo due to lot of connection errors with original rpo
#
LOGINF "Replacing archive.raspbian.org with ftp.halifax.rwth-aachen.de/raspbian in /etc/apt/sources.list.";
system ("/bin/sed -i 's:mirrordirector.raspbian.org:ftp.halifax.rwth-aachen.de/raspbian:g' /etc/apt/sources.list");
system ("/bin/sed -i 's:archive.raspbian.org:ftp.halifax.rwth-aachen.de/raspbian:g' /etc/apt/sources.list");
unlink ("/etc/apt/sources.list.d/raspi.list");

LOGINF "Getting signature for ftp.halifax.rwth-aachen.de/raspbian/raspbian.";
$output = qx ( wget http://ftp.halifax.rwth-aachen.de/raspbian/raspbian.public.key -O - | apt-key add - );
$exitcode  = $? >> 8;
if ($exitcode != 0) {
	LOGERR "Error getting signature for ftp.halifax.rwth-aachen.de/raspbian - Error $exitcode";
	LOGDEB $output;
	$errors++;
} else {
     	LOGOK "Got signature for ftp.halifax.rwth-aachen.de/raspbian successfully.";
}

#
# Installing new network templates
#
LOGINF "Installing new network templates for IPv6...";
unlink "$lbhomedir/system/network/interfaces.ipv4";
unlink "$lbhomedir/system/network/interfaces.ipv6";
unlink "$lbhomedir/system/network/interfaces.loopback";
unlink "$lbhomedir/system/network/interfaces.v6auto";
unlink "$lbhomedir/system/network/interfaces.v6dhcp";
unlink "$lbhomedir/system/network/interfaces.v6static";
unlink "$lbhomedir/system/network/interfaces.eth_dhcp";
unlink "$lbhomedir/system/network/interfaces.eth_static";
unlink "$lbhomedir/system/network/interfaces.wlan_dhcp";
unlink "$lbhomedir/system/network/interfaces.wlan_static";

LOGINF "Installing additional Perl modules...";
apt_update("update");
apt_install("libdata-validate-ip-perl");

#
# Upgrade Raspbian on next reboot
#
LOGWARN "Upgrading system to latest Raspbian release ON NEXT REBOOT.";
my $logfilename_wo_ext = $logfilename;
$logfilename_wo_ext =~ s{\.[^.]+$}{};
open(F,">$lbhomedir/system/daemons/system/99-updaterebootv200");
print F <<EOF;
#!/bin/bash
perl $lbhomedir/sbin/loxberryupdate/updatereboot_v2.0.0.pl logfilename=$logfilename_wo_ext-reboot 2>&1
EOF
close (F);
qx { chmod +x $lbhomedir/system/daemons/system/99-updaterebootv200 };

#
# Disable Apache2 for next reboot
#
LOGINF "Disabling Apache2 Service for next reboot...";
my $output = qx { systemctl disable apache2.service };
$exitcode = $? >> 8;
if ($exitcode != 0) {
	LOGWARN "Could not disable Apache webserver - Error $exitcode";
	LOGWARN "Maybe your LoxBerry does not respond during system upgrade after reboot. Please be patient when rebooting!";
} else {
	LOGOK "Apache Service disabled successfully.";
}

#
# Backing up Python packages, because rasbian's upgrade will overwrite all of them...
#
LOGINF "Backing up all Python Modules - Will be overwritten by f***cking broken Rasbian upgrade...";
system ("which pip");
$exitcode  = $? >> 8;
if ($exitcode != 0) {
	LOGINF "pip seems not to be installed.";
} else {
	LOGINF "Saving list with installed pip packages...";
	system ("pip install pip --upgrade");
	system("pip list --format=freeze > $lbsdatadir/pip_list.dat");
}
system ("which pip3");
$exitcode  = $? >> 8;
if ($exitcode != 0) {
	LOGINF "pip3 seems not to be installed.";
} else {
	LOGINF "Saving list with installed pip3 packages...";
	system ("pip3 install pip --upgrade");
	system("pip3 list --format=freeze > $lbsdatadir/pip3_list.dat");
}

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
LOGDEB `node -e "console.log('Hello LoxBerry users, this is Node.js '+process.version);"`;

LOGINF "Installing additional Perl modules...";
apt_install("libdata-validate-ip-perl");

LOGINF "Removing obsolete ssmtp package...";
apt_remove("ssmtp bsd-mailx");

LOGINF "Installing msmtp package and replacing ssmtp...";
copy_to_loxberry("/system/msmtp", "loxberry");
apt_install("msmtp msmtp-mta bsd-mailx");

#
# Migrating ssmtp config to msmtp
#
if (-e "$lbhomedir/system/ssmtp/ssmtp.conf" ) {

	my $mailfile = $lbsconfigdir . "/mail.json";
	my $msmtprcfile = $lbhomedir . "/system/msmtp/msmtprc";
	
	$mailobj = LoxBerry::JSON->new();
	$mcfg = $mailobj->open(filename => $mailfile);
	
	if ( is_enabled ($mcfg->{SMTP}->{ACTIVATE_MAIL}) ) {
		LOGINF "Migrating ssmtp configuration to msmtp...";
		my $error;
		# Config
		open(F,">$msmtprcfile") || $error++;
		flock(F,2);
		print F "aliases $lbhomedir/system/msmtp/aliases\n";
		print F "logfile $lbhomedir/log/system_tmpfs/mail.log\n";
		print F "from $mcfg->{SMTP}->{EMAIL}\n";
		print F "host $mcfg->{SMTP}->{SMTPSERVER}\n";
		print F "port $mcfg->{SMTP}->{PORT}\n";
		if ( is_enabled($mcfg->{SMTP}->{AUTH}) ) {
			print F "auth on\n";
			print F "user $mcfg->{SMTP}->{SMTPUSER}\n";
			print F "password $mcfg->{SMTP}->{SMTPPASS}\n";
		} else {
			print F "auth off\n";
		}
		if ( is_enabled($mcfg->{SMTP}->{CRYPT}) ) {
			print F "tls on\n";
			print F "tls_trust_file /etc/ssl/certs/ca-certificates.crt\n"
		} else {
			print F "tls off\n";
		}
		flock(F,8);
		close(F);
		$output = qx { chmod 0600 $msmtprcfile 2>&1 };
		$exitcode  = $? >> 8;
		if ($exitcode != 0) {
		        LOGERR "Error setting 0600 file permissions for $msmtprcfile - Error $exitcode";
			$error++;
		} else {
			LOGOK "Changing file permissions successfully for $msmtprcfile";
		}
		$output = qx { chown loxberry:loxberry $msmtprcfile 2>&1 };
		$exitcode  = $? >> 8;
		if ($exitcode != 0) {
		        LOGERR "Error changing owner to loxberry for $msmtprcfile - Error $exitcode";
			$error++;
		} else {
			LOGOK "Changing owner to loxberry successfully for $msmtprcfile";
		}
		# Aliases
		open(F,">$lbhomedir/system/msmtp/aliases");
		flock(F,2);
		print F "root: $mcfg->{SMTP}->{EMAIL}\n";
		print F "loxberry: $mcfg->{SMTP}->{EMAIL}\n";
		print F "default: $mcfg->{SMTP}->{EMAIL}\n";
		flock(F,8);
		close(F);
		$output = qx { chmod 0600 $lbhomedir/system/msmtp/aliases 2>&1 };
		$exitcode  = $? >> 8;
		if ($exitcode != 0) {
		        LOGERR "Error setting 0600 file permissions for $lbhomedir/system/msmtp/aliases - Error $exitcode";
			$error++;
		} else {
			LOGOK "Changing file permissions successfully for $lbhomedir/system/msmtp/aliases";
		}
		$output = qx { chown loxberry:loxberry $lbhomedir/system/msmtp/aliases 2>&1 };
		$exitcode  = $? >> 8;
		if ($exitcode != 0) {
		        LOGERR "Error changing owner to loxberry for $lbhomedir/system/msmtp/aliases - Error $exitcode";
			$error++;
		} else {
			LOGOK "Changing owner to loxberry successfully for $lbhomedir/system/msmtp/aliases";
		}
		if ($error) {
			LOGWARN "Could not migrate config file from ssmtp to msmtp. Please configure the Mailserver Widget manually!";
			unlink "$lbhomedir/system/msmtp/aliases";
			unlink "$msmtprcfile";
		} else {
			LOGOK "Created new msmtp config successfully.";
			my $email = $mcfg->{SMTP}->{EMAIL};
			LOGINF "Cleaning mail.json due to previously saved credentials in that config file";
			delete $mcfg->{SMTP};
			$mcfg->{SMTP}->{ACTIVATE_MAIL} = "1";
			$mcfg->{SMTP}->{ISCONFIGURED} = "1";
			$mcfg->{SMTP}->{EMAIL} = "$email";
			$mailobj->write();
			LOGINF "Activating new msmtp configuration...";
			system( "ln -s $lbhomedir/system/msmtp/msmtprc /etc/msmtprc" );
			#system( "ln -s $lbhomedir/system/msmtp/msmtprc $lbhomedir/.msmtprc" );
			#system( "chown -h loxberry:loxberry $lbhomedir/.msmtprc" );
		}

	}

}	

LOGINF "Removing old ssmtp configuration...";
delete_directory ("$lbhomedir/system/ssmtp");

LOGINF "Replacing auto.smb with LoxBerry's modified auto.smb ...";
copy_to_loxberry("/system/autofs", "root");
if ( ! -l '/etc/auto.smb' ) {
	# Not a symlink
	execute ( command => 'mv -f /etc/auto.smb /etc/auto.smb.backup', log => $log );
}

if ( ! -e "$lbhomedir/system/autofs" ) {
	mkdir "$lbhomedir/system/autofs" or do { LOGERR "Could not create dir $lbhomedir/system/autofs"; $errors++; };
}
unlink "/etc/auto.smb";
symlink "$lbhomedir/system/autofs/auto.smb", "/etc/auto.smb" or do { LOGERR "Could not create symlink from /etc/auto.smb to $lbhomedir/system/autofs/auto.smb"; $errors++; };
execute ( command => "chmod 0755 $lbhomedir/system/autofs/auto.smb", log => $log );
execute ( command => "systemctl restart autofs", log => $log );

LOGINF "Updating PHP 7.x configuration";
LOGINF "Deleting ~/system/php...";
delete_directory("$lbhomedir/system/php");
LOGINF "Re-creating directory ~/system/php...";
mkdir "$lbhomedir/system/php" or do { LOGERR "Could not create dir $lbhomedir/system/php"; $errors++; };
LOGINF "Copying LoxBerry PHP config...";
copy_to_loxberry("/system/php/loxberry-apache.ini");
copy_to_loxberry("/system/php/loxberry-cli.ini");

LOGINF "Deleting old LoxBerry PHP config...";
my @phpfiles = ( 
	'/etc/php/7.0/apache2/conf.d/20-loxberry.ini', 
	'/etc/php/7.0/cgi/conf.d/20-loxberry.ini', 
	'/etc/php/7.0/cli/conf.d/20-loxberry.ini', 
	'/etc/php/7.1/apache2/conf.d/20-loxberry.ini', 
	'/etc/php/7.1/cgi/conf.d/20-loxberry.ini', 
	'/etc/php/7.1/cli/conf.d/20-loxberry.ini', 
	'/etc/php/7.2/apache2/conf.d/20-loxberry.ini', 
	'/etc/php/7.2/cgi/conf.d/20-loxberry.ini', 
	'/etc/php/7.2/cli/conf.d/20-loxberry.ini', 
	'/etc/php/7.3/apache2/conf.d/20-loxberry.ini', 
	'/etc/php/7.3/cgi/conf.d/20-loxberry.ini', 
	'/etc/php/7.3/cli/conf.d/20-loxberry.ini', 
);
foreach (@phpfiles) {
	if (-e "$_") { 
		unlink "$_" or do { LOGERR "Could not delete $_"; $errors++; }; 
	}
}

LOGINF "Creating symlinks to new configuration....";

if ( -e "/etc/php/7.0" ) {
	my $output = qx { ln -vsfn $lbhomedir/system/php/loxberry-apache.ini /etc/php/7.0/apache2/conf.d/20-loxberry-apache.ini >> $logfilename 2>&1 };
	my $output = qx { ln -vsfn $lbhomedir/system/php/loxberry-apache.ini /etc/php/7.0/cgi/conf.d/20-loxberry-apache.ini >> $logfilename 2>&1};
	my $output = qx { ln -vsfn $lbhomedir/system/php/loxberry-cli.ini /etc/php/7.0/cli/conf.d/20-loxberry-cli.ini >> $logfilename 2>&1};
};
if ( -e "/etc/php/7.1" ) {
	my $output = qx { ln -vsfn $lbhomedir/system/php/loxberry-apache.ini /etc/php/7.1/apache2/conf.d/20-loxberry-apache.ini >> $logfilename 2>&1};
	my $output = qx { ln -vsfn $lbhomedir/system/php/loxberry-apache.ini /etc/php/7.1/cgi/conf.d/20-loxberry-apache.ini >> $logfilename 2>&1};
	my $output = qx { ln -vsfn $lbhomedir/system/php/loxberry-cli.ini /etc/php/7.1/cli/conf.d/20-loxberry-cli.ini >> $logfilename 2>&1};
};
if ( -e "/etc/php/7.2" ) {
	my $output = qx { ln -vsfn $lbhomedir/system/php/loxberry-apache.ini /etc/php/7.2/apache2/conf.d/20-loxberry-apache.ini >> $logfilename 2>&1 };
	my $output = qx { ln -vsfn $lbhomedir/system/php/loxberry-apache.ini /etc/php/7.2/cgi/conf.d/20-loxberry-apache.ini >> $logfilename 2>&1 };
	my $output = qx { ln -vsfn $lbhomedir/system/php/loxberry-cli.ini /etc/php/7.2/cli/conf.d/20-loxberry-cli.ini >> $logfilename 2>&1 };
};
if ( -e "/etc/php/7.3" ) {
	my $output = qx { ln -vsfn $lbhomedir/system/php/loxberry-apache.ini /etc/php/7.3/apache2/conf.d/20-loxberry-apache.ini >> $logfilename 2>&1 };
	my $output = qx { ln -vsfn $lbhomedir/system/php/loxberry-apache.ini /etc/php/7.3/cgi/conf.d/20-loxberry-apache.ini >> $logfilename 2>&1 };
	my $output = qx { ln -vsfn $lbhomedir/system/php/loxberry-cli.ini /etc/php/7.3/cli/conf.d/20-loxberry-cli.ini >> $logfilename 2>&1 };
};

LOGOK "PHP logging settings changed.";

LOGINF "Installing daily cronjob for plugin update checks...";
$output = qx { rm -f $lbhomedir/system/cron/cron.daily/02-pluginsupdate.pl };
$output = qx { ln -f -s $lbhomedir/sbin/pluginsupdate.pl $lbhomedir/system/cron/cron.daily/02-pluginsupdate };

# Copy new ~/system/systemd to installation
#if (!-e "$lbhomedir/system/systemd") {
	LOGINF "Install ~/system/systemd to your Loxberry...";
	&copy_to_loxberry('/system/systemd');
#} else {
#	LOGINF "~/system/systemd seems to exist already. Skipping...";
#}

# Link usb-mount@.service
if ( -e "/etc/systemd/system/usb-mount@.service" ) {
	LOGINF "Remove /etc/systemd/system/usb-mount@.service...";
	unlink ("/etc/systemd/system/usb-mount@.service");
}
LOGINF "Install usb-mount@.service...";
system( "ln -s $lbhomedir/system/systemd/usb-mount@.service /etc/systemd/system/usb-mount@.service" );

LOGINF "Updating NTFS driver to ntfs-3g...";
apt_install("ntfs-3g");

LOGINF "Re-Install ssdpd service...";
if ( -e "/etc/systemd/system/ssdpd.service" ) {
	unlink ("/etc/systemd/system/ssdpd.service");
}
unlink ("$lbhomedir/data/system/ssdpd.service");
system ("ln -s $lbhomedir/system/systemd/ssdpd.service /etc/systemd/system/ssdpd.service");
system ("/bin/systemctl daemon-reload");

# Link loxberry.service
if ( -e "/etc/init.d/loxberry" ) {
	LOGINF "Remove old loxberry init script...";
	unlink ("/etc/init.d/loxberry");
}
if ( -e "/etc/systemd/system/loxberry.service" ) {
	LOGINF "Remove /etc/systemd/system/loxberry.service...";
	unlink ("/etc/systemd/system/loxberry.service");
}
LOGINF "Install loxberry.service...";
system( "ln -s $lbhomedir/system/systemd/loxberry.service /etc/systemd/system/loxberry.service" );

# Link createtmpfs.service
if ( -e "/etc/init.d/createtmpfsfoldersinit" ) {
	LOGINF "Remove old createtmpfs init script...";
	unlink ("/etc/init.d/createtmpfsfoldersinit");
}
if ( -e "/etc/systemd/system/createtmpfs.service" ) {
	LOGINF "Remove /etc/systemd/system/createtmpfs.service...";
	unlink ("/etc/systemd/system/createtmpfs.service");
}
LOGINF "Install createtmpfs.service...";
system( "ln -s $lbhomedir/system/systemd/createtmpfs.service /etc/systemd/system/createtmpfs.service" );

LOGINF "Disable already deinstalled dhcpcd.service...";
system( "systemctl disable dhcpcd" );

system ("/bin/systemctl daemon-reload");
system ("/bin/systemctl enable loxberry.service");
system ("/bin/systemctl enable createtmpfs.service");

if( -e $LoxBerry::System::PLUGINDATABASE ) {
	LOGWARN "Plugin database is already migrated. Skipping.";
} else {
	# # Migrate plugindatabase.dat to plugindatabase.json
	# my ($exitcode, $output) = LoxBerry::System::execute( 
		# log => $log,
		# intro => "Migrating plugindatabase to json file format",
		# command => "perl $lbhomedir/sbin/loxberryupdate/migrate_plugindb_v2.pl",
		# ok => "Plugin database migrated successfully.",
		# error => "Migration returned an error."
	# );

	eval {
		migration_plugindb();
	};
	if($@) {
		$errors++;
		LOGCRIT "Migration of plugindatabase failed: $@";
		LOGWARN "Because of errors, the old files of plugindatabase are kept for further investigation.";
	} else {
		LOGINF "The old plugin database is kept for any issues as plugindatabase.dat";
		unlink "$lbsdatadir/plugindatabase.dat-";
		unlink "$lbsdatadir/plugindatabase.bkp";
	}
}

LOGINF "Installing new system crontab...";
mkdir "$lbhomedir/system/cron/cron.reboot";
`chown loxberry:loxberry $lbhomedir/system/cron/cron.reboot`;
&copy_to_loxberry('/system/cron/cron.d/lbdefaults');

# Clean apt
apt_update("clean");

## If this script needs a reboot, a reboot.required file will be created or appended
LOGWARN "Update file $0 requests a reboot of LoxBerry. Please reboot your LoxBerry after the installation has finished.";
reboot_required("LoxBerry Update requests a reboot.");

LOGOK "Update script $0 finished." if ($errors == 0);
LOGERR "Update script $0 finished with errors." if ($errors != 0);

# End Skript for reboot
if ($errors) {
	exit(251); 
} else {
	exit(250);
}


####################################################
# Plugindatabase migration
####################################################

sub migration_plugindb 
{

	LOGINF "Migrating plugin database to LoxBerry 2.x format...";

	use LoxBerry::System;
	use LoxBerry::JSON;
	use LoxBerry::System::PluginDB;

	# $LoxBerry::JSON::DEBUG = 1;

	if(!$lbsdatadir) {
		die("Could not read LoxBerry variables");
	}

	my $plugin_count_old = 0;
	my $plugin_count_new = 0;

	# Create new database file
	LOGINF "Deleting existing (new) plugindatabase.json";
	unlink $LoxBerry::System::PLUGINDATABASE;

	# Read old database with old code
	my @plugins = get_plugins_V1();

	my $plugin_count_old = scalar @plugins;

	## Transform data
	foreach $oldplugin ( @plugins ) {
		LOGINF "Migrating plugin $oldplugin->{PLUGINDB_MD5_CHECKSUM} $oldplugin->{PLUGINDB_NAME} $oldplugin->{PLUGINDB_TITLE}";
		
		my $plugin = LoxBerry::System::PluginDB->plugin(
			author_name => $oldplugin->{PLUGINDB_AUTHOR_NAME},
			author_email => $oldplugin->{PLUGINDB_AUTHOR_EMAIL},
			version => $oldplugin->{PLUGINDB_VERSION},
			name => $oldplugin->{PLUGINDB_NAME},
			folder => $oldplugin->{PLUGINDB_FOLDER},
			title => $oldplugin->{PLUGINDB_TITLE},
			interface => $oldplugin->{PLUGINDB_INTERFACE},
			autoupdate => $oldplugin->{PLUGINDB_AUTOUPDATE},
			releasecfg => $oldplugin->{PLUGINDB_RELEASECFG},
			prereleasecfg => $oldplugin->{PLUGINDB_PRERELEASECFG},
			loglevel => $oldplugin->{PLUGINDB_LOGLEVEL},
			loglevels_enabled => $oldplugin->{PLUGINDB_LOGLEVELS_ENABLED},
		);
		
		if($plugin) {
			if( $plugin->{md5} ne $oldplugin->{PLUGINDB_MD5_CHECKSUM} ) {
				LOGWARN "  Newly calculated pluginid does not match old pluginid";
			} else {
				LOGOK "  Created database entry for $plugin->{title}";
			}
			$plugin->save;
		} else {
			LOGERR "  Could not create entry for $oldplugin->{PLUGINDB_TITLE}";
		}
	}

	LOGINF "Checking new database file...";
	eval {
		$data = JSON::from_json( LoxBerry::System::read_file( $LoxBerry::System::PLUGINDATABASE ) );
	};
	if($data and $data->{plugins}) {
		$plugin_count_new = scalar keys %{$data->{plugins}};
	} else {
		$plugin_count_new = 0;
	}

	LOGINF "Creating backup and shadow copy of plugindatabase";
	`cp -f $Loxberry::System::PLUGINDATABASE $Loxberry::System::PLUGINDATABASE-`;
	`cp -f $Loxberry::System::PLUGINDATABASE $Loxberry::System::PLUGINDATABASE.bkp`;
	`chmod 644 $Loxberry::System::PLUGINDATABASE-`;
	`chown root:root $Loxberry::System::PLUGINDATABASE-`;

	LOGINF "Number of plugins BEFORE: " . $plugin_count_old;
	LOGINF "Number of plugins AFTER : " . $plugin_count_new;

	if( $plugin_count_old ne $plugin_count_new ) {
		LOGERR "Plugin count is not equal. Check the list above. Before trying any plugin installations, contact the LoxBerry-Core team via https://loxforum.com or https://github.com/mschlenstedt/Loxberry/issues";
		die("Plugin count BEFORE and AFTER is not equal");
	} else {
		LOGOK "Plugindatabase migration finished successfully.";
	}

	return(0);
}


# This is the code to read the old plugindatabase.dat
sub get_plugins_V1
{
		
	if (! $plugindb_file) {
		$plugindb_file = "$lbsdatadir/plugindatabase.dat";
	}
	print STDERR "get_plugins: Using file $plugindb_file\n" if ($DEBUG);
	
	if (!-e $plugindb_file) {
		Carp::carp "LoxBerry::System::pluginversion: Could not find $plugindb_file\n";
		return;
	}
	my $openerr;
	open(my $fh, "<", $plugindb_file) or ($openerr = 1);
	if ($openerr) {
		Carp::carp "Error opening plugin database $plugindb_file";
		# &error;
		return;
		}
	my @data = <$fh>;

	my @plugins = ();
	my $plugincount = 0;
	
	foreach (@data){
		s/[\n\r]//g;
		my %plugin;
		# Comments
		if ($_ =~ /^\s*#.*/) {
			if (defined $withcomments) {
				$plugin{PLUGINDB_COMMENT} = $_;
				push(@plugins, \%plugin);
			}
			next;
		}
		
		$plugincount++;
		my @fields = split(/\|/);

		# From Plugin-DB
		
		$plugin{PLUGINDB_NO} = $plugincount;
		$plugin{PLUGINDB_MD5_CHECKSUM} = $fields[0];
		$plugin{PLUGINDB_AUTHOR_NAME} = $fields[1];
		$plugin{PLUGINDB_AUTHOR_EMAIL} = $fields[2];
		$plugin{PLUGINDB_VERSION} = $fields[3];
		$plugin{PLUGINDB_NAME} = $fields[4];
		$plugin{PLUGINDB_FOLDER} = $fields[5];
		$plugin{PLUGINDB_TITLE} = $fields[6];
		$plugin{PLUGINDB_INTERFACE} = $fields[7];
		$plugin{PLUGINDB_AUTOUPDATE} = $fields[8];
		$plugin{PLUGINDB_RELEASECFG} = $fields[9];
		$plugin{PLUGINDB_PRERELEASECFG} = $fields[10];
		$plugin{PLUGINDB_LOGLEVEL} = $fields[11];
		$plugin{PLUGINDB_LOGLEVELS_ENABLED} = $plugin{PLUGINDB_LOGLEVEL} >= 0 ? 1 : 0;
		$plugin{PLUGINDB_ICONURI} = "/system/images/icons/$plugin{PLUGINDB_FOLDER}/icon_64.png";
		push(@plugins, \%plugin);

	}
	return @plugins;
}
