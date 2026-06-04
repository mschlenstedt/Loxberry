package Unix::Lsof;

use 5.008;
use version; our $VERSION = qv('0.1.0');

use warnings;
use strict;
use IPC::Run3;
use Unix::Lsof::Result;

use base qw(Exporter);

our @EXPORT    = qw(lsof);
our @EXPORT_OK = qw(parse_lsof_output);

our %op_field = (
    a => q(access mode),
    c => q(command name),
    C => q(structure share count),
    d => q(device character code),
    D => q(major/minor device number),
    f => q(file descriptor),
    F => q(structure address),
    g => q(process group id),
    G => q(flags),
    i => q(inode number),
    k => q(link count),
    K => q(task id),
    l => q(lock status),
    L => q(login name),
    n => q(file name),
    N => q(node identifier),
    o => q(file offset),
    p => q(process id),
    P => q(protocol name),
    r => q(raw device number),
    R => q(parent pid),
    s => q(file size),
    S => q(stream module and device names),
    t => q(file type),
    T => q(tcp/tpi info),
    u => q(user id),
    z => q(zone name),
    Z => q(selinux security context),
                 
);

our %tcptpi_field = (
                     QR => q(read queue size),
                     QS => q(send queue size),
                     SO => q(socket options and values),
                     SS => q(socket states),
                     ST => q(connection state),
                     TF => q(TCP flags and values),
                     WR => q(window read size),
                     WW => q(window write size),
                     );

my (%opt,$err);

sub lsof {
    my @arg = @_;

    $err = undef;
    _parse_opt (\@arg);

    # TODO: split arguments if only one argument is passed, so that a shell
    # line can be used as-is

    $opt{binary} ||= _find_binary() || _idie("Cannot find lsof binary");

    if ( ! -e $opt{binary} ) {
        _idie("Cannot find lsof binary: $!");
    }
    if ( !-x $opt{binary} || !-f $opt{binary} ) {
        _idie("$opt{binary} is not an executable binary: $!");
    }

    my $out="";

    eval { run3( [ $opt{binary}, "-F0", @arg ], \undef, \$out, \$err ); };

    if ($@) {
        $err = $err ? $@ . $err : $@;
    }

    my $parsed = _parse_lsof_output( $out );

    if (wantarray) {
        return ( $parsed, $err );
    } else {
        return Unix::Lsof::Result->_new( $parsed, $err, $out,\%opt );
    }
}

sub _idie {
    my $message = shift;
    if ( $opt{suppress_errors} ) {
        $err .= $message;
    } else {
        die $message;
    }
}

sub _iwarn {
    my $message = shift;
    if ( $opt{suppress_errors} ) {
        $err .= $message;
    } else {
        warn $message;
    }
}

sub _parse_opt {
    my $arg = shift;
    # set options to defaults
    %opt = (
            binary          => undef,
            tcp_tpi_parse   => "full",
            suppress_errors => 0,
        );

    if ( ref $arg->[-1] eq ref {} ) {
        my $manopt = pop @$arg;
        for my $k (keys %opt) {
            if (exists $manopt->{$k}) {
                $opt{$k} = $manopt->{$k};
            }
        }
    }
}

sub _find_binary {
#    return if (!$ENV{PATH});
    my @path = split( ":", $ENV{PATH} );
    my $bin;
  PATHLOOP:
    for my $p (@path) {
        if ( -f $p . "/lsof" && -x _ ) {
            $bin = $p . "/lsof";
            last PATHLOOP;
        }
    }
    return $bin;
}

# This is a stub for now. Constructing lsof arguments is a little
# tricky and will be done conclusively later
sub _construct_parameters {
    my $options = shift;
    my @cmd_line;
    my %translate = (
        pid  => "-p",
        file => undef
    );
    for my $arg ( keys %{$options} ) {
        if ( exists $translate{$arg} ) {
            push @cmd_line, $translate{$arg} if ( defined $translate{$arg} );
        } else {
            push @cmd_line, $options->{$arg};
        }
    }
    return scalar @cmd_line ? @cmd_line : undef;
}

sub _parse_lsof_output {
    my $out = shift;
    my ( %result, $pid, $previous );
    my @output = split (/\000\012/, $out);
    for my $line (@output) {
        $line =~ s/^[\s\0]*//;
        my @elements = split( "\0", $line );
        my ($ident,$content) = ( $elements[0] =~ m/^(\w)(.*)$/ );
        if ( !$ident ) {
            _idie("Can't parse line $line, identifier missing");
        } elsif ($ident eq "p") {
            $pid = $content;
            $result{$pid} = _parseelements( \@elements );
            $previous = $ident;
        } elsif ( $ident eq "f" ) {
            push @{ $result{$pid}{files} }, _parseelements( \@elements );
            $previous = $ident;
        } else {
            _idie("Can't parse line $line, operator field $ident is not valid");
        }

    }

    return \%result;
}

