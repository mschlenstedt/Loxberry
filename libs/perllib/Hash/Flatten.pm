###############################################################################
# Purpose : Flatten/Unflatten nested data structures to/from key-value form
# Author  : John Alden
# Created : Feb 2002
# CVS     : $Id: Flatten.pm,v 1.19 2009/05/09 12:42:02 jamiel Exp $
###############################################################################

package Hash::Flatten;

use strict;
use Exporter;
use Carp;

use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS $VERSION);
@ISA = qw(Exporter);
@EXPORT_OK = qw(flatten unflatten);
%EXPORT_TAGS = ('all' => \@EXPORT_OK);
$VERSION = ('$Revision: 1.19 $' =~ /([\d\.]+)/)[0];

use constant DEFAULT_HASH_DELIM => '.';
use constant DEFAULT_ARRAY_DELIM => ':';

#Check if we need to support overloaded stringification
use constant HAVE_OVERLOAD => eval {
	require overload;
};

sub new
{
	my ($class, $options) = @_;
	$options = {} unless ref $options eq 'HASH';
	my $self = {
		%$options
	};
	
	#Defaults
	$self->{HashDelimiter} ||= DEFAULT_HASH_DELIM;
	$self->{ArrayDelimiter} ||= DEFAULT_ARRAY_DELIM;
	$self->{EscapeSequence} = "\\" unless(defined $self->{EscapeSequence} && length($self->{EscapeSequence}) > 0);
	$self->{EscapeSequence} = undef if($self->{DisableEscapes});
	
	#Sanity check: delimiters don't contain escape sequence
	croak("Hash delimiter cannot contain escape sequence") if($self->{HashDelimiter} =~ /\Q$self->{EscapeSequence}\E/);
	croak("Array delimiter cannot contain escape sequence") if($self->{ArrayDelimiter} =~ /\Q$self->{EscapeSequence}\E/);
	
	TRACE(__PACKAGE__." constructor - $self");
	return bless($self, $class);	
}

sub flatten
{
	#Convert functional to OO with default ctor
	if(ref $_[0] ne __PACKAGE__) {
		return __PACKAGE__->new($_[1])->flatten($_[0]);
	}

	my ($self, $hashref) = @_;
	die("1st arg must be a hashref") unless(UNIVERSAL::isa($hashref, 'HASH'));
	
	my $delim = {
		'HASH' => $self->{HashDelimiter},
		'ARRAY' => $self->{ArrayDelimiter}
	};
	$self->{RECURSE_CHECK} = {};
	my @flat = $self->_flatten_hash_level($hashref,$delim);
	my %flat_hash = map {$_->[0], $_->[1]} @flat;
	return \%flat_hash;
}

sub unflatten
{
	#Convert functional to OO with default ctor
	if(ref $_[0] ne __PACKAGE__) {
		return __PACKAGE__->new($_[1])->unflatten($_[0]);
	}
	
	my ($self, $hashref) = @_;
	die("1st arg must be a hashref") unless(UNIVERSAL::isa($hashref, 'HASH'));

	my $delim = {
		'HASH' => $self->{HashDelimiter},
		'ARRAY' => $self->{ArrayDelimiter}
	};
	
	my $regexp = '((?:' . quotemeta($delim->{'HASH'}) . ')|(?:' . quotemeta($delim->{'ARRAY'}) . '))';
	if($self->{EscapeSequence}) { 
		$regexp = '(?<!'.quotemeta($self->{EscapeSequence}).')'.$regexp; #Use negative look behind
	} 
	TRACE("regex = /$regexp/");
	
	my %expanded;
	foreach my $key (keys %$hashref)
	{
		my $value = $hashref->{$key};
		my @levels = split(/$regexp/, $key);
		
		my $finalkey = $self->_unescape((scalar(@levels) % 2 ? pop(@levels) : ''), $self->{EscapeSequence});
		my $ptr = \%expanded;
		while (@levels >= 2)
		{
			my $key = $self->_unescape(shift(@levels), $self->{EscapeSequence});
			my $type = shift(@levels);
			if ($type eq $delim->{'HASH'})
			{
				if (UNIVERSAL::isa($ptr, 'HASH')) {
					$ptr->{$key} = {} unless exists $ptr->{$key};
					$ptr = $ptr->{$key};
				} else {
					$ptr->[$key] = {} unless defined $ptr->[$key];
					$ptr = $ptr->[$key];
				}
			}
			elsif ($type eq $delim->{'ARRAY'})
			{
				if (UNIVERSAL::isa($ptr, 'HASH')) {
					$ptr->{$key} = [] unless exists $ptr->{$key};
					$ptr = $ptr->{$key};
				} else {
					$ptr->[$key] = [] unless defined $ptr->[$key];
					$ptr = $ptr->[$key];
				}
			}
			else
			{
				die "Type '$type' was not recognized. This should not happen.";
			}
		}

		if (UNIVERSAL::isa($ptr, 'HASH')) {
			$ptr->{$finalkey} = $value;
		} else {
			$ptr->[$finalkey] = $value;
		}
	}
	return \%expanded;
}

