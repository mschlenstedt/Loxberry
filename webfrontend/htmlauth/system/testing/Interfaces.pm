use Data::Dumper;

package Interfaces;

our $VERSION = "1.5.0.1";
our $DEBUG = 1; 

sub new
{

	my $class = shift;
	my $self = {};
	bless $self, $class;
	return $self;

}

sub parse 
{
	my $self = shift;
	
	my @stanzas;
	
	my @possible_stanzas = qw ( 
		auto 
		allow-hotplug 
		no-auto-down 
		no-scripts 
		source 
		source-directory 
		mapping 
		iface 
	);
	
	my $curr_stanza;
	
	foreach my $line (@{$self->{filecontent}}) {
		next if(substr($line, 0, 1) eq "#"); # Skip comments
		print STDERR $line . "\n";
		$first = lc $1 if($line =~ /([^\s]+)/);
		if(in_array($first, \@possible_stanzas)) {
			print "New Stanza $first found\n";
			my @stanza;
			$curr_stanza = \@stanza;
			push @stanzas, \@stanza;
			push @stanza, $line;
		} elsif ( ! $curr_stanza ) {
			print STDERR "Skipping line $line\n";
			next;
		} else {
			push @{$curr_stanza}, $line;
		}
	}
	print STDERR "Interfaces:\n" . Data::Dumper::Dumper(@stanzas) . "\n";




# # Divide physical from logical interfaces 
		# $first = lc $1 if($line =~ /([^\s]+)/);
		# # print STDERR "first: " . $first . "\n";
		
		# # Physical interfaces
		# if( $first eq "auto" or substr($first, 0, 6) eq "allow-") {
			# my @found_interfaces = ( $line =~ /\w+/g );
			# shift @found_interfaces;
			# foreach(@found_interfaces) {
				# print STDERR "Interface $_ uses $first\n";
				# $interfaces{$_} = $first;
			# }
		# }
		# # Missing: no-auto-down, no-scripts
		
		




}

sub open
{

	my $self = shift;
	my ($filename) = @_;
	
	die "File not found: $filename " if ( ! -e $filename );
		
	open my $fh, '<', $filename;
	chomp(my @lines = <$fh>);
	close $fh;
	
	# Concentrate lines (backslash on the end is a continue sign for lines)
	my @conentrated;
	my $concentrate;
	foreach my $line (@lines) {
		$line =~ s/^\s+|\s+$//g;
		next if(!$line);
		if($concentrate) {
			$lastline = pop @concentrated;
			$line = $lastline . " " . $line;
			$concentrated = undef;
		}
		
		if ( substr($line, -1) eq '\\' ) {
			push @concentrated, substr($line, 0, -1);
			$concentrate = 1;
		} else {
			push @concentrated, $line;
		}
	}


	
	$self->{filecontent} = \@concentrated;
	
	# print STDERR "Output: " . Data::Dumper::Dumper($self->{filecontent}) if ($DEBUG);
	
	
}

sub in_array
{
	my ($string, $array) = @_;
	if ( grep( /^$string$/, @{$array} ) ) {
		return 1;
	}
}




1;