sub parse_lsof_output {
    my @args = @_;
    $err = undef;
    if (ref($args[0]) eq ref([])) {
        my $str = join("\000\012",@{$args[0]});
        return _parse_lsof_output($str);
    } else {
        return _parse_lsof_output($args[0]);
    }
}

sub _parseelements {
    my $elements = shift;

    my %result;
    while ( my $elem = shift @$elements ) {
        my ( $fident, $content ) = ( $elem =~ /^(.)(.*)$/ );
        next if !$fident;
        # Specialised handling of TCP/TPI info, since that field
        # contains multiple pieces of data
        if ($fident eq "T") {
            if ($opt{tcp_tpi_parse} eq "array") {
                push @{$result{ $op_field{$fident} } },$content;
            } else {
                my ($fi,$fc) = split(/=/,$content);
                my $key = $opt{tcp_tpi_parse} eq "part" ? $fi : $tcptpi_field{$fi};
                $result{ $op_field{$fident} }{ $key } = $fc;
            }
        } else {
#            warn $fident. " - ".$op_field{$fident}." - ".$content;
            $result{ $op_field{$fident} } = $content;
#            exit;
        }
    }
    return \%result;
}

1;    # Magic true value required at end of module
__END__

=head1 NAME

Unix::Lsof - Wrapper to the Unix lsof utility


=head1 VERSION

This document describes Unix::Lsof version 0.1.0


=head1 SYNOPSIS

    use Unix::Lsof;
    my ($output,$error) = lsof("afile.txt");
    my @pids = keys %$output;
    my @commands = map { $_->{"command name"} } values %$output;

    ($output,$error) = lsof("-p",$$);
    my @filenames;
    for my $pid (keys %$output) {
        for my $files ( @{ $o->{$k}{files} } ) {
            push @filenames,$f->{"file name"}
        }
    }

   my $lr = lsof ("-p",$$); # see Unix::Lsof::Result
   @filenames = $lrs->get_filenames();
   @inodes = $lrs->get_values("inode number");

   # With options
   my $lr = lsof ("-p",$$,{ binary => "/opt/bin/lsof" });

=head1 DESCRIPTION

