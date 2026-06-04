package Unix::Lsof::Result;

use 5.008;
use version; our $VERSION = qv('0.1.0');

use warnings;
use strict;
use Unix::Lsof;

use overload bool => sub {
    my ($self) = @_;
    if ( $self->{error} && (!keys %{$self->{output}}) ) {
        return;
    } else {
        return 1;
    }
};

sub _new {
    my ( $class, $parsed, $err, $raw,$opt ) = @_;

    my $self = {
                output => $parsed,
                error  => $err,
                _raw_output => $raw,
                options => $opt,
    };
    bless $self, $class;

    $self->_get_field_ids();
    return $self;
}

sub has_errors {
    my $self = shift;
    return $self->{error} ? 1 : 0;
}

sub errors {
    my $self = shift;
    return $self->{error};
}

sub get_pids {
    my $self = shift;
    my @params = ( "process id");
    unshift @params,$_[0] if ref( $_[0] );
    my @ret =$self->get_values( @params );
    return wantarray ? @ret : \@ret;
}

sub get_filenames {
    my $self = shift;
    my @params = ( "file name" );
    unshift @params,$_[0] if ref( $_[0] );
    my @ret = $self->get_values( @params );
    return wantarray ? @ret : \@ret;
}

sub get_values {
    my ( $self, @args ) = @_;
    my @col = $self->get_arrayof_columns(@args);
    return if (!defined $col[0]);
    return wantarray ? @{$col[0]} : $col[0];
}

sub get_arrayof_columns {
    my ( $self, @args ) = @_;
    my @rows = $self->get_arrayof_rows(@args);

    my @cols;
    my $i = 0;
    for my $r (@rows) {
        my $j = 0;
        for my $c (@$r) {
            $cols[ $j++ ][$i] = $c;
        }
        $i++;
    }
    return wantarray ? @cols : \@cols;
}

sub get_hashof_columns {
    my ( $self, @args ) = @_;
    my @cols = $self->get_arrayof_columns(@args);

    my %return;
    for my $i ( 0 .. $#cols ) {
        $return{ $args[$i] } = $cols[$i];
    }

    return wantarray ? %return : \%return;
}

sub get_hashof_rows {
    my ( $self, @args ) = @_;

    my ( $key, %ret );
    if ( ref( $args[0] ) eq ref( {} ) ) {
        $self->{_query}{filter} = shift @args;
    }

    ( $key, @{ $self->{_query}{inp_fields} } ) = @args;

    my $full_key = $Unix::Lsof::op_field{$key} || $key;

    $full_key =~ s/_/ /g;

    $self->_setup_fields();
    $self->_setup_filter();

    my %outp = %{ $self->{output} };

    my %uniqify;
    for my $pid ( keys %outp ) {
      LINELOOP:
        for my $file ( @{ $outp{$pid}{files} } ) {
            my $hkey = $self->_get_value( $full_key, $pid, $file ) || next LINELOOP;
            my $line = $self->_get_line( $pid, $file ) || next LINELOOP;

            my $i = 0;
            my %rline;

            for my $l (@$line) {
                if (defined $l) {
                    $rline{ $self->{_query}{inp_fields}[ $i ] } = $l;
                }
                $i++;
            }
            my $ukey = join $;, sort values %rline;
            next LINELOOP if !defined $ukey;

            if ( !exists $uniqify{$hkey} || !exists $uniqify{$hkey}{$ukey} ) {
                push @{ $ret{$hkey} }, \%rline;
                $uniqify{$hkey}{$ukey}=1;
            }
        }
    }
    delete $self->{_query};
    return wantarray ? %ret : \%ret;
}

