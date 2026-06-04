#!/usr/bin/perl
use warnings;
use strict;
use LoxBerry::System;
use LoxBerry::JSON;
use Sys::Filesystem;
use Unix::Lsof;
use Hash::Merge;
# use CGI::Simple qw(-debug1);
use CGI;


# Mountpoint list of "nodev" devices
my @nodev_mounts;
my %lsof_result;
my @large_files;

# my $q = CGI::Simple->new;
my $q = CGI->new;
my $action = $q->param('action');

if( $action eq "getopenfiledata" ) {
	get_nodev_devices();
	get_open_files();
}

if( $action eq "getlargefiledata" ) {
	get_nodev_devices();
	get_large_files();
}


print_result();

# print "===============\n";
# foreach( @nodev_mounts ) 
# {
	# print $_ . "\n" if( $_ );
# }


sub get_nodev_devices
{

	my $fs = Sys::Filesystem->new();
	my @filesystems = $fs->filesystems( mounted => 1 );
	
	undef @nodev_mounts;
	
	for (@filesystems)
	{
		next if ( !$_ ); 
		my @options = split(',', $fs->options($_) );
		next if !( grep( /^nodev$/, @options ) );
		
		# printf("%s Format %s device %s Options: %s\n",
			# $fs->mount_point($_),
			# $fs->type($_),
			# $fs->device($_),
			# $fs->options($_)
	   # );
		push @nodev_mounts, $fs->mount_point($_);
		print STDERR "Mountpoint: " . $fs->mount_point($_) . "\n";
	}
 
	return @nodev_mounts;


}


sub get_open_files
{
	
	
	my %options;
	
	undef %lsof_result;
	
	my $merger = Hash::Merge->new('LEFT_PRECEDENT');
	
	foreach my $nodev ( @nodev_mounts )
	{
		next if (!$nodev);
		print STDERR "lsof: $nodev\n";
		my @lsof_arguments = ( $nodev );
		my ($res, $error) = lsof ( @lsof_arguments, \%options );
		%lsof_result = %{ $merger->merge( \%lsof_result, $res ) };
		use Data::Dumper;
		# print STDERR Dumper( $res );
		# print STDERR Dumper( \%fullres );
		print STDERR "Number of elements: " . scalar (keys %lsof_result) . "\n";
		
	}
	
	# Uniquify files arrays
	foreach my $process ( keys %lsof_result ) {
		# if( !defined $lsof_result{$process}->{'process id'} ) {
			# delete $lsof_result{$process};
		# }
		if( !defined $lsof_result{$process}->{files} ) {
			delete $lsof_result{$process};
			next;
		}
		my @files = @{$lsof_result{$process}->{files}};
		
		my %seen;
		
		my @unique = grep { ! $seen{$_->{'file name'} }++ } @files;
		$lsof_result{$process}->{files} = \@unique;
		# print STDERR Dumper( @unique ) . "\n";
		# exit;
		
	
		
	}
	
	
	
	
	print STDERR Dumper( \%lsof_result );
}

sub get_large_files
{
	# require File::Find::Rule;
	
	require File::Find;
	
	my %size;
	
	foreach my $nodev ( @nodev_mounts ) {
		print STDERR "nodev: $nodev\n";
		File::Find::find(sub {$size{$File::Find::name} = -s if -f;}, $nodev);
		
	}
	
	my @sorted = sort {$size{$b} <=> $size{$a}} keys %size;

	# Try to remove duplicates on different mount points
	my $i = -1;
	my @sorted_filtered;
	foreach ( @sorted ) {
		$i++;
		next if( $i==0);
		next if( m/[^\/]+$/ eq $sorted[$i-1]=~m/[^\/]+$/ and $size{$_} == $size{ $sorted[$i-1] } );
		push @sorted_filtered, $_;
	}
	
	
	splice @sorted_filtered, 30 if @sorted_filtered > 30;
	
	foreach( @sorted_filtered ) {
		push @large_files, { name => $_, size => $size{$_} };
	}	
	
	
	
	
	
	# #!/usr/local/bin/perl -w

	# ($#ARGV == 0) or die "Usage: $0 [directory]\n"; 

	# use File::Find;
		
	# find(sub {$size{$File::Find::name} = -s if -f;}, @ARGV);
	# @sorted = sort {$size{$b} <=> $size{$a}} keys %size;
		
	# splice @sorted, 20 if @sorted > 20;
		
	# foreach (@sorted) 
	# {
		# printf "%10d %s\n", $size{$_}, $_;
	# }	
	
	
}


sub print_result
{
	my %returndata;
	
	$returndata{nodev_mounts} = \@nodev_mounts;
	$returndata{lsof_result} = \%lsof_result;
	$returndata{large_files} = \@large_files;
	
	# print quotemeta( encode_json( \%returndata ) );
	print encode_json( \%returndata );
	# print STDERR "\n\n";
	# print STDERR encode_json( \%lsof_result );
	
	
}
