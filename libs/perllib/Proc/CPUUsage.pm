package Proc::CPUUsage;
$Proc::CPUUsage::VERSION = '1.002';
use strict;
use warnings;
use BSD::Resource qw( getrusage );
use Time::HiRes qw( gettimeofday tv_interval );

sub new {
  my $class = shift;
  
  return bless [ [gettimeofday()], _cpu_time(), 0 ], $class;
}

sub usage {
  my $self = $_[0];
  my ($t0, $r0, $u0) = @$self;
  return unless defined $r0;
  
  my ($dt, $dr, $t1, $r1, $u1);
  $t1 = [gettimeofday()];
  $dt = tv_interval($t0, $t1);
  $self->[0] = $t1;
  
  $r1 = _cpu_time();
  $dr = $r1 - $r0;
  $self->[1] = $r1;

  $u1 = $dt == 0 ? $u0 : $dr/$dt;
  $self->[2] = $u1;

  return $u1;
}

sub _cpu_time {
  my ($utime, $stime) = getrusage();
  return unless defined $utime && defined $stime;
  return $utime+$stime;
}

1;

__END__

=encoding utf8

=head1 NAME

Proc::CPUUsage - measures the percentage of CPU the current process is using


=head1 VERSION

version 1.002

=head1 SYNOPSIS

    my $cpu = Proc::CPUUsage->new;
    my $usage1 = $cpu->usage; ## returns usage since new()
    my $usage2 = $cpu->usage; ## returns usage since last usage()
    ...


=head1 DESCRIPTION

This module allows you to measure how much CPU your perl process is
using.

The construction of the object defines the inital values. Each call to
L</"usage()"> returns the CPU usage since the last call to L</"new()"> or
L</"usage()">.

The value returned is normalised between 0 and 1, the latter being
100% usage.


=head1 METHODS

=head2 new()

    $cpu = Proc::CPUUsage->new()

Creates a new L<Proc::CPUUsage|Proc::CPUUsage> object with the current values for CPU usage.


=head2 usage()

    $usage = $cpu->usage()

Returns the CPU usage since the last call to L</"new()"> or L</"usage()">.

The value returned is greater than 0 and lower or equal to 1.


=head1 SEE ALSO

L<AnyEvent::Monitor::CPU|AnyEvent::Monitor::CPU> for a more practical use for this module.


=head1 AUTHOR

Pedro Melo, C<< <melo at cpan.org> >>


=head1 COPYRIGHT & LICENSE

Copyright 2009 Pedro Melo.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