#
# Private subroutines
#

sub _flatten
{
	my($self, $flatkey, $v, $delim) = @_;

	TRACE("flatten: $self - " . ref($v));

	if(UNIVERSAL::isa($v, 'REF'))
	{
		$v = $self->_follow_refs($v);
	}

	if(UNIVERSAL::isa($v, 'HASH'))
	{
		return $self->_flatten_hash_level($v, $delim, $flatkey);
	}
	elsif(UNIVERSAL::isa($v, 'ARRAY'))
	{
		return $self->_flatten_array_level($v, $delim, $flatkey);
	}	
	elsif(UNIVERSAL::isa($v, 'GLOB'))
	{
		$v = $self->_flatten_glob_ref($v);
	}
	elsif(UNIVERSAL::isa($v, 'SCALAR'))
	{
		$v = $self->_flatten_scalar_ref($v);
	}
	return [$flatkey, $v];
}

sub _follow_refs
{
	my ($self, $rscalar) = @_;
	while (UNIVERSAL::isa($rscalar, 'REF'))
	{
		if ($self->{RECURSE_CHECK}{_stringify_ref($rscalar)}++)
		{
			die "Recursive data structure detected. Cannot flatten recursive structures.";
		}

		if(defined $self->{OnRefRef}) { 
			if(ref $self->{OnRefRef} eq 'CODE') {
				TRACE("Executing coderef");
				$rscalar = $self->{OnRefRef}->($rscalar);
				next;
			} elsif($self->{OnRefRef} eq 'warn') {
				warn("$rscalar is a ".(ref $rscalar)." and will be followed");
			} elsif($self->{OnRefRef} eq 'die') {
				die("$rscalar is a ".(ref $rscalar));
			}
		}
		$rscalar = $$rscalar;
	}
	return $rscalar;
}

sub _flatten_hash_level
{
	my ($self, $hashref, $delim, $prefix) = @_;
	TRACE("_flatten_hash_level called");
	
	if ($self->{RECURSE_CHECK}{_stringify_ref($hashref)}++)
	{
		die "Recursive data structure detected at this point in the structure: '$prefix'. Cannot flatten recursive structures.";
	}

	my @flat;
	for my $k (keys %$hashref)
	{
		TRACE("_flatten_hash_level: flattening: $k");
		my $v = $hashref->{$k};
		$k = $self->_escape($k, $self->{EscapeSequence}, [values %$delim]);
		my $flatkey = (defined($prefix) ? $prefix.$delim->{'HASH'}.$k : $k);
		push @flat, $self->_flatten($flatkey, $v, $delim);
	}
	return @flat;
}

