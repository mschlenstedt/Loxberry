package Net::MQTT::Simple::SSL;

use base 'Net::MQTT::Simple';

use IO::Socket::SSL qw(SSL_VERIFY_NONE);

my $sslver = IO::Socket::SSL->VERSION;

# use strict;    # might not be available (e.g. on openwrt)
# use warnings;  # same.

BEGIN { *_croak = \&Net::MQTT::Simple::_croak }

sub _socket_class { "IO::Socket::SSL" }
sub _default_port { 8883 }

sub _socket_error { shift->_socket_class->errstr }
sub _secure { 1 }

sub new {
    my ($class, $server, $sockopts) = @_;
    @_ == 2 or @_ == 3 or _croak "Wrong number of arguments for $class->new";

    $sockopts ||= {};

    if (my $ca = $ENV{MQTT_SIMPLE_SSL_CA}) {
        $sockopts->{-f $ca ? "SSL_ca_file" : "SSL_ca_path"} //= $ca;
    }
    if (my $cert = $ENV{MQTT_SIMPLE_SSL_CERT}) {
        $sockopts->{SSL_cert_file} //= $cert;
    }
    if (my $key = $ENV{MQTT_SIMPLE_SSL_KEY}) {
        $sockopts->{SSL_key_file} //= $key;
    }
    ## Fingerprint support in IO::Socket::SSL appears to be broken, even in
    ## 1.988: during validation, X509_digest returns a different hash than
    ## after connecting. Haven't investigated yet, so I don't know if this is
    ## a bug in their code or in mine.
    # if (my $fp = $ENV{MQTT_SIMPLE_SSL_FINGERPRINT}) {
    #     $sockopts->{SSL_fingerprint} //= [];
    #     if (not ref $sockopts->{SSL_fingerprint}) {
    #         $sockopts->{SSL_fingerprint} = [ $sockopts->{SSL_fingerprint} ];
    #     }
    #     push @{ $sockopts->{SSL_fingerprint} }, $fp;
    # }
    if (my $wtf = $ENV{MQTT_SIMPLE_SSL_INSECURE}) {
        warn "Warning: certificate validation disabled";
        $sockopts->{SSL_verify_mode} = SSL_VERIFY_NONE;
    }
    return $class->SUPER::new($server, $sockopts);
}

1;

__END__

=head1 NAME

Net::MQTT::Simple::SSL - Minimal MQTT version 3 interface with SSL support

=head1 SYNOPSIS

    # Specifying SSL parameters in environment variables

    export MQTT_SIMPLE_SSL_CA=/etc/ssl/ca.crt
    export MQTT_SIMPLE_SSL_CERT=/etc/ssl/mqtt.crt
    export MQTT_SIMPLE_SSL_KEY=/etc/ssl/mqtt.key

    perl -MNet::MQTT::Simple::SSL=mosquitto.example.org \
         -nle'retain "topic/here" => $_'


    # Specifying explicit SSL parameters

    use Net::MQTT::Simple::SSL;

    my $mqtt = Net::MQTT::Simple::SSL->new("mosquitto.example.org", {
        SSL_ca_file   => '/etc/ssl/ca.crt',
        SSL_cert_file => '/etc/ssl/mqtt.crt',
        SSL_key_file  => '/etc/ssl/mqtt.key',
    });

    $mqtt->publish("topic/here" => "Message here");
    $mqtt->retain( "topic/here" => "Message here");

=head1 DESCRIPTION

A subclass of L<Net::MQTT::Simple> that adds SSL/TLS.

Like its base class, a server can be given on the C<use> line, in which case
C<publish> and C<retain> are exported so that they can be used as simple
functions. This interface supports configuration via environment variables,
but not via explicit options in code.

The object oriented interface does support explicit SSL configuration. See
L<IO::Socket::SSL> for a comprehensive overview of all the options that can be
supplied to the constructor, C<new>.

=head2 Environment variables

Instead of explicitly specifying the SSL options in the constructor, they can
be set with environment variables. These are overridden by options given to
C<new>.

=over 26

=item MQTT_SIMPLE_SSL_INSECURE

Set to something other than C<0> to disable SSL validation.

=item MQTT_SIMPLE_SSL_CA

Path to the CA certificate or a directory of certificates. IO::Socket::SSL
can find the CA path automatically on some systems.

=item MQTT_SIMPLE_SSL_CERT

=item MQTT_SIMPLE_SSL_KEY

Path to the client certificate file and its key file.

=back

=head1 LICENSE

Pick your favourite OSI approved license :)

http://www.opensource.org/licenses/alphabetical

=head1 AUTHOR

Juerd Waalboer <juerd@tnx.nl>

=head1 SEE ALSO

L<Net::MQTT::Simple>
