package Net::MQTT::Simple;

use strict;
use warnings;

our $VERSION = '1.23';

# Please note that these are not documented and are subject to change:
our $KEEPALIVE_INTERVAL = 60;
our $PING_TIMEOUT = 10;
our $RECONNECT_INTERVAL = 5;
our $MAX_LENGTH = 2097152;    # 2 MB
our $READ_BYTES = 16 * 1024;  # 16 kB per IO::Socket::SSL recommendation
our $PROTOCOL_LEVEL = 0x04;   # 0x03 in v3.1, 0x04 in v3.1.1
our $PROTOCOL_NAME = "MQTT";  # MQIsdp in v3.1, MQTT in v3.1.1

my $global;

BEGIN {
    *_socket_class =
      eval { require IO::Socket::IP; 1 }   ? sub { "IO::Socket::IP" }
    : eval { require IO::Socket::INET; 1 } ? sub { "IO::Socket::INET" }
    : die "Neither IO::Socket::IP nor IO::Socket::INET found";
}

sub _default_port { 1883 }
sub _socket_error { "$@" }
sub _secure { 0 }

my $random_id = join "", map chr 65 + int rand 26, 1 .. 10;
sub _client_identifier { "Net::MQTT::Simple[$random_id]" }

# Carp might not be available either.
sub _croak {
    die sprintf "%s at %s line %d.\n", "@_", (caller 1)[1, 2];
}