sub get_arrayof_rows {
    my ( $self, @args ) = @_;

    my @ret;

    if ( ref( $args[0] ) eq ref( {} ) ) {
        $self->{_query}{filter} = shift @args;
    }

    $self->{_query}{inp_fields} = \@args;

    $self->_setup_fields();
    $self->_setup_filter();

    my %outp = %{ $self->{output} };

    my %uniqify;
    for my $pid ( keys %outp ) {
    ROWLOOP:
        for my $file ( @{ $outp{$pid}{files} } ) {
            my $line = $self->_get_line( $pid, $file ) || next ROWLOOP;

            push @ret, $line if ( !$uniqify{ join $;, map { defined $_ ? $_ : "" } @$line }++ );
        }
    }
    delete $self->{_query};
    return wantarray ? @ret : \@ret;
}

sub _setup_filter {
    my $self = shift;
    return if ( !exists $self->{_query}{filter} );

    %{ $self->{_query}{filter} } =
        map { my $t = $_; $t =~ s/_/ /g;
              $Unix::Lsof::op_field{$t} || $t => $self->{_query}{filter}{$_} }
            keys %{ $self->{_query}{filter} };

    my %check_filter = map { $_ => 1 } @{ $self->{_query}{ret_fields} };
    @{ $self->{_query}{force_validate} } = grep { !exists $check_filter{$_} }
        keys %{ $self->{_query}{filter} };
}

sub _setup_fields {
    my $self = shift;
    my ( @temp_fields, @ret_fields );

    # Use either field designators or names
    @ret_fields =
        map { $_ =~ s/_/ /g; $Unix::Lsof::op_field{$_} || $_ }
            @{ $self->{_query}{inp_fields} };

    for my $f (@ret_fields) {
        if ( exists $self->{_program_field_ids}{$f} ||
             exists $self->{_file_field_ids}{$f} 
        ) {
            push @temp_fields, $f;
        } else {
            $self->_iwarn("$f is not in the list of fields returned by lsof");
        }
    }

    $self->{_query}{ret_fields} = \@temp_fields;
}