This module is a wrapper around the Unix lsof utility (written by Victor
A.Abell, Copyright Purdue University), which lists open files as well as
information about the files and processes opening them. C<Unix::Lsof> uses
the lsof binary, so you need to have that installed in order to use this
module (lsof can be obtained from
L<ftp://lsof.itap.purdue.edu/pub/tools/unix/lsof>).

By default, this module exports a single function C<lsof>, to which you can pass
the same parameters you would the lsof binary. When called in list context,
C<lsof> will return two values, a hash reference containing the parsed output
of the lsof binary and a string containing (unparsed) any error messages. When
called in scalar context, C<lsof> will return a C<Unix::Lsof::Result> object
(see the documentation for that module for further details).

On request, you can also export the subroutine C<parse_lsof_output> which will
do what the name says and return the parsed output. Both of these support a
number of options, passed in as a hash reference as the last argument (see
section "OPTIONS" below).

=head1 INTERFACE

=head2 Subroutines

=over 4

=item lsof

 lsof ();
 lsof ( @lsof_arguments );
 lsof ( @lsof_arguments, \%options );

C<lsof> accepts arguments passed on to the lsof binary. These need to be in
list form, so you need to do

    $r = lsof("-p",$pid,"-a","+D","/tmp");

B<NOT>

    $r = lsof("-p $pid -a +D /tmp");


SCALAR CONTEXT

Example:

    $lr = lsof("afile");

When called in scalar context, C<lsof> will return a C<Unix::Lsof::Result>
object. Please see the documentation for that module on how to use this object.
I mean it, really, take a look there, you'll almost certainly want to use the
C<Unix::Lsof::Result> interface which gives you lots of helper methods to dig
out exactly the information you want.

LIST CONTEXT

Example:

    ($output,$error) = lsof("afile");

When called in list context, C<lsof> will return two values, a hash reference
containing the parsed output of the lsof binary, and a string containing any
error messages. The output data structure looks like this (approximating
C<Data::Dumper> formatting here:)

   $output = {
               '<pid>' => {
                            '<process field name>' => '<value>',
                            '<process field name>' => '<value>',
                            'files' => [
                                         {
                                           '<file field name>' => '<value>',
                                           '<file field name>' => '<value>'
                                         },
                                         {
                                           '<file field name>' => '<value>',
                                           '<file field name>' => '<value>'
                                                ...
                                         },
                                       ]
                          }
                  ...
             }

Each process id (pid) is the key to a hash reference that contains as keys the
names of process set fields and their corresponding field value. The special
C<files> key has an array reference as value. Each element in this array is a
hash reference that contains the names of file set fields and their values. See
the section OUTPUT FOR OTHER PROGRAMS in the lsof manpage if you're wondering
what process and file sets are.

Process field names are:

    "command name"
    "login name"
    "process id"
    "process group id"
    "parent pid"
    "task id"
    "user id"

File field names are:

    "access mode"
    "structure share count"
    "device character code"
    "major/minor device number"
    "file descriptor"
    "structure address"
    "flags"
    "inode number"
    "link count"
    "lock status"
    "file name"
    "node identifier"
    "file offset"
    "protocol name"
    "raw device number"
    "file size"
    "stream module and device names"
    "file type"
    "tcp/tpi info"
    "user id"
    "zone name"
    "selinux security context"

Special mention needs to be made of the field "tcp/tpi info", since that will
contain a list of information. Therefore, the value for this field is itself a
hash reference. The keys of this hash are the long names of the information, as
given in the lsof man page, the information names are:

    "read queue size"
    "send queue size"
    "socket options and values"
    "socket states"
    "connection state"
    "TCP flags and values"
    "window read size"
    "window write size"

Note that not all of this information is available on every dialect, see the lsof
man page for more.

=item parse_lsof_output ( <STRING> )

This function takes the output as obtained from the lsof binary (with the
-F0 option) and parses it into the data structure explained above. You need to
pass the lsof STDOUT output in as a single string. Previous behaviour (passing
the output as an array reference with one line of output per array element) is
deprecated as of Unix::Lsof version 0.0.8 and may not work in future releases.
C<parse_lsof_output> does B<not> understand the lsof STDERR output.

=item OPTIONS

You can (optionally) pass in a hash reference as the last argument to either
C<lsof> or C<parse_lsof_output>. This reference can contain the following
options:

=back

=over 8

=item binary

Contains the path of the lsof binary. Use this if lsof is not in your $ENV{PATH}.

=item suppress_errors

Default false. If set to 1, Unix::Lsof subroutines will not emit any warning
messages and will not die on a fatal error. Diagnostics suppressed in this way
can be found in $err (and $UNIX::Lsof::Result->err()).

=item tcp_tpi_parse

See the above section on "tcp/tpi info". Possible values:

"full"

Default. Parses out the tcptpi information and uses the long names as hash keys.

"part"

Also parses out the information, but uses the short names (e.g. QS for "send
queue size") as keys.

"array"

Returns an array reference instead of a hash, each element of the array
contains an unparsed TCP/TPI information (e.g. "QS=0").


=back

=head1 DIAGNOSTICS

=over

=item C<< Cannot find lsof program >>

Couldn't find the lsof binary which is required to use this module. Either
install lsof or (if it's installed) be sure that it is in your shells path.

=item C<< Can't parse line >>

Encountered a line of lsof output which could not be properly parsed. If you
get this from calling C<lsof()> it is almost certainly a bug, please let me know
so I can fix it. If you encountered it from running C<parse_lsof_output>, please
make sure that the output was obtained from running lsof with the -F0 option.

=item C<< Adding results of this line to process set for PID %s >>

Appears in conjunction with the "invalid field identifier" warning
and show that the incorrect output was encountered in a process set.

=item C<< Adding results of this line to file set line >>

Appears in conjunction with the "invalid field identifier" warning
and show that the incorrect output was encountered in a field set.

=item C<< Previous record neither a process nor file set, identifier was "%s" >>

Appears in conjunction with the "invalid field identifier" warning, something else
has gone wrong and we were unable to work around it. Please send a bug report to
C<bug-unix-lsof@rt.cpan.org>.


=back


=head1 CONFIGURATION AND ENVIRONMENT

Unix::Lsof requires no configuration files. It searches for the lsof binary in
the directories listed in your $PATH environment variable.

=head1 DEPENDENCIES

Unix::Lsof requires the following modules:

=over

=item *

version

=item *

IPC::Run3

=back


=head1 INCOMPATIBILITIES

None reported.

=head1 BUGS AND LIMITATIONS

Please report any bugs or feature requests to
C<bug-unix-lsof@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Unix-Lsof>.

No bugs have been reported so far. There are a number of improvements that could
be made to this module, particularly in the handling of parameters. Further
development is almost certainly strictly "develop by bugreport", so if you want
a feature added, please open a wishlist item in the RT web interface and let me
know. I'm more than happy to do more work on this module, but want to see what
concrete improvements people would like to have. As always, patches are more than
welcome.

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

Copyright (c) 2008-2013, Marc Beyer C<< <japh@tirwhan.org> >>. All rights reserved.

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
