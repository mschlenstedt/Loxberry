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
# Upgrade Raspbian on next reboot
#
LOGWARN "Upgrading system to latest release ON NEXT REBOOT.";
my $logfilename_wo_ext = $logfilename;
$logfilename_wo_ext =~ s{\.[^.]+$}{};
open(F,">$lbhomedir/system/daemons/system/99-updaterebootv220");
print F <<EOF;
#!/bin/bash
perl $lbhomedir/sbin/loxberryupdate/updatereboot_v2.2.0.pl logfilename=$logfilename_wo_ext-reboot 2>&1
EOF
close (F);
qx { chmod +x $lbhomedir/system/daemons/system/99-updaterebootv220 };

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
