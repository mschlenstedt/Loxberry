package LoxBerry::WebLogin;

use strict;
use warnings;
use DBI;
use Digest::SHA qw(sha256_hex);
use Fcntl qw(O_CREAT O_EXCL O_WRONLY);
use IPC::Open3;
use Symbol qw(gensym);
use URI::Escape qw(uri_unescape);

# Browser sessions only. Apache continues to verify legacy Basic Auth itself.
# Never persist passwords or raw bearer tokens. Do not share DB handles between
# Apache children: each request creates its own store.
sub new {
    my ($class, %args) = @_;
    my $self = bless { now => sub { time }, %args }, $class;
    die "Missing WebLogin paths" unless $self->{state} && $self->{users};
    my @st = lstat $self->{state};
    die "WebLogin state directory must be private and owned by the web user"
        unless @st && -d _ && !-l _ && $st[4] == $< && ($st[2] & 077) == 0;
    my $path = "$self->{state}/sessions.sqlite";
    if (!-e $path) {
        if (sysopen(my $fh, $path, O_CREAT | O_EXCL | O_WRONLY, 0600)) { close $fh }
        elsif (!-e $path) { die "Cannot create session database" }
    }
    @st = lstat $path;
    die "Unsafe session database permissions"
        unless @st && -f _ && !-l _ && $st[4] == $< && ($st[2] & 077) == 0;
    my $db = DBI->connect("dbi:SQLite:dbname=$path", '', '', {
        RaiseError => 1, PrintError => 0, AutoCommit => 1,
        sqlite_busy_timeout => 5000,
    });
    $self->{db} = $db;
    $db->do('CREATE TABLE IF NOT EXISTS sessions (id TEXT PRIMARY KEY, user TEXT NOT NULL, fingerprint TEXT NOT NULL, csrf TEXT NOT NULL, expires INTEGER NOT NULL, seen INTEGER NOT NULL)');
    $db->do('CREATE TABLE IF NOT EXISTS attempts (bucket TEXT PRIMARY KEY, started INTEGER NOT NULL, count INTEGER NOT NULL)');
    return $self;
}

sub random_token {
    open my $fh, '<:raw', '/dev/urandom' or die "No system random source";
    my $data = '';
    while (length($data) < 32) {
        my $n = read($fh, my $part, 32 - length($data));
        die "Cannot read system random source" unless $n;
        $data .= $part;
    }
    close $fh;
    return unpack('H*', $data);
}

sub constant_equal {
    my ($a, $b) = @_;
    return 0 unless defined($a) && defined($b) && length($a) == length($b);
    my $different = 0;
    $different |= ord(substr($a, $_, 1)) ^ ord(substr($b, $_, 1)) for 0 .. length($a) - 1;
    return $different == 0;
}

sub fingerprint {
    my ($self, $user) = @_;
    open my $fh, '<:raw', $self->{users} or die "Cannot read web users";
    while (my $line = <$fh>) {
        $line =~ s/[\r\n]+$//;
        my ($name, $hash) = split /:/, $line, 2;
        if (defined($hash) && $name eq $user) { close $fh; return sha256_hex($line) }
    }
    close $fh;
    return '';
}

sub verify_password {
    my ($self, $user, $password) = @_;
    # These are the existing LoxBerry admin username rules. Passwords go through
    # stdin, never a shell, argv, logs, cookie, or the session database.
    return 0 unless defined($user) && $user =~ /\A[A-Za-z0-9_-]{3,20}\z/;
    return 0 unless defined($password) && length($password) && length($password) <= 1024;
    return 0 if $password =~ /[\x00\r\n]/;
    my $fingerprint = $self->fingerprint($user);
    my $err = gensym;
    my $pid = open3(my $in, my $out, $err,
        $self->{htpasswd} || '/usr/bin/htpasswd', '-vi', $self->{users}, $user);
    { local $SIG{PIPE} = 'IGNORE'; print {$in} "$password\n" }
    close $in;
    # htpasswd emits only a short status line. Discard it, including usernames.
    { local $/; my $discard = <$out>; $discard = <$err>; }
    close $out; close $err;
    waitpid($pid, 0);
    return $? == 0 && $fingerprint && constant_equal($fingerprint, $self->fingerprint($user)) ? $fingerprint : 0;
}