sub _validate {
    my ( $self, $filter_key, $value ) = @_;

    my $filter = $self->{_query}{filter}{$filter_key};

    return if !defined $value;

    if ( ref($filter) eq ref( sub { } ) ) {
        return $filter->($value);
    } elsif ( ref($filter) eq ref(qr//) ) {
        return $value =~ $filter ? 1 : 0;
    } elsif ( $filter =~ m/\A\d+\z/ && $value =~ m/\A\d+\z/) {
        return $filter == $value ? 1 : 0;
    } elsif ( !ref($filter) ) {
        return $filter eq $value ? 1 : 0;
    } else  {
        $self->_iwarn(qq(Invalid filter specified for "$filter_key"));
    }
}


sub _get_line {
    my ( $self, $pid, $file ) = @_;
    my @line;

    for my $force ( @{ $self->{_query}{force_validate} } ) {
        my $val = $self->_get_value( $force, $pid, $file );
        $self->_validate( $force, $val ) || return;
    }

    for my $field ( @{ $self->{_query}{ret_fields} } ) {

        my $val = $self->_get_value( $field, $pid, $file );

        if ( exists( $self->{_query}{filter}{$field} ) ) {
            $self->_validate( $field, $val ) || return;
        }

        push @line, $val;
    }
    return \@line;
}

sub _get_value {
    my ( $self, $name, $pid, $file ) = @_;
    my $ret =
        exists $self->{_program_field_ids}{$name}
        ? $self->{output}{$pid}{$name}
        : $file->{$name};
    return $ret;
}

sub _get_field_ids {
    my $self = shift;

    for my $pid ( keys %{ $self->{output} } ) {
        for my $pfield ( keys %{ $self->{output}{$pid} } ) {
            if ( $pfield eq "files" ) {
                for my $file ( @{ ${ $self->{output} }{$pid}{files} } ) {
                    for my $id ( keys %$file ) {
                        $self->{_file_field_ids}{$id}++;
                    }
                }
            } else {
                $self->{_program_field_ids}{$pfield}++;
            }
        }
    }
}


sub _iwarn {
    my $self = shift;
    my $message = $_[0];
    if ( $self->{options}{suppress_errors} ) {
        $self->{error} .= $message;
    } else {
        warn @_;
    }
}


=head1 NAME

Unix::Lsof::Result - Perlish interface to lsof output


=head1 VERSION

This document describes Unix::Lsof::Result version 0.1.0


=head1 SYNOPSIS

    use Unix::Lsof;

    my $lr = lsof("-p",$$);

    if ($lr->has_errors()) {
        print qq(Errors encountered: $lr->errors());
    }

    my @pids         = $lr->get_pids();
    my @file_types   = $lr->get_values( "file type" );
    my $access_modes = $lr->get_values( "access mode" );

    # Print out file name and type
    my @filenames    = $lr->get_arrayof_rows( "file type", "file name" );
    for my $p (@filenames) {
        print "File type: $p->[0] - File name: $p->[1]\n";
    }

    # Print a list of open IPv4 connections
    my %filetype     = $lr->get_hashof_rows( "file type", "n", "protocol name" );
    for my $conn ( @{ $filetype{"IPv4"} } ) {
        print qq(IPv4 connection to: $conn->{"n"}, protocol: $conn->{"protocol name"}\n);
    }

    # Print out a list of open files larger than 1kb
    my @filesize     = $lr->get_arrayof_columns( "file name", "file size" );
    for my $i ( 0..scalar( @{ $filesize[1] } ) ) {
        if ( $filesize[1][$i] >= 1024 ) {
            print "File $filesize[0][$1] is over 1k\n";
        }
    }

    # Print out the size of text files found
    my $fs           = $lr->get_hashof_columns( "file name", "file size" );
    for my $i ( 0..scalar( @{ $fs->{"file name"} } ) ) {
        if ( $fs->{"file name"}[$i] =~ m/\.txt\z/ ) {
            print qq(Found $fs->{"file size"}[$i] bytes large text file\n);
        }
    }

    # The same as previous, using filters
    my @file_list    = $lr->get_values( { "file name" => qr/\.txt\z/ },
                                        "file size" );
    for my $f (@file_list) {
        print qq(Found $f bytes large text file);
    }

   # Looking for text files between 1 and 4k
   my @file_list     = $lr->get_filenames( { "file name" => qr/\.txt\z/,
                                             "file size"  => sub { $_[0] > 1024 &&
                                                                   $_[0] <= 4096  }
                                        }, "file name");


=head1 DESCRIPTION

This module offers multiple ways of organising and retrieving the data returned
by lsof. It attempts to make it as easy as possible for the user to obtain the
information he wants in the way he wants it.

The C<Unix::Lsof::Result> object is returned when calling C<<Unix::Lsof->lsof()>>
in scalar context. When evaluated in boolean context the object will evaluate to
true unless no STDOUT output is obtained from running the C<lsof> binary <b>and
</b> STDERR output was obtained from the same run. This allows for the following
logic :

    if ($lf = $lsof(@params)) {
        # we got output or no errors, some success was had
        warn "Errors: ".$lf->errors()
            if $lf->has_errors();
        # normal processing continues
        # ...
    } else {
        # no output and we have an error message, something is badly wrong
        die "Errors: ".$lf->errors();
    }

Note that you will only find out whether B<any> errors were encountered by
examining the C<has_errors> return value, examining truth of the object itself
only makes sense if you just care about some valid output being returned (e.g.
if you're passing in a list of files, some of which may not exist).

All of the output accessor methods (i.e. the methods starting with C<get_>, for
example C<get_values>, C<get_arrayof_rows>) have the following properties:

=over 4

=item *

Only return unique values

All output accessor methods will only return unique result sets, e.g. if
a single file is opened by multiple programs

   $lf->get_arrayof_rows( "file name", "process id");

will return as many rows as there are processes opening the file, whereas

   $lf->get_arrayof_rows( "file name", "file type");

will only return a single row, since file name and file type are the same for
all return sets.

=item *

Returns list or reference depending on calling context

The accessor methods are sensitive to their calling context and will return
either a list or a reference to an array/hash.

  # This will return a list
  @e = $lf->get_pids();

  # This will return an array reference
  $e = $lf->get_pids()

=item *

Fields can be specified either with their full name or single character

When specifying a list of fields which you want returned from the accessor, you
can either use the single character associated with that field (see the lsof man
page section "OUTPUT FOR OTHER PROGRAMS" for a list of these) or the full field
name as given in ther C<Unix::Lsof> perldoc, or the full field name with spaces
replaced by underscores (e.g. file_name instead of "file name").

=item *

Filters

The method can optionally be provided with a "filter" which limits the
data returned. For this, pass a hash reference as the first argument, of the
format

    {
      <field name> => <filter>,
      <field name> => <filter>,
      ...
    }

where <filter> can be either a scalar value, a reference to a regular expression
or a reference to a subroutine. Only record sets that match on all fields will
be returned. A subroutine must return true to "match", the field value is passed
in normally as the first element of the @_ array.

Example:

    {
        "process id"   => 4242,
        "n"            => qr/\.txt\z/i,
        "command_name" => sub { $_[0] =~ m/kde/ || $_[0] eq "cupsd" }
    }

Limitations: is is very well possible to specify a filter that completely excludes
any files, e.g.

    { "process id" => "-1" }

. Also, to specify more than one condition on a given field name (e.g. greater
than 100 but not 105) you need to use a sub e.g.

    { "process id" => sub { $_[0] > 100 && $_[0] != 105 } }

The same goes if you need to C<or> a set of constraints. Note that there is
currently no way to C<or> constraints over several fields (e.g. process id equals
1000 or user id equals 42).


=back

=head1 INTERFACE 

=head2 Methods

=over 4

=item C<has_errors>

    $lf->has_errors();

Returns true if the call to the lsof binary returned any STDERR output.

=item C<errors>

    $lf->errors();

Returns the STDERR output of the lsof binary in a single string. WARNING: it is
possible that this B<may> change in some future version to allow for more
sophisticated error handling (though using the result of this subroutine as a
simple string will almost certainly continue to be supported).

=item C<get_values>

    $lf->get_values( $field_name );
    $lf->get_values( $filter, $field_name );

Returns a list with the values for a single field.

=item C<get_pids>

    $lf->get_values();
    $lf->get_values( $filter );

Specialised version of get_values which returns a list of process ids.

=item C<get_filenames>

    $lf->get_filenames();
    $lf->get_filenames( $filter );

Specialised version of get_values which returns a list of file names.

=item C<get_arrayof_rows>

    $lf->get_arrayof_rows( @column_names );
    $lf->get_arrayof_rows( $filter, @column_names );

Returns a list of array references, each of which corresponds to a row of lsof
output. The order of the values in the referenced arrays corresponds to the
order of the parameters passed in; e.g. a call to

    $lf->get_arrayof_rows( "file name", "file type");

would produce a data structure like this

    [
        [ filename1, filetype1 ],
        [ filename2, filetype2 ],
        ...
    ]

=item C<get_arrayof_columns>

    $lf->get_arrayof_columns( @column_names );
    $lf->get_arrayof_columns( $filter, @column_names );

Returns a list of array references, each of which correspond to a field name
column. The order of array references correspond to the order of parameters
passed in, e.g. a call to

    $lf->get_arrayof_columns( "file name", "file type");

would produce a data structure like this

    [
        [ filename1, filename2, ... ],
        [ filetype1, filetype2, ... ]
    ]

=item C<get_hashof_columns>

    $lf->get_hashof_columns(  @column_names );
    $lf->get_arrayof_columns( $filter, @column_names );

Returns a hash references (or list which can be assigned to a hash). The hash
keys are the column names specified in the parameters, the hash values are array
references with the column values. E.g. a call to

    $lf->get_hashof_columns( "file name", "file type");

would produce a data structure like this

    {
        "file name" => [ filename1, filename2 ],
        "file type" => [ filetype1, filetype2 ]
    }

The hash keys returned are exactly of the same format as passed in via the
parameters, so passing in a single character will B<not> create a full field
name key. E.g.

    $lf->get_hashof_columns( "file_name", "t");

will produce this

    {
        "file_name" => [ filename1, filename2 ],
        "t"         => [ filetype1, filetype2 ]
    }

=item  C<get_hashof_rows>

    $lf->get_hashof_rows(  $key, @column_names );
    $lf->get_arrayof_rows( $filter, $key, @column_names );

Returns a hash reference (or a list which can be assigned to a hash). The hash
keys are the value of the field which is given as the first parameter. The hash
values are references to arrays, each of which contain a row of the requested
fields in a hash; e.g. a call to

    $lf->get_hashof_rows( "process id", "file name", "t" );

would produce a data structure like this

    {
        pid1 => [
                   {
                       "file name" => filename1,
                       "t"         => filetype1
                   },
                   {
                       "file name" => filename2,
                       "t"         => filetype2
                   },
                ],
        pid2 => [
                   {
                       "file name" => filename3,
                       "t"         => filetype3
                   }
                ]
    }



=back

=head1 DIAGNOSTICS

=over

=item C<< %s is not in the list of fields returned by lsof >>

You requested a field which was not in the list of fields returned by the lsof
binary. Check that you spelt the field name correctly and that it is in the list
of field names specified in the C<Unix::Lsof> docs. Also check that the field
name is supported on the platform you are running lsof on.

=item C<< Invalid filter specified for "%s" >>

You specified an invalid filter. Valid filters are strings, numbers or
references to regular expressions or subroutines. See the documentation on
"Filters" above.

=back


=head1 CONFIGURATION AND ENVIRONMENT

Unix::Lsof::Result requires no configuration files or environment variables.


=head1 DEPENDENCIES

Unix::Lsof::Result requires the following modules:

=over

=item *

version

=back


=head1 INCOMPATIBILITIES

None reported.


=head1 BUGS AND LIMITATIONS

Please report any bugs or feature requests to
C<bug-unix-lsof@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Unix-Lsof>.

No bugs have been reported so far. As with C<Unix::Lsof>, there are a number of
improvements that could be made to this module, particularly with regards to
filtering. Further development is almost certainly strictly "develop by
bugreport", so if you want a feature added, please open a wishlist item in the
RT web interface and let me know. I'm more than happy to do more work on this
module, but want to see what concrete improvements people would like to have.
As always, patches are more than welcome.


=head1 ACKNOWLEDGEMENTS

A very heartfelt thanks to Vic Abell for writing C<lsof>, it has been invaluable
to me over the years. Many thanks as always to http://www.perlmonks.org, the
monks continue to amaze and enlighten me. A very special thanks to Damian
Conway, who (amongst other things) recommends writing module documentation
at the same time as code (in his excellent book "Perl Best Practices"). I didn't
follow that advice and as a result writing these docs was more painful and
error-prone than it should have been. Please Mr. Conway, for the next edition
could you put more emphasis on that recommendation so that dolts like me get
it the first time?

=head1 AUTHOR

Marc Beyer  C<< <japh@tirwhan.org> >>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2008-2013,2009, Marc Beyer C<< <japh@tirwhan.org> >>. All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.


=head1 DISCLAIMER OF WARRANTY

BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
FOR THE SOFTWARE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT WHEN
OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES
PROVIDE THE SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER
EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE
ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE SOFTWARE IS WITH
YOU. SHOULD THE SOFTWARE PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL
NECESSARY SERVICING, REPAIR, OR CORRECTION.

IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR
REDISTRIBUTE THE SOFTWARE AS PERMITTED BY THE ABOVE LICENCE, BE
LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL,
OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE
THE SOFTWARE (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING
RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A
FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE), EVEN IF
SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF
SUCH DAMAGES.
