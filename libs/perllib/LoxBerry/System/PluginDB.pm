#!/usr/bin/perl

use JSON;
use LoxBerry::System;
use LoxBerry::JSON;
use warnings;
use strict;

# Only for debugging
use Data::Dumper;

package LoxBerry::System::PluginDB;

our $VERSION = "2.0.0.2";
our $DEBUG = 0;

my %plugindb_handles;
# my $dbobj;
	# my $dbfile;
	# my $plugindb;



my $dbfile_default = $LoxBerry::System::lbsdatadir."/plugindatabase.json";


sub plugin
{
	my $class = shift;
	
	# if (@_ % 2) {
		# Carp::croak "Illegal parameter list has odd number of values\n" . join("\n", @_) . "\n";
	# }
		
	my %params = @_;
	my $self = \%params;
	bless $self, $class;
	
	$self->_load_db;
	
	my $dbfile = $self->{_dbfile};
	my $dbobj = $plugindb_handles{$dbfile}{dbobj};
	my $plugindb = $plugindb_handles{$dbfile}{plugindb};
	
	
	# Submitted an md5 - search plugin
	if ( $self->{md5} ) {
		if ( defined $plugindb->{plugins}->{ $self->{md5} } ) {
			# print STDERR "Plugin $self->{md5} exists\n";
			$self = $plugindb->{plugins}->{ $self->{md5} } ;
			bless $self, $class;
			$self->{_isnew} = 0;
			$self->{_dbobj} = $dbobj;
			$self->{_plugindb} = $plugindb;
			$self->{_dbfile} = $dbfile;
			
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
			$self->{_dbobj} = $dbobj;
			$self->{_plugindb} = $plugindb;
			$self->{_dbfile} = $dbfile;
		} else {
			# print STDERR "Plugin is new: $self->{md5}\n";
			$self->{_isnew} = 1;
		}
	} else {
		print STDERR "Plugin does not exist and cannot be created without required properties\n";
	}
	
	return $self;
	

}

sub search
{
	my $class = shift;
	my $self = {};
	bless $self, $class;
	my %params = @_;
	
	$self->_load_db();
	
	my $dbfile = $self->{_dbfile};
	my $dbobj = $plugindb_handles{$dbfile}{dbobj};
	my $plugindb = $plugindb_handles{$dbfile}{plugindb};
	
	
	# Build an AND query
	my @conditions;
	my $operator;
	
	foreach my $findkey ( keys %params ) {
		if($findkey eq '_operator') {
			$operator = $params{$findkey};
			next;
		}
		my $needle = lc($params{$findkey});
		my $query = "lc(\$_->{$findkey}) eq '$needle'";
		push @conditions, $query;
	}
		
	$operator = "and" if(!$operator);
	my $full_query = join(" $operator ", @conditions);
	
	print STDERR "Search for: $full_query\n";
	
	my @result = $dbobj->find( $plugindb->{plugins}, $full_query );
	
	return @result;
}

sub _calculate_md5 
{
	my $self = shift;
	require Digest::MD5;
	require Encode;
	
	my $pauthorname = $self->{author_name};
	my $pauthoremail = $self->{author_email};
	my $pname = $self->{name};
	my $pfolder = $self->{folder};
	
	if (! $pauthorname or !$pauthoremail or !$pname or !$pfolder) {
		return undef;
	}
	
	my $pmd5checksum = Digest::MD5::md5_hex(Encode::encode_utf8("$pauthorname$pauthoremail$pname$pfolder"));

	return $pmd5checksum;
}

sub save
{
	my $self = shift;
	
	my $dbfile = $self->{_dbfile};
	my $dbobj = $plugindb_handles{$dbfile}{dbobj};
	my $plugindb = $plugindb_handles{$dbfile}{plugindb};
	
	my $isnew = $self->{_isnew};
	my $md5 = $self->{md5};
	
	# print "dbobj: " . Data::Dumper::Dumper($dbobj) . "\n";
	
	if(!$md5) {
		print STDERR "Cannot save plugin - no md5 defined\n";
		return undef;
	}
		
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
	# $plugindb->{plugins}->{$md5} = { %$self } ;
	
	delete $plugindb->{plugins}->{$md5};
	
	# Do not save internal variables (beginning with _)
	foreach my $key ( sort keys %$self ) {
		next if( substr($key, 0, 1) eq '_' );
		$plugindb->{plugins}->{$md5}->{$key} = $self->{$key} ;
	}
	
	# Save
	$dbobj->write();

}

sub remove
{
	my $self = shift;
	
	my $dbfile = $self->{_dbfile};
	my $dbobj = $plugindb_handles{$dbfile}{dbobj};
	my $plugindb = $plugindb_handles{$dbfile}{plugindb};
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
	my $self = shift;
	
	my $dbfile = $dbfile_default;
	
	$self->{_dbfile} = $dbfile;
	
	my $dbobj = LoxBerry::JSON->new();
	$plugindb_handles{$dbfile}{dbobj} = $dbobj;
	$plugindb_handles{$dbfile}{plugindb} = $dbobj->open(filename => $dbfile);
	
	
	# print "_load_db: " . Data::Dumper::Dumper( $plugindb ) . "\n";

}

# Every unknown method is an object property
our $AUTOLOAD;
sub AUTOLOAD {
	my $self = shift;
	my $propvalue = shift;
	# Remove qualifier from original method name
	my $called = $AUTOLOAD =~ s/.*:://r;
	
	if(! defined $propvalue) {
		return $self->{$called};
	} else {
		$self->{$called} = $propvalue;
	}
}

sub DESTROY 
{ 
	# Currently nothing
} 



#####################################################
# Finally 1; ########################################
#####################################################
1;
