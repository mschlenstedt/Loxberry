#!/usr/bin/perl

use LoxBerry::System;
use LoxBerry::JSON;
use LoxBerry::System::PluginDB;

# $LoxBerry::JSON::DEBUG = 1;

if(!$lbsdatadir) {
	die("Could not read LoxBerry variables");
}

# Create new database file
unlink $dbfile;

# Read old database with old code
my @plugins = get_plugins_V1(undef, 1);

## Transform data
foreach $oldplugin ( @plugins ) {
	print "Migrating plugin $oldplugin->{PLUGINDB_MD5_CHECKSUM} $oldplugin->{PLUGINDB_NAME} $oldplugin->{PLUGINDB_TITLE}\n";
	
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
		print "Created database entry for $plugin->{title}\n";
		$plugin->save;
	} else {
		print "ERROR: Could not create entry for $oldplugin->{PLUGINDB_TITLE}\n";
	}
}


# This is the code to read the old plugindatabase.dat
sub get_plugins_V1
{
	
	my ($withcomments, $forcereload, $plugindb_file) = @_;
	
	# When the plugindb has changed, always force a reload of the plugindb
	
	$forcereload = 1;
		
	if (@plugins && !$forcereload && !$plugindb_file && !$plugins_delcache) {
		print STDERR "get_plugins: Returning cached version of plugindatabase\n" if ($DEBUG);
		return @plugins;
	} else {
		print STDERR "get_plugins: Re-reading plugindatabase\n" if ($DEBUG);
	}
	
	if (! $plugindb_file) {
		$plugindb_file = "$lbsdatadir/plugindatabase.dat";
		$plugins_delcache = 0;
	} else {
		$plugins_delcache = 1;
	}
	
	print STDERR "get_plugins: Using file $plugindb_file\n" if ($DEBUG);
	
	if (!-e $plugindb_file) {
		Carp::carp "LoxBerry::System::pluginversion: Could not find $plugindb_file\n";
		return undef;
	}
	my $openerr;
	open(my $fh, "<", $plugindb_file) or ($openerr = 1);
	if ($openerr) {
		Carp::carp "Error opening plugin database $plugindb_file";
		# &error;
		return undef;
		}
	my @data = <$fh>;

	@plugins = ();
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

		## Start Debug fields of Plugin-DB
		# do {
			# my $field_nr = 0;
			# my $dbg_fields = "Plugin-DB Fields: ";
			# foreach (@fields) {
				# $dbg_fields .= "$field_nr: $_ | ";
				# $field_nr++;
			# }
			# print STDERR "$dbg_fields\n";
		# } ;
		## End Debug fields of Plugin-DB
		
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
		# On changes of the plugindatabase format, please change here 
		# and in libs/phplib/loxberry_system.php / function get_plugins
	}
	return @plugins;
}

