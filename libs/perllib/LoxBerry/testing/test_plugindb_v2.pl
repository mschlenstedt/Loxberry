#!/usr/bin/perl

use LoxBerry::System;
use LoxBerry::JSON;
use LoxBerry::System::PluginDB;

use Data::Dumper;

# $LoxBerry::JSON::DEBUG = 1;

if(!$lbsdatadir) {
	die("Could not read LoxBerry variables");
}

my $dbfile = "$lbsdatadir/plugindatabase.json";
my $dbfile_secured = "$lbsdatadir/plugindatabase.json-";
# # Create new database file
# unlink $dbfile;

# # Read old database with old code
# my @plugins = get_plugins_V1(undef, 1);

# ## Transform data
# foreach $oldplugin ( @plugins ) {
	# print "Migrating plugin $oldplugin->{PLUGINDB_MD5_CHECKSUM} $oldplugin->{PLUGINDB_NAME} $oldplugin->{PLUGINDB_TITLE}\n";
	
	# my $plugin = LoxBerry::System::PluginDB->plugin(
		# author_name => $oldplugin->{PLUGINDB_AUTHOR_NAME},
		# author_email => $oldplugin->{PLUGINDB_AUTHOR_EMAIL},
		# version => $oldplugin->{PLUGINDB_VERSION},
		# name => $oldplugin->{PLUGINDB_NAME},
		# folder => $oldplugin->{PLUGINDB_FOLDER},
		# title => $oldplugin->{PLUGINDB_TITLE},
		# interface => $oldplugin->{PLUGINDB_INTERFACE},
		# autoupdate => $oldplugin->{PLUGINDB_AUTOUPDATE},
		# releasecfg => $oldplugin->{PLUGINDB_RELEASECFG},
		# prereleasecfg => $oldplugin->{PLUGINDB_PRERELEASECFG},
		# loglevel => $oldplugin->{PLUGINDB_LOGLEVEL},
		# loglevels_enabled => $oldplugin->{PLUGINDB_LOGLEVELS_ENABLED},
	# );
	# if($plugin) {
		# print "Created database entry for $plugin->{title}\n";
		# $plugin->save;
	# } else {
		# print "ERR: Could not create entry for $oldplugin->{PLUGINDB_TITLE}\n";
	# }
# }


# my $plugin1 = LoxBerry::System::PluginDB->plugin( md5 => '07a6053111afa90479675dbcd29d54b5' );
# if($plugin1) {
	# print "Plugin exists\n";
	# # print Dumper($plugin1);
	# # $plugin1->save();
# } else {
	# print "Plugin not defined\n";
# }

# print "Main: $dbfile_secured\n";
# my $plugin_secured = LoxBerry::System::PluginDB->plugin( 
	# md5 => '07a6053111afa90479675dbcd29d54b5', 
	# _dbfile => $dbfile_secured
# );
# if($plugin_secured) {
	# print "Plugin SECURED\n";
	# #print Dumper($plugin_secured);
	# # $plugin_secured->save();
# } else {
	# print "Plugin not defined\n";
# }


# # Change plugin 2 and save
# $plugin_secured->random(int(rand(100)));
# $plugin_secured->save;

# $plugin1->random(int(rand(100)));
# $plugin1->save;

# my $plugin2 = LoxBerry::System::PluginDB->plugin( 
	# author_name => 'Christian Fenzl', 
	# author_email => 'fenzl@t-r-t.at',
	# name => 'Very New Test Plugin 2', 
	# folder => 'testplugin',
	# title => 'Schönes Plugin'
# );

# if($plugin2) {
	# print "Plugin2 is new: " . $plugin2->_isnew . "\n";
	# $plugin2->save();
# } else { 
	# print "Plugin not defined\n";
# }

# my $plugin_to_remove = LoxBerry::System::PluginDB->plugin( md5 => '92d3a07b6bf39801bcf5756a8cc2f90a' );
# if( $plugin_to_remove ) {
	# my $ok = $plugin_to_remove->remove;
	# print "Removed: " . $ok ? "Removed\n" : "Failed to remove\n";
# } else {
	# print "Plugin to remove not found\n";
# }

# my (@result, @result2, @result3);