sub filter_as_regex {
    my ($filter) = @_;

    return "^(?!\\\$)" if $filter eq '#';   # Match everything except /^\$/
    return "^/"        if $filter eq '/#';  # Parent (empty topic) is invalid

    $filter = quotemeta $filter;

    $filter =~ s{ \z (?<! \\ \/ \\ \# ) } {\\z}x;       # Anchor unless /#$/
    $filter =~ s{ \\ \/ \\ \#           } {}x;
    $filter =~ s{ \\ \+                 } {[^/]*+}xg;
    $filter =~ s{ ^ (?= \[ \^ / \] \* ) } {(?!\\\$)}x;  # No /^\$/ if /^\+/

    return "^$filter";
}

sub import {
    my ($class, $server) = @_;
    @_ <= 2 or _croak "Too many arguments for use " . __PACKAGE__;

    $server or return;

    $global = $class->new($server);

    *{ (caller)[0] . "::publish" } = \&publish;
    *{ (caller)[0] . "::retain"  } = \&retain;
}

sub new {
    my ($class, $server, $sockopts) = @_;
    @_ == 2 or @_ == 3 or _croak "Wrong number of arguments for $class->new";

    my $port = $class->_default_port;

    # Add port for bare IPv6 address
    $server = "[$server]:$port" if $server =~ /:.*:/ and not $server =~ /\[/;

    # Add port for bare IPv4 address or bracketed IPv6 address
    $server .= ":$port" if $server !~ /:/ or $server =~ /^\[.*\]$/;

    return bless {
        server       => $server,
        last_connect => 0,
        sockopts     => $sockopts // {},
    }, $class;
}

sub last_will {
    my ($self, $topic, $message, $retain) = @_;

    my %old;
    %old = %{ $self->{will} } if $self->{will};

    _croak "Wrong number of arguments for last_will" if @_ > 4;

    if (@_ >= 2) {
        if (not defined $topic and not defined $message) {
            delete $self->{will};
            delete $self->{encoded_will};

            return;
        } else {
            $self->{will} = {
                topic   => $topic    // $old{topic}   // '',
                message => $message  // $old{message} // '',
                retain  => !!$retain // $old{retain}  // 0,
            };
            _croak("Topic is empty") if not length $self->{will}->{topic};

            my $e = $self->{encoded_will} = { %{ $self->{will} } };
            utf8::encode($e->{topic});
            utf8::downgrade($e->{message}, 1) or do {
                my ($file, $line, $method) = (caller 1)[1, 2, 3];
                warn "Wide character in $method at $file line $line.\n";
                utf8::encode($e->{message});
            };
        }
    }

    return @{ $self->{will} }{qw/topic message retain/};
}

sub login {
    my ($self, $username, $password) = @_;


    if (@_ > 1) {
        _croak "Password login is disabled for insecure connections"
            if defined $password
            and not $self->_secure || $ENV{MQTT_SIMPLE_ALLOW_INSECURE_LOGIN};

        utf8::encode($username);
        $self->{username} = $username;
        $self->{password} = $password;
    }

    return $username;
}

sub _connect {
    my ($self) = @_;

    return if $self->{socket} and $self->{socket}->connected;

    if ($self->{last_connect} > time() - $RECONNECT_INTERVAL) {
        select undef, undef, undef, .01;
        return;
    }

    # Reset state
    $self->{last_connect} = time;
    $self->{buffer} = "";
    delete $self->{ping};

    # Connect
    my $socket_class = $self->_socket_class;
    my %socket_options = (
        PeerAddr => $self->{server},
        %{ $self->{sockopts} }
    );
    $self->{socket} = $socket_class->new( %socket_options )
        or warn "$0: connect: " . $self->_socket_error . "\n";

    # Say hello
    local $self->{skip_connect} = 1;  # avoid infinite recursion :-)
    $self->_send_connect;
    $self->_send_subscribe;
}

sub _prepend_variable_length {
    # Copied from Net::MQTT::Constants
    my ($data) = @_;
    my $v = length $data;
    my $o = "";
    my $d;
    do {
        $d = $v % 128;
        $v = int($v/128);
        $d |= 0x80 if $v;
        $o .= pack "C", $d;
    } while $d & 0x80;
    return "$o$data";
}

sub _send {
    my ($self, $data) = @_;

    $self->_connect unless exists $self->{skip_connect};
    delete $self->{skip_connect};

    my $socket = $self->{socket} or return;

    syswrite $socket, $data
        or $self->_drop_connection;  # reconnect on next message

    $self->{last_send} = time;
}

sub _send_connect {
    my ($self) = @_;

    my $will = $self->{encoded_will};
    my $flags = 0x02;
    $flags |= 0x04 if $will;
    $flags |= 0x20 if $will and $will->{retain};

    $flags |= 0x80 if defined $self->{username};
    $flags |= 0x40 if defined $self->{username} and defined $self->{password};

    $self->_send("\x10" . _prepend_variable_length(pack(
        "x C/a* C C n n/a*"
            . ($flags & 0x04 ? "n/a* n/a*" : "")
            . ($flags & 0x80 ? "n/a*" : "")
            . ($flags & 0x40 ? "n/a*" : ""),
        $PROTOCOL_NAME,
        $PROTOCOL_LEVEL,
        $flags,
        $KEEPALIVE_INTERVAL,
        $self->_client_identifier,
        ($flags & 0x04 ? ($will->{topic}, $will->{message}) : ()),
        ($flags & 0x80 ? $self->{username} : ()),
        ($flags & 0x40 ? $self->{password} : ()),
    )));
}

sub _send_subscribe {
    my ($self, @topics) = @_;

    if (not @topics) {
        @topics = keys %{ $self->{sub} } or return;
    }
    return if not @topics;

    utf8::encode($_) for @topics;

    # Hardcoded "packet identifier" \0\x01 for now (was \0\0 but the spec
    # disallows it for subscribe packets and mosquitto started enforcing that.)
    $self->_send("\x82" . _prepend_variable_length("\0\x01" .
        pack("(n/a* x)*", @topics)  # x = QoS 0
    ));
}

sub _send_unsubscribe {
    my ($self, @topics) = @_;

    return if not @topics;

    utf8::encode($_) for @topics;

    # Hardcoded "packet identifier" \0\0 for now.
    $self->_send("\xa2" . _prepend_variable_length("\0\0" .
        pack("(n/a*)*", @topics)
    ));
}

sub _parse {
    my ($self) = @_;

    my $bufref = \$self->{buffer};

    return if length $$bufref < 2;

    my $offset = 1;

    my $length = do {
        my $multiplier = 1;
        my $v = 0;
        my $d;
        do {
            return if $offset >= length $$bufref;  # not enough data yet
            $d = unpack "C", substr $$bufref, $offset++, 1;
            $v += ($d & 0x7f) * $multiplier;
            $multiplier *= 128;
        } while ($d & 0x80);
        $v;
    };

    if ($length > $MAX_LENGTH) {
        # On receiving an enormous packet, just disconnect to avoid exhausting
        # RAM on tiny systems.
        # TODO: just slurp and drop the data
        $self->_drop_connection;
        return;
    }

    return if $length > (length $$bufref) + $offset;  # not enough data yet

    my $first_byte = unpack "C", substr $$bufref, 0, 1;

    my $packet = {
        type   => ($first_byte & 0xF0) >> 4,
        dup    => ($first_byte & 0x08) >> 3,
        qos    => ($first_byte & 0x06) >> 1,
        retain => ($first_byte & 0x01),
        data   => substr($$bufref, $offset, $length),
    };

    substr $$bufref, 0, $offset + $length, "";  # remove the parsed bits.

    return $packet;
}

sub _incoming_publish {
    my ($self, $packet) = @_;

    # Because QoS is not supported, no packed ID in the data. It would
    # have been 16 bits between $topic and $message.
    my ($topic, $message) = unpack "n/a a*", $packet->{data};

    utf8::decode($topic);

    for my $cb (@{ $self->{callbacks} }) {
        if ($topic =~ /$cb->{regex}/) {
            $cb->{callback}->($topic, $message, $packet->{retain});
            return;
        }
    }
}

sub _publish {
    my ($self, $retain, $topic, $message) = @_;

    $message //= "" if $retain;

    utf8::encode($topic);
    utf8::downgrade($message, 1) or do {
        my ($file, $line, $method) = (caller 1)[1, 2, 3];
        warn "Wide character in $method at $file line $line.\n";
        utf8::encode($message);
    };

    $self->_send(
        ($retain ? "\x31" : "\x30")
        . _prepend_variable_length(
            pack("n/a*", $topic) . $message
        )
    );
}

sub publish {
    my $method = UNIVERSAL::isa($_[0], __PACKAGE__);
    @_ == ($method ? 3 : 2) or _croak "Wrong number of arguments for publish";

    ($method ? shift : $global)->_publish(0, @_);
}

sub retain {
    my $method = UNIVERSAL::isa($_[0], __PACKAGE__);
    @_ == ($method ? 3 : 2) or _croak "Wrong number of arguments for retain";

    ($method ? shift : $global)->_publish(1, @_);
}

sub run {
    my ($self, @subscribe_args) = @_;

    $self->subscribe(@subscribe_args) if @subscribe_args;

    until ($self->{stop_loop}) {
        my @timeouts;
        push @timeouts, $KEEPALIVE_INTERVAL - (time() - $self->{last_send})
            if exists $self->{last_send};
        push @timeouts, $PING_TIMEOUT - (time() - $self->{ping})
            if exists $self->{ping};

        my $timeout = @timeouts
            ? (sort { $a <=> $b } @timeouts)[0]
            : 1;  # default to 1

        $self->tick($timeout);
    }

    delete $self->{stop_loop};
}

sub subscribe {
    my ($self, @kv) = @_;

    while (my ($topic, $callback) = splice @kv, 0, 2) {
        $self->{sub}->{ $topic } = 1;
        push @{ $self->{callbacks} }, {
            topic => $topic,
            regex => filter_as_regex($topic),
            callback => $callback,
        };
    }

    $self->_send_subscribe() if $self->{socket};
}

sub unsubscribe {
    my ($self, @topics) = @_;

    $self->_send_unsubscribe(@topics);

    my $cb = $self->{callbacks};
    @$cb = grep $_->{topic} ne $_, @$cb
        for @topics;

    delete @{ $self->{sub} }{ @topics };
}

sub tick {
    my ($self, $timeout) = @_;

    $self->_connect;

    my $socket = $self->{socket} or return;
    my $bufref = \$self->{buffer};

    my $r = '';
    vec($r, fileno($socket), 1) = 1;

    if (select $r, undef, undef, $timeout // 0) {
        sysread $socket, $$bufref, $READ_BYTES, length $$bufref
            or delete $self->{socket};

        while (length $$bufref) {
            my $packet = $self->_parse() or last;
            $self->_incoming_publish($packet) if $packet->{type} == 3;
            delete $self->{ping}              if $packet->{type} == 13;
        }
    }

    if (time() >= $self->{last_send} + $KEEPALIVE_INTERVAL) {
        $self->_send("\xc0\0");  # PINGREQ
        $self->{ping} = time;
    }
    if ($self->{ping} and time() >= $self->{ping} + $PING_TIMEOUT) {
        $self->_drop_connection;
    }

    return !! $self->{socket};
}

sub disconnect {
    my ($self) = @_;

    $self->_send(pack "C x", 0xe0)
        if $self->{socket} and $self->{socket}->connected;

    $self->_drop_connection;
}

sub _drop_connection {
    my ($self) = @_;

    delete $self->{socket};
    $self->{last_connect} = 0;
}

1;

__END__

=head1 NAME

Net::MQTT::Simple - Minimal MQTT version 3 interface

=head1 SYNOPSIS

    # One-liner that publishes sensor values from STDIN

    perl -MNet::MQTT::Simple=mosquitto.example.org \
         -nle'retain "topic/here" => $_'


    # Functional (single server only)

    use Net::MQTT::Simple "mosquitto.example.org";

    publish "topic/here" => "Message here";
    retain  "topic/here" => "Retained message here";


    # Object oriented (supports subscribing to topics)

    use Net::MQTT::Simple;

    my $mqtt = Net::MQTT::Simple->new("mosquitto.example.org");

    $mqtt->publish("topic/here" => "Message here");
    $mqtt->retain( "topic/here" => "Message here");

    $mqtt->run(
        "sensors/+/temperature" => sub {
            my ($topic, $message) = @_;
            die "The building's on fire" if $message > 150;
        },
        "#" => sub {
            my ($topic, $message) = @_;
            print "[$topic] $message\n";
        },
    );

=head1 DESCRIPTION

This module consists of only one file and has no dependencies except core Perl
modules, making it suitable for embedded installations where CPAN installers
are unavailable and resources are limited.

Only basic MQTT functionality is provided; if you need more, you'll have to
use the full-featured L<Net::MQTT> instead.

Connections are set up on demand, automatically reconnecting to the server if a
previous connection had been lost.

Because sensor scripts often run unattended, connection failures will result in
warnings (on STDERR if you didn't override that) without throwing an exception.

Please refer to L<Net::MQTT::Simple::SSL> for more information about encrypted
and authenticated connections.

=head2 Functional interface

This will suffice for most simple sensor scripts. A socket is kept open for
reuse until the script has finished. The functional interface cannot be used
for subscriptions, only for publishing.

Instead of requesting symbols to be imported, provide the MQTT server on the
C<use Net::MQTT::Simple> line. A non-standard port can be specified with a
colon. The functions C<publish> and C<retain> will be exported.

=head2 Object oriented interface

=head3 new(server[, sockopts])

Specify the server (possibly with a colon and port number) to the constructor,
C<< Net::MQTT::Simple->new >>. The socket is disconnected when the object goes
out of scope.

Optionally, a reference to a hash of socket options can be passed. Options
specified in this hash are passed on to the socket constructor.

=head3 last_will([$topic, $message[, $retain]])

Set a "Last Will and Testament", to be used on subsequent connections. Note
that the last will cannot be updated for a connection that is already
established.

A last will is a message that is published by the broker on behalf of the
client, if the connection is dropped without an explicit call to C<disconnect>.

Without arguments, returns the current values without changing the
active configuration.

When the given topic and message are both undef, the last will is deconfigured.
In other cases, only arguments which are C<defined> are updated with the given
value. For the first setting, the topic is mandatory, the message defaults to
an empty string, and the retain flag defaults to false.

Returns a list of the three values in the same order as the arguments.

=head3 login($username[, $password])

Sets authentication credentials, to be used on subsequent connections. Note
that the credentials cannot be updated for a connection that is already
established.

The username is text, the password is binary.

See L<Net::MQTT::Simple::SSL> for information about secure connections. To
enable insecure password authenticated connections, set the environment
variable MQTT_SIMPLE_ALLOW_INSECURE_LOGIN to a true value.

Returns the username.

=head1 DISCONNECTING GRACEFULLY

=head2 disconnect

Performs a graceful disconnect, which ensures that the server does NOT send
the registered "Last Will" message.

Subsequent calls that require a connection, will cause a new connection to be
set up.

=head1 PUBLISHING MESSAGES

The two methods for publishing messages are the same, except for the state of
the C<retain> flag.

=head2 retain(topic, message)

Publish the message with the C<retain> flag on. Use this for sensor values or
anything else where the message indicates the current status of something.

To discard a retained topic, provide an empty or undefined message.

=head2 publish(topic, message)

Publishes the message with the C<retain> flag off. Use this for ephemeral
messages about events that occur (like that a button was pressed).

=head1 SUBSCRIPTIONS

=head2 subscribe(topic, handler[, topic, handler, ...])

Subscribes to the given topic(s) and registers the callbacks. Note that only
the first matching handler will be called for every message, even if filter
patterns overlap.

=head2 unsubscribe(topic[, topic, ...])

Unsubscribes from the given topic(s) and unregisters the corresponding
callbacks. The given topics must exactly match topics that were previously
used with the C<subscribe> method.

=head2 run(...)

Enters an infinite loop, which calls C<tick> repeatedly. If any arguments
are given, they will be passed to C<subscribe> first.

=head2 tick(timeout)

Test the socket to see if there's any incoming message, waiting at most
I<timeout> seconds (can be fractional). Use a timeout of C<0> to avoid
blocking, but note that blocking automatic reconnection may take place, which
may take much longer.

If C<tick> returns false, this means that the socket was no longer connected
and that the next call will cause a reconnection attempt. However, a true value
does not necessarily mean that the socket is still functional. The only way to
reliably determine that a TCP stream is still connected, is to actually
communicate with the server, e.g. with a ping, which is only done periodically.

=head1 UTILITY FUNCTIONS

=head2 Net::MQTT::Simple::filter_as_regex(topic_filter)

Given a valid MQTT topic filter, returns the corresponding regular expression.

=head1 IPv6 PREREQUISITE

For IPv6 support, the module L<IO::Socket::IP> needs to be installed. It comes
with Perl 5.20 and is available from CPAN for older Perls. If this module is
not available, the older L<IO::Socket::INET> will be used, which only supports
Legacy IP (IPv4).

=head1 MANUAL INSTALLATION

If you can't use the CPAN installer, you can actually install this module by
creating a directory C<Net/MQTT> and putting C<Simple.pm> in it. Please note
that this method does not work for every Perl module and should be used only
as a last resort on systems where proper installers are not available.

To view the list of C<@INC> paths where Perl searches for modules, run C<perl
-V>. This list includes the current working directory (C<.>). Additional
include paths can be specified in the C<PERL5LIB> environment variable; see
L<perlenv>.

=head1 NOT SUPPORTED

=over 4

=item QoS (Quality of Service)

Every message is published at QoS level 0, that is, "at most once", also known
as "fire and forget".

=item DUP (Duplicate message)

Since QoS is not supported, no retransmissions are done, and no message will
indicate that it has already been sent before.

=item Authentication

No username and password are sent to the server.

=item Large data

Because everything is handled in memory and there's no way to indicate to the
server that large messages are not desired, the connection is dropped as soon
as the server announces a packet larger than 2 megabytes.

=item Validation of server-to-client communication

The MQTT spec prescribes mandatory validation of all incoming data, and
disconnecting if anything (really, anything) is wrong with it. However, this
minimal implementation silently ignores anything it doesn't specifically
handle, which may result in weird behaviour if the server sends out bad data.

Most clients do not adhere to this part of the specifications.

=back

=head1 CAVEATS

=head2 Automatic reconnection

Connection and reconnection are handled automatically, but without retries. If
anything goes wrong, this will cause a single reconnection attempt before the
following action. For example, if sending a message fails because of a
disconnected socket, the message will not be resent, but the next message might
succeed. Only one new connection attempt is done per approximately 5 seconds.
This behaviour is intended.

=head2 Unicode

This module uses the proper Perl Unicode abstractions for parts that according
to the MQTT specification are UTF-8 encoded. This includes I<topic>s, but not
I<message>s. Published messages are binary data, which you may have to encode
and decode yourself.

This means that if you have UTF-8 encoded string literals in your code, you
should C<use utf8;> and that any of those strings which is a I<message> will
need to be encoded by you, for example with C<utf8::encode($message);>.

It also means that a I<message> should never contain any character with an
ordinal value of greater than 255, because those cannot be used in binary
communication. If you're passing non-ASCII text strings, encode them before
publishing, decode them after receiving. A character greater than 255 results in
a warning

    Wide character in publish at yourfile.pl line 42.

while the UTF-8 encoded data is passed through. To get rid of the warning, use
C<utf8::encode($message);>.

=head1 LICENSE

Pick your favourite OSI approved license :)

http://www.opensource.org/licenses/alphabetical

=head1 AUTHOR

Juerd Waalboer <juerd@tnx.nl>

=head1 SEE ALSO

L<Net::MQTT>, L<Net::MQTT::Simple::SSL>
