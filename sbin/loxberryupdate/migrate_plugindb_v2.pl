#!/usr/bin/perl

use LoxBerry::System;
use LoxBerry::JSON;
use Data::Dumper;

$LoxBerry::System::DEBUG = 1;

if(!$lbsdatadir) {
	die("Could not read LoxBerry variables");
}

$dbfile = "$lbsdatadir/plugindatabase.json";

# Create new database file
unlink $dbfile;

# Read old database with old code
my @plugins = get_plugins_V1(undef, 1);

# Transform data
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
		print "ERR: Could not create entry for $oldplugin->{PLUGINDB_TITLE}\n";
	}
}


# my $plugin1 = LoxBerry::System::PluginDB->plugin( md5 => 'cbb215d37c67b25110043e95d0e2d492' );
# if($plugin1) {
	# print "Plugin exists - Salling save\n";
	# $plugin1->save();
# } else {
	# print "Plugin not defined\n";
# }

# my $plugin2 = LoxBerry::System::PluginDB->plugin( 
	# author_name => 'Christian Fenzl', 
	# author_email => 'fenzl@t-r-t.at',
	# name => 'New Test Plugin', 
	# folder => 'testplugin',
	# title => 'Schönes Plugin'
# );

# if($plugin2) {
	# print "Plugin2 is new: " . $plugin2->{_isnew} . "\n";
	# $plugin2->save();
# } else { 
	# print "Plugin not defined\n";
# }

# my $plugin_to_remove = LoxBerry::System::PluginDB->plugin( md5 => 'c5b8ba6f10b15415f8554c40064347aa' );
# if( $plugin_to_remove ) {
	# my $ok = $plugin_to_remove->remove;
	# print "Removed: " . $ok ? "Removed\n" : "Failed to remove\n";
# } else {
	# print "Plugin to remove not found\n";
# }

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


package LoxBerry::System::PluginDB;

use LoxBerry::System;

sub plugin
{
	my $class = shift;
	
	# if (@_ % 2) {
		# Carp::croak "Illegal parameter list has odd number of values\n" . join("\n", @_) . "\n";
	# }
		
	my %params = @_;
	my $self = \%params;
	bless $self, $class;
	
	_load_db();
	
	# Submitted an md5 - search plugin
	if ( $self->{md5} ) {
		if ( defined $plugindb->{plugins}->{ $self->{md5} } ) {
			# print STDERR "Plugin $self->{md5} exists\n";
			$self = $plugindb->{plugins}->{ $self->{md5} } ;
			bless $self, $class;
			$self->{_isnew} = 0;
		} else {
			# print STDERR "Plugin $self->{md5} does not exist\n";
			return undef;
		}
	} elsif ( $self->{md5} = $self->_calculate_md5 ) {
		if ( defined $plugindb->{plugins}->{ $self->{md5} } ) {
			# print STDERR "Plugin exists\n";
			# Take the database values
			$self = ( $plugindb->{plugins}->{ $self->{md5} } );
			# Update the db values by the parameters
			foreach my $paramkey ( keys %params ) {
				$self->{$paramkey} = $params{$paramkey};
			}
			# Re-bless $self
			bless $self, $class;
			$self->{_isnew} = 0;
		} else {
			# print STDERR "Plugin is new: $self->{md5}\n";
			$self->{_isnew} = 1;
		}
	} else {
		print STDERR "Plugin does not exist and cannot be created without required properties\n";
	}
	
	return $self;
	

}

# sub _searchpluginmd5
# {
	# my $self = shift;
	# print "_searchpluginmd5: " . $self->{md5} . "\n";
	# my @result = $dbobj->find( $plugindb->{plugins}, " $_ eq '".$self->{md5}."'" );
	# print "Result _searchpluginmd5: ".  Data::Dumper::Dumper(@result) . "\n";
	# return @result;
# }

sub _calculate_md5 
{
	my $self = shift;
	require Digest::MD5;
	require Encode;
	
	my $pauthorname = $self->{author_name};
	my $pauthoremail = $self->{author_email};
	my $name = $self->{name};
	my $folder = $self->{folder};
	
	if (! $pauthorname or !$pauthoremail or !$name or !$folder) {
		return undef;
	}
	
	my $pmd5checksum = Digest::MD5::md5_hex(Encode::encode_utf8("$pauthorname$pauthoremail$pname$pfolder"));

	return $pmd5checksum;
}

sub save
{
	my $self = shift;
	
	my $isnew = $self->{_isnew};
	delete $self->{_isnew};
	
	my $md5 = $self->{md5};
	
	if(!$md5) {
		print STDERR "Cannot save plugin - no md5 defined\n";
		return undef;
	}
		
	# print STDERR "Save $md5 (isnew $isnew)\n";
	
	# print "Data of dbobj: " . Data::Dumper::Dumper($dbobj) . "\n";
	
	
	my $homedir = $LoxBerry::System::lbhomedir;
	my $plugindir = $self->{folder};
	my $pluginname = $self->{name};
	
	# Save common variables
	my %directories;
	$directories{lbphtmlauthdir} = "$homedir/webfrontend/htmlauth/plugins/$plugindir";
	$directories{lbphtmldir} = "$homedir/webfrontend/html/plugins/$plugindir";
	$directories{lbptemplatedir} = "$homedir/templates/plugins/$plugindir";
	$directories{lbpdatadir} = "$homedir/data/plugins/$plugindir";
	$directories{lbplogdir} = "$homedir/log/plugins/$plugindir";
	$directories{lbpconfigdir} = "$homedir/config/plugins/$plugindir";
	$directories{lbpbindir} = "$homedir/bin/plugins/$plugindir";
	$self->{directories} = \%directories;
	
	my %files;
	$files{daemon} = "$homedir/system/daemons/plugins/$pluginname";
	$files{uninstall} = "$homedir/data/system/uninstall/$pluginname";
	$files{sudoers} = "$homedir/system/sudoers/$pluginname";
	$self->{files} = \%files;
	
	
	# Save data to the database object
	$plugindb->{plugins}->{$md5} = { %$self } ;
	
	# Remove internal properties
	delete $plugindb->{plugins}->{$md5}->{_isnew};
	
	# Save
	$dbobj->write();

}

sub remove
{
	my $self = shift;
	
	my $md5 = $self->{md5};
	
	if(!$md5) {
		print STDERR "Cannot remove plugin - no md5 set\n";
		return undef;
	}
	
	if( defined $plugindb->{plugins}->{$md5} ) {
		delete $plugindb->{plugins}->{$md5};
		$dbobj->write();
	}

	return 1;

}


sub _load_db
{
	# print "Loading PluginDB\n";
	my $dbfile = $LoxBerry::System::lbsdatadir."/plugindatabase.json";
	
	# if (! -e $dbfile) {
		# print STDERR "DB file not found: $dbfile\n";
		# die;
	# }
	
	our $dbobj = LoxBerry::JSON->new();
	our $plugindb = $dbobj->open(filename => $dbfile );

	# print "_load_db: " . Data::Dumper::Dumper( $plugindb ) . "\n";

}