# # Search for a plugin
# @result = LoxBerry::System::PluginDB->search( folder => 'wiringpi' );
# print "Search result: " . Dumper(\@result) . "\n";

# ## Search with AND condition
# # Example: All plugins with interface 2.0 and custom loglevel are enabled
# @result = LoxBerry::System::PluginDB->search( 
	# interface => '2.0',
	# loglevels_enabled => '1',
# );
# print "Search result: " . Dumper(\@result) . "\n";

# ## Search with OR
# # You can do two searches, and combine the array
# @result1 = LoxBerry::System::PluginDB->search( name => 'nukismartlock' );
# @result2 = LoxBerry::System::PluginDB->search( folder => 'nukismartlock' );
# my %h;
# @result3 = map { $h{$_}++ ? () : $_ } (@result1, @result2);
# print "Result 1: " . join(", ", @result1) . "\n";
# print "Result 2: " . join(", ", @result2) . "\n";
# print "Result 3: " . join(", ", @result3) . "\n";

## You may use the _operator parameter, that's faster
## Default _operatior is 'and'
# print "Fast combined search with _operator\n";
# @result = LoxBerry::System::PluginDB->search( 
	# name => 'nukismartlock',
	# folder => 'nukismartlock',
	# _operator => 'or'
# );
# print "Result: " . join(", ", @result) . "\n";



# my $plugin1 = LoxBerry::System::PluginDB->plugin( md5 => '07a6053111afa90479675dbcd29d54b5' );
# print "Plugin 1 Title: $plugin1->{title}\n";
# print "Changing title of Plugin 1...\n";
# $plugin1->title("New MQTT gateway");
# print "Plugin 1 Title: $plugin1->{title}\n";

# print "Load another plugin...\n";
# my $plugin2 = LoxBerry::System::PluginDB->plugin( md5 => '1cd1e75734f2410b0dc795a13d3c04ef' );
# print "Plugin 2 Title: $plugin2->{title}\n";
# print "Changing title of Plugin 2...\n";
# $plugin2->title("New Any Plugin");
# print "Plugin 2 Title: $plugin2->{title}\n";
# print "Save Plugin 2...\n";
# $plugin2->save;
# print "Save Plugin 1...\n";
# $plugin1->save;
# print "Undef both plugins...\n";
# undef $plugin1;
# undef $plugin2;
# print "Reload Plugin 1...\n";
# my $plugin1 = LoxBerry::System::PluginDB->plugin( md5 => '07a6053111afa90479675dbcd29d54b5' );
# print "Plugin 1 Title: $plugin1->{title}\n";
# print "Reload Plugin 2...\n";
# my $plugin2 = LoxBerry::System::PluginDB->plugin( md5 => '1cd1e75734f2410b0dc795a13d3c04ef' );
# print "Plugin 2 Title: $plugin2->{title}\n";

my $plugin1 = LoxBerry::System::PluginDB->plugin( md5 => '07a6053111afa90479675dbcd29d54b5' );
print "Plugin 1 Title: $plugin1->{title}\n";
print "Changing title of Plugin 1...\n";
$plugin1->title("New MQTT gateway");
print "Plugin 1 Title: $plugin1->{title}\n";

print "Load another plugin...\n";
my $plugin2 = LoxBerry::System::PluginDB->plugin( md5 => '1cd1e75734f2410b0dc795a13d3c04ef' );
print "Plugin 2 Title: $plugin2->{title}\n";
print "Changing title of Plugin 2...\n";
$plugin2->title("New Any Plugin");
print "Plugin 2 Title: $plugin2->{title}\n";
print "Save Plugin 2...\n";
$plugin2->save;
print "Undef both plugins...\n";
undef $plugin1;
undef $plugin2;
print "Reload Plugin 1...\n";
my $plugin1 = LoxBerry::System::PluginDB->plugin( md5 => '07a6053111afa90479675dbcd29d54b5' );
print "Plugin 1 Title: $plugin1->{title}\n";
print "Reload Plugin 2...\n";
my $plugin2 = LoxBerry::System::PluginDB->plugin( md5 => '1cd1e75734f2410b0dc795a13d3c04ef' );
print "Plugin 2 Title: $plugin2->{title}\n";







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