sub _flatten_array_level
{
	my ($self, $arrayref, $delim, $prefix) = @_;

	if ($self->{RECURSE_CHECK}{_stringify_ref($arrayref)}++)
	{
		die "Recursive data structure detected at this point in the structure: '$prefix'. Cannot flatten recursive structures.";
	}

	my @flat;
	foreach my $ind (0 .. $#$arrayref)
	{
		my $flatkey = (defined($prefix) ? $prefix.$delim->{'ARRAY'}.$ind : $ind);
		my $v = $arrayref->[$ind];
		push @flat, $self->_flatten($flatkey, $v, $delim);
	}
	return @flat;
}

sub _flatten_scalar_ref
{
	my ($self, $rscalar) = @_;
	if(defined $self->{OnRefScalar}) {
		if(ref $self->{OnRefScalar} eq 'CODE') {
			TRACE("Executing coderef");
			return $self->{OnRefScalar}->($rscalar);
		} elsif($self->{OnRefScalar} eq 'warn') {
			warn("$rscalar is a ".(ref $rscalar)." and will be followed");
		} elsif($self->{OnRefScalar} eq 'die') {
			die("$rscalar is a ".(ref $rscalar));
		}
	}
	return $$rscalar;
}

sub _flatten_glob_ref
{
	my($self, $rglob) = @_;
	if(defined $self->{OnRefGlob}) { 
		if(ref $self->{OnRefGlob} eq 'CODE') {
			TRACE("Executing coderef");
			return $self->{OnRefGlob}->($rglob);
		} elsif($self->{OnRefGlob} eq 'warn') {
			warn("$rglob is a ".(ref $rglob)." and will be followed");
		} elsif($self->{OnRefGlob} eq 'die') {
			die("$rglob is a ".(ref $rglob));
		}
	}
	return $rglob;	
}

sub _escape
{
	my ($self, $string, $eseq, $delim) = @_;
	return $string unless($eseq); #no-op
	$delim = [] unless(ref $delim eq 'ARRAY');
	
	foreach my $char($eseq, @$delim) {
		next unless(defined $char && length($char));
		$string =~ s/\Q$char\E/$eseq$char/sg;	
	}
	
	return $string;
}

sub _unescape
{
	my ($self, $string, $eseq) = @_;	
	return $string unless($eseq); #no-op
	
	#Remove escape characters apart from double-escapes
	$string =~ s/\Q$eseq\E(?!\Q$eseq\E)//gs;

	#Fold double-escapes down to single escapes
	$string =~ s/\Q$eseq$eseq\E/$eseq/gs;

	return $string;
}

sub _stringify_ref {
	my $ref = shift;
	return unless ref($ref); #Undef if not a reference
	return overload::StrVal($ref) if(HAVE_OVERLOAD && overload::Overloaded($ref));
	return $ref.''; #Force type conversion here
}

#Log::Trace stubs
sub TRACE {}
sub DUMP {}

1;

=head1 NAME

Hash::Flatten - flatten/unflatten complex data hashes

=head1 SYNOPSIS

	# Exported functions
	use Hash::Flatten qw(:all);
	$flat_hash = flatten($nested_hash);
	$nested_hash = unflatten($flat_hash);
	
	# OO interface
	my $o = new Hash::Flatten({
		HashDelimiter => '->', 
		ArrayDelimiter => '=>',
		OnRefScalar => 'warn',
	});
	$flat_hash = $o->flatten($nested_hash);
	$nested_hash = $o->unflatten($flat_hash);

=head1 DESCRIPTION

Converts back and forth between a nested hash structure and a flat hash of delimited key-value pairs.
Useful for protocols that only support key-value pairs (such as CGI and DBMs).

=head2 Functional interface

=over 4

=item $flat_hash = flatten($nested_hash, \%options)

Reduces a nested data-structure to key-value form.  The top-level container must be hashref.  For example:

	$nested = {
		'x' => 1,
		'y' => {
			'a' => 2,
			'b' => 3
		},
		'z' => [
			'a', 'b', 'c'
		]
	}

	$flat = flatten($nested);
	use Data::Dumper;
	print Dumper($flat);

	$VAR1 = {
		'y.a' => 2,
		'x' => 1,
		'y.b' => 3,
		'z:0' => 'a',
		'z:1' => 'b',
		'z:2' => 'c'
	};

The C<\%options> hashref can be used to override the default behaviour (see L</OPTIONS>).

=item $nested_hash = unflatten($flat_hash, \%options)

The unflatten() routine takes the flattened hash and returns the original nested hash (see L</CAVEATS> though).

=back

=head2 OO interface

=over 4

=item $o = new Hash::Flatten(\%options)

Options can be squirreled away in an object (see L</OPTIONS>)

=item $flat = $o->flatten($nested)

Flatten the structure using the options stored in the object.

=item $nested = $o->unflatten($flat)

Unflatten the structure using the options stored in the object.

=back

=head1 OPTIONS

=over 4

=item HashDelimiter and ArrayDelimiter

By default, hash dereferences are denoted by a dot, and array dereferences are denoted by a colon. However
you may change these characters to any string you want, because you don't want there to be any confusion as to
which part of a string is the 'key' and which is the 'delimiter'. You may use multicharacter strings
if you prefer.

=item OnRefScalar and OnRefRef and OnRefGlob

Behaviour if a reference of this type is encountered during flattening.  
Possible values are 'die', 'warn' (default behaviour but warns) or a coderef 
which is passed the reference and should return the flattened value.

By default references to references, and references to scalars, are followed silently.

=item EscapeSequence

This is the character or sequence of characters that will be used to escape the hash and array delimiters.
The default escape sequence is '\\'. The escaping strategy is to place the escape sequence in front of 
delimiter sequences; the escape sequence itself is escaped by replacing it with two instances.

=item DisableEscapes

Stop the escaping from happening.  No escape sequences will be added to flattened output, nor interpreted on the way back.

B<WARNING:> If your structure has keys that contain the delimiter characters, it will not be possible to unflatten the 
structure correctly.

=back

=head1 CAVEATS

Any blessings will be discarded during flattening, so that if you flatten an object you must re-bless() it on unflattening.

Note that there is no delimiter for scalar references, or references to references.
If your structure to be flattened contains scalar, or reference, references these will be followed by default, i.e.
C<'foo' =E<gt> \\\\\\$foo>
will be collapsed to
C<'foo' =E<gt> $foo>.
You can override this behaviour using the OnRefScalar and OnRefRef constructor option.

Recursive structures are detected and cause a fatal error.

=head1 SEE ALSO

The perlmonks site has a helpful introduction to when and why you
might want to flatten a hash: http://www.perlmonks.org/index.pl?node_id=234186

=over 4

=item CGI::Expand

Unflattens hashes using "." as a delimiter, similar to Template::Toolkit's behaviour.

=item Tie::MultiDim

This provides a tie interface to unflattening a data structure if you specify a "template" for the structure of the data.

=item MLDBM

This also provides a tie interface but reduces a nested structure to key-value form by serialising the values below the top level.

=back

=head1 VERSION

$Id: Flatten.pm,v 1.19 2009/05/09 12:42:02 jamiel Exp $

=head1 AUTHOR

John Alden E<amp> P Kent E<lt>cpan _at_ bbc _dot_ co _dot_ ukE<gt>

=head1 COPYRIGHT

(c) BBC 2005. This program is free software; you can redistribute it and/or
modify it under the GNU GPL.

See the file COPYING in this distribution, or http://www.gnu.org/licenses/gpl.txt

=cut
