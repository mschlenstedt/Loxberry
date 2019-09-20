#!/usr/bin/perl

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
print "<INFO> Deleting existing (new) plugindatabase.json\n";
unlink $LoxBerry::System::PLUGINDATABASE;

# Read old database with old code
my @plugins = get_plugins_V1();

my $plugin_count_old = scalar @plugins;

## Transform data
foreach $oldplugin ( @plugins ) {
	print "<INFO> Migrating plugin $oldplugin->{PLUGINDB_MD5_CHECKSUM} $oldplugin->{PLUGINDB_NAME} $oldplugin->{PLUGINDB_TITLE}\n";
	
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
			print "<WARN> Newly calculated pluginid does not match old pluginid\n";
		} else {
			print "<OK> Created database entry for $plugin->{title}\n";
		}
		$plugin->save;
	} else {
		print "<ERROR> Could not create entry for $oldplugin->{PLUGINDB_TITLE}\n";
	}
}

print "<INFO> Checking new database file...\n";
eval {
    $data = JSON::from_json( LoxBerry::System::read_file( $LoxBerry::System::PLUGINDATABASE ) );
};
if($data and $data->{plugins}) {
	$plugin_count_new = scalar keys %{$data->{plugins}};
} else {
	$plugin_count_new = 0;
}

print "<INFO> Creating backup and shadow copy of plugindatabase\n";
`cp -f $Loxberry::System::PLUGINDATABASE $Loxberry::System::PLUGINDATABASE-`;
`cp -f $Loxberry::System::PLUGINDATABASE $Loxberry::System::PLUGINDATABASE.bkp`;
`chmod 644 $Loxberry::System::PLUGINDATABASE-`;
`chown root:root $Loxberry::System::PLUGINDATABASE-`;

print "<INFO> Number of plugins BEFORE: " . $plugin_count_old . "\n";
print "<INFO> Number of plugins AFTER : " . $plugin_count_new . "\n";

if( $plugin_count_old ne $plugin_count_new ) {
	print "<ERROR> Plugin count is not equal. Check the list above. Before trying any plugin installations, contact the LoxBerry-Core team via https://loxforum.com or https://github.com/mschlenstedt/Loxberry/issues\n";
	exit(1);
} else {
	print "<OK> Plugindatabase migration finished successfully.\n";
}
exit(0);


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