sub create_session {
    my ($self, $user, $verified_fingerprint) = @_;
    $user //= '';
    my $fingerprint = $user eq '' ? '' : $self->fingerprint($user);
    die "Unknown user" if $user ne '' && !$fingerprint;
    die "Credentials changed during login" if defined($verified_fingerprint) &&
        !constant_equal($verified_fingerprint, $fingerprint);
    my $token = random_token();
    my $now = $self->{now}->();
    my $session = { id => sha256_hex($token), user => $user,
        fingerprint => $fingerprint, csrf => random_token(),
        expires => $now + ($user eq '' ? 600 : 28800), seen => $now };
    # Bounded lifetime and opportunistic cleanup without a cron dependency.
    $self->{db}->do('DELETE FROM sessions WHERE expires < ? OR seen < ?', undef, $now, $now - 1800);
    # Bound unauthenticated form requests as well as password guesses. Keep the
    # newest 512 anonymous sessions; never evict an authenticated session here.
    $self->{db}->do("DELETE FROM sessions WHERE id IN (SELECT id FROM sessions WHERE user = '' ORDER BY seen DESC LIMIT -1 OFFSET 511)");
    $self->{db}->do('INSERT INTO sessions VALUES (?, ?, ?, ?, ?, ?)', undef,
        @{$session}{qw(id user fingerprint csrf expires seen)});
    return ($token, $session);
}

sub session {
    my ($self, $token) = @_;
    return unless defined($token) && $token =~ /\A[0-9a-f]{64}\z/;
    my $s = $self->{db}->selectrow_hashref('SELECT * FROM sessions WHERE id = ?', undef, sha256_hex($token));
    return unless $s;
    my $now = $self->{now}->();
    if ($s->{expires} <= $now || $s->{seen} + 1800 <= $now ||
        ($s->{user} ne '' && !constant_equal($s->{fingerprint}, $self->fingerprint($s->{user})))) {
        $self->revoke($token);
        return;
    }
    if ($s->{user} ne '' && $s->{seen} + 60 < $now) {
        $self->{db}->do('UPDATE sessions SET seen = ? WHERE id = ?', undef, $now, $s->{id});
    }
    return $s;
}

sub revoke {
    my ($self, $token) = @_;
    return unless defined($token) && $token =~ /\A[0-9a-f]{64}\z/;
    $self->{db}->do('DELETE FROM sessions WHERE id = ?', undef, sha256_hex($token));
}

sub consume_login {
    my ($self, $token, $csrf) = @_;
    my $s = $self->session($token);
    return unless $s && $s->{user} eq '' && constant_equal($s->{csrf}, $csrf);
    # Atomically consume the anonymous session: parallel POSTs cannot promote
    # the same pre-login cookie more than once (session fixation / replay).
    my $deleted = $self->{db}->do('DELETE FROM sessions WHERE id = ?', undef, $s->{id});
    return $deleted > 0;
}

sub allow_attempt {
    my ($self, $ip, $user) = @_;
    my $now = $self->{now}->();
    my $db = $self->{db};
    $db->do('BEGIN IMMEDIATE');
    my $allowed = eval {
        $db->do('DELETE FROM attempts WHERE started <= ?', undef, $now - 300);
        my $ok = 1;
        for my $bucket (["ip:$ip", 30], ["user:$user", 10]) {
            my $key = sha256_hex($bucket->[0]);
            $db->do('INSERT OR IGNORE INTO attempts VALUES (?, ?, 0)', undef, $key, $now);
            $db->do('UPDATE attempts SET count = count + 1 WHERE bucket = ?', undef, $key);
            my ($count) = $db->selectrow_array('SELECT count FROM attempts WHERE bucket = ?', undef, $key);
            $ok = 0 if $count > $bucket->[1];
            last unless $ok; # A blocked IP must not create unbounded user buckets.
        }
        $db->do('COMMIT');
        $ok;
    };
    if ($@) { eval { $db->do('ROLLBACK') }; die "Cannot rate limit login" }
    return $allowed;
}

sub safe_return {
    my ($value) = @_;
    return '/admin/system/index.cgi' unless defined($value) && length($value) <= 2048;
    # Keep destinations in the protected app, on this origin. Reject controls,
    # backslashes and their encoded forms before any browser normalization.
    return '/admin/system/index.cgi' if $value =~ /[\x00-\x20\x7f\\]/ || $value =~ /%(?:0[0-9a-f]|1[0-9a-f]|20|5c|7f)/i;
    my $path = uri_unescape((split /\?/, $value, 2)[0]);
    return '/admin/system/index.cgi' if $path =~ m{(?:\A|/)\.{1,2}(?:/|\z)};
    return $value if $value =~ m{\A/(?:admin|auth)/};
    return '/admin/system/index.cgi';
}

sub DESTROY { my ($self) = @_; $self->{db}->disconnect if $self->{db} }

1;
