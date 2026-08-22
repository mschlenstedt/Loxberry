# Please change version number (numbering after underscore) on EVERY change - keep it two-digits as recommended in perlmodstyle
# Major.Minor represents LoxBerry version (e.g. 0.23 = LoxBerry V0.2.3)

use strict;
use Digest::SHA;
use JSON;
use URI::Escape;
use LoxBerry::System;

package LoxBerry::Auth;

# Imported AFTER the package statement on purpose - the flock/O_* constants
# have to land in this namespace, not in main::
use Fcntl qw( :flock O_RDWR O_CREAT );

use base 'Exporter';

our @EXPORT_OK = qw (
	auth_method
	get_token
	refresh_token
	kill_token
	token_info
	request
);

our $VERSION = "4.0.0.1";
our $DEBUG = 0;

# Permission bits of the Miniserver token API
our $PERM_ADMIN = 0x01;
our $PERM_WEB   = 0x02;
our $PERM_APP   = 0x04;
our $PERM_SYSWS = 0x100;

# App + Sys-WS: ~3 months lifetime, includes the right to reboot
our $DEFAULT_PERM = 0x104;

# Renew as soon as less than this many seconds are left
our $REFRESH_THRESHOLD = 7 * 86400;

# HTTP timeout in seconds
our $TIMEOUT = 10;

# Below this firmware the token endpoints require application layer encryption
our $MIN_FIRMWARE = "11.2.10.22";

##################################################################
# Pure helpers - no I/O, no state
##################################################################

# Normalise the hashAlg field of getkey2. An empty field means SHA1
# (Miniservers from before the field was introduced).
sub _norm_alg
{
	my ($alg) = @_;
	$alg = defined $alg ? uc($alg) : '';
	$alg =~ s/[^A-Z0-9]//g;
	return 'SHA1'   if ($alg eq '' or $alg eq 'SHA1');
	return 'SHA256' if ($alg eq 'SHA256');
	return undef;
}

sub _hash_hex
{
	my ($alg, $data) = @_;
	return $alg eq 'SHA256' ? Digest::SHA::sha256_hex($data)
	                        : Digest::SHA::sha1_hex($data);
}

# The key from getkey2 is hex encoded and has to be used as raw bytes
sub _hmac_hex
{
	my ($alg, $data, $keyhex) = @_;
	my $key = pack("H*", $keyhex);
	return $alg eq 'SHA256' ? Digest::SHA::hmac_sha256_hex($data, $key)
	                        : Digest::SHA::hmac_sha1_hex($data, $key);
}

# The Miniserver expects the password hash in uppercase
sub _pw_hash
{
	my ($password, $salt, $alg) = @_;
	return uc( _hash_hex($alg, "$password:$salt") );
}

sub _auth_hash
{
	my ($user, $pwhash, $keyhex, $alg) = @_;
	return _hmac_hex($alg, "$user:$pwhash", $keyhex);
}

sub _token_hash
{
	my ($token, $keyhex, $alg) = @_;
	return _hmac_hex($alg, $token, $keyhex);
}

# jdev/cfg/api returns its value as a STRING using single quotes - that is not
# valid JSON and must not be fed to a JSON parser.
sub _parse_api_value
{
	my ($value) = @_;
	return undef if (!defined $value or $value eq '');
	my %out;
	while ( $value =~ /'([^']+)'\s*:\s*(?:'([^']*)'|([^,}\s]+))/g ) {
		$out{$1} = defined $2 ? $2 : $3;
	}
	return undef if (! %out);
	return \%out;
}

sub _fw_supported
{
	my ($fw) = @_;
	return 0 if (!defined $fw or $fw eq '');
	my @is  = split(/\./, $fw);
	my @min = split(/\./, $MIN_FIRMWARE);
	for my $i (0..3) {
		my $a = defined $is[$i]  ? int($is[$i])  : 0;
		my $b = defined $min[$i] ? int($min[$i]) : 0;
		return 1 if ($a > $b);
		return 0 if ($a < $b);
	}
	return 1;
}

# tokenRights is a bitmask; perm 0x104 was measured to return 1924
sub _rights_granted
{
	my ($rights, $bit) = @_;
	return 0 if (!defined $rights or !defined $bit);
	return ( (int($rights) & int($bit)) == int($bit) ) ? 1 : 0;
}

##################################################################
# Result objects
##################################################################

sub _err
{
	my ($code, $message) = @_;
	print STDERR "LoxBerry::Auth: $code - $message\n" if ($DEBUG);
	return { ok => 0, error => $code, message => $message };
}

##################################################################
# Token store - data/system/tokens.json, 0600, owner loxberry
##################################################################

# Test hook: set this to a temp path to decouple tests from the installation
our $store_file;

sub _store_file
{
	return $store_file if ($store_file);
	if ( defined $LoxBerry::System::lbsdatadir and $LoxBerry::System::lbsdatadir ne '' ) {
		return "$LoxBerry::System::lbsdatadir/tokens.json";
	}
	return "$ENV{LBSDATA}/tokens.json" if ($ENV{LBSDATA});
	return undef;
}

sub _store_decode
{
	my ($content) = @_;
	return {} if (!defined $content or $content !~ /\S/);
	my $data;
	eval { $data = JSON::from_json($content); };
	if ($@ or ref($data) ne 'HASH') {
		print STDERR "LoxBerry::Auth: tokens.json is not readable JSON - starting empty\n" if ($DEBUG);
		return {};
	}
	return $data;
}

sub _store_encode
{
	my ($data) = @_;
	return JSON->new->pretty->canonical(1)->encode($data);
}

# Read the full store under a shared lock. A missing file is an empty store
# and is NOT created here.
sub _store_read
{
	my $file = _store_file();
	return {} if (!$file or ! -e $file);
	my $fh;
	if ( ! CORE::open($fh, '<', $file) ) {
		print STDERR "LoxBerry::Auth: cannot open $file: $!\n" if ($DEBUG);
		return {};
	}
	flock($fh, LOCK_SH);
	my $content = do { local $/; <$fh> };
	close($fh);
	return _store_decode($content);
}

# Read-modify-write under ONE exclusive lock. The callback gets the decoded
# store and mutates it in place. Written only when the content really changed.
# Returns 1 = written, 0 = unchanged, undef = error.
sub _store_update
{
	my ($cb) = @_;
	my $file = _store_file();
	if (!$file) {
		print STDERR "LoxBerry::Auth: no token store path available\n" if ($DEBUG);
		return undef;
	}

	my $fh;
	if ( ! sysopen($fh, $file, O_RDWR | O_CREAT, 0600) ) {
		print STDERR "LoxBerry::Auth: cannot open $file: $!\n" if ($DEBUG);
		return undef;
	}
	if ( ! flock($fh, LOCK_EX) ) {
		print STDERR "LoxBerry::Auth: cannot lock $file: $!\n" if ($DEBUG);
		close($fh);
		return undef;
	}

	my $content = do { local $/; <$fh> };
	my $data    = _store_decode($content);
	my $before  = _store_encode($data);

	$cb->($data);

	my $after = _store_encode($data);
	if ($after eq $before and -s $file) {
		close($fh);
		return 0;
	}

	seek($fh, 0, 0);
	print $fh $after;
	truncate($fh, tell($fh));
	close($fh);   # releases the lock

	chmod 0600, $file;
	eval {
		my ($login, $pass, $uid, $gid) = getpwnam("loxberry");
		chown $uid, $gid, $file if (defined $uid);
	};
	return 1;
}

# Process cache: the token lives in the process, the file is pure persistence
# across restarts. Another process may change the file behind our back - the
# single 401 retry in request() is the safety net for that.
my %tokencache;

sub _cache_clear
{
	%tokencache = ();
	return 1;
}

sub _store_get_token
{
	my ($serial, $user) = @_;
	return undef if (!$serial or !$user);
	my $ck = "$serial|$user";
	return $tokencache{$ck} if (exists $tokencache{$ck});

	my $data = _store_read();
	return undef if (! exists $data->{$serial});
	my $tok = $data->{$serial}{users}{$user};
	$tokencache{$ck} = $tok if ($tok);
	return $tok;
}

sub _store_put_token
{
	my ($serial, $user, $msmeta, $tokendata) = @_;
	return undef if (!$serial or !$user);
	$tokencache{"$serial|$user"} = { %$tokendata };
	return _store_update( sub {
		my ($data) = @_;
		$data->{$serial} = {} if (! exists $data->{$serial});
		foreach my $k (keys %$msmeta) {
			$data->{$serial}{$k} = $msmeta->{$k};
		}
		$data->{$serial}{users} = {} if (! exists $data->{$serial}{users});
		$data->{$serial}{users}{$user} = { %$tokendata };
		return;
	} );
}

sub _store_del_token
{
	my ($serial, $user) = @_;
	return undef if (!$serial or !$user);
	delete $tokencache{"$serial|$user"};
	return _store_update( sub {
		my ($data) = @_;
		delete $data->{$serial}{users}{$user} if (exists $data->{$serial});
		return;
	} );
}

##################################################################
# Miniserver resolution
##################################################################

sub _ms_baseurl
{
	my ($msc) = @_;
	return undef if (!$msc);
	my $transport = $msc->{Transport} ? $msc->{Transport} : 'http';
	my $port = ($transport eq 'https') ? $msc->{PortHttps} : $msc->{Port};
	$port = ($transport eq 'https') ? 443 : 80 if (!$port);
	my $ip = $msc->{IPAddress};
	$ip = "[$ip]" if (index($ip, ':') != -1);
	return "$transport://$ip:$port";
}

# Accepts a Miniserver number or a serial number. A serial is resolved through
# the token store, which remembers which number it belonged to.
# Without the user option the credentials from general.json are used. With a
# user but without a password the password stays undef on purpose - the
# password from general.json belongs to that user and to no other.
sub _resolve_ms
{
	my ($ms, %opts) = @_;
	return _err('msnotfound', 'No Miniserver given') if (!defined $ms or $ms eq '');

	my $serial;
	my $msnr;
	if ($ms =~ /^\d+$/) {
		$msnr = $ms;
	} else {
		$serial = uc($ms);
		my $data = _store_read();
		if ( exists $data->{$serial} and defined $data->{$serial}{msnr} ) {
			$msnr = $data->{$serial}{msnr};
		}
		if (!defined $msnr) {
			return _err('msnotfound',
				"Serial $ms is unknown - fetch a token for this Miniserver first");
		}
	}

	my %miniservers = LoxBerry::System::get_miniservers();
	my $msc = $miniservers{$msnr};
	return _err('msnotfound', "Miniserver $ms is not configured") if (!$msc);

	my $user     = defined $opts{user} ? $opts{user} : $msc->{Admin_RAW};
	my $password = defined $opts{password} ? $opts{password}
	             : ( defined $opts{user} ? undef : $msc->{Pass_RAW} );

	return {
		ok            => 1,
		msnr          => $msnr,
		name          => $msc->{Name},
		baseurl       => _ms_baseurl($msc),
		user          => $user,
		password      => $password,
		serial        => $serial,
		is_lbsystem   => 1,
		lbsystem_user => $msc->{Admin_RAW},
	};
}

##################################################################
# general.json: Authmethod (read only - never written by this lib)
##################################################################

sub auth_method
{
	my ($ms) = @_;
	return 'basicauth' if (!defined $ms or $ms eq '');

	my $msnr = $ms;
	if ($ms !~ /^\d+$/) {
		my $data = _store_read();
		my $serial = uc($ms);
		$msnr = ( exists $data->{$serial} ) ? $data->{$serial}{msnr} : undef;
		return 'basicauth' if (!defined $msnr);
	}

	my $cfg;
	eval {
		$cfg = JSON::from_json(
			LoxBerry::System::read_file("$LoxBerry::System::lbsconfigdir/general.json") );
	};
	return 'basicauth' if ($@ or ref($cfg) ne 'HASH');

	my $val = $cfg->{Miniserver}{$msnr}{Authmethod};
	return 'token' if (defined $val and lc($val) eq 'token');
	return 'basicauth';
}

##################################################################
# HTTP transport
# Verified on Miniserver 17.1.7.3: jdev/cfg/api and jdev/sys/getkey2
# answer without any authentication. Only killtoken needs Basic Auth.
##################################################################

# Test hook: replaced by the unit tests.
# sub ($url, %opts) -> ($code, $body, $statusline); $code undef = no connection
our $transport;

sub _http_get
{
	my ($url, %opts) = @_;
	require LWP::UserAgent;
	my $ua = LWP::UserAgent->new(
		timeout  => $opts{timeout} ? $opts{timeout} : $TIMEOUT,
		ssl_opts => { verify_hostname => 0, SSL_verify_mode => 0 },
	);
	my @headers;
	if ( defined $opts{basicauth_user} ) {
		require MIME::Base64;
		my $pw = defined $opts{basicauth_password} ? $opts{basicauth_password} : '';
		push @headers, 'Authorization' => 'Basic '
			. MIME::Base64::encode_base64( $opts{basicauth_user} . ':' . $pw, '' );
	}
	my $resp = $ua->get($url, @headers);
	# LWP fakes a 500 when the connection never happened - tell that apart
	my $cw = $resp->header('Client-Warning');
	if ( defined $cw and $cw eq 'Internal response' ) {
		return (undef, undef, $resp->status_line);
	}
	return ($resp->code, $resp->decoded_content, $resp->status_line);
}

sub _call
{
	my ($url, %opts) = @_;
	my $t = $transport ? $transport : \&_http_get;
	print STDERR "LoxBerry::Auth: GET $url\n" if ($DEBUG);
	return $t->($url, %opts);
}

# The LL envelope. value is a hashref for most endpoints and a string for
# jdev/cfg/api. A non-JSON body (the Miniserver answers 401 in HTML) is undef.
sub _ll_value
{
	my ($body) = @_;
	return undef if (!defined $body or $body !~ /\S/);
	my $j;
	eval { $j = JSON::from_json($body); };
	return undef if ($@ or ref($j) ne 'HASH' or ref($j->{LL}) ne 'HASH');
	return $j->{LL}{value};
}

# The LL envelope carries its OWN status code, and the Miniserver does not
# always mirror it into the HTTP status: refreshjwt answers HTTP 200 with
# LL.code 401 when the token signature is not accepted. Measured on 17.1.7.3.
# The field is spelled "Code" by some endpoints (jdev/cfg/api) and "code" by
# others (jdev/sys/*), so both are read.
sub _ll_code
{
	my ($body) = @_;
	return undef if (!defined $body or $body !~ /\S/);
	my $j;
	eval { $j = JSON::from_json($body); };
	return undef if ($@ or ref($j) ne 'HASH' or ref($j->{LL}) ne 'HASH');
	my $c = defined $j->{LL}{code} ? $j->{LL}{code} : $j->{LL}{Code};
	return undef if (!defined $c or $c !~ /^\d+$/);
	return int($c);
}

# The code that really decides: an HTTP 200 carrying a different LL code is a
# failure, not a success.
sub _effective_code
{
	my ($code, $body) = @_;
	return $code if (!defined $code or $code != 200);
	my $ll = _ll_code($body);
	return $ll if (defined $ll and $ll != 200);
	return $code;
}

# Stable per host and user, so the Miniserver does not collect a new client
# entry on every call. Never persisted - it is derived, not stored.
sub _client_uuid
{
	my ($user) = @_;
	my $seed = LoxBerry::System::lbhostname() . '|' . $user . '|loxberry-auth';
	my $h = Digest::SHA::sha256_hex($seed);
	return join('-', substr($h,0,8), substr($h,8,4), substr($h,12,4),
	                 substr($h,16,4), substr($h,20,12));
}

##################################################################
# Miniserver identity: serial + firmware in one call
##################################################################

sub _ms_api
{
	my ($res, %opts) = @_;
	my ($code, $body) = _call($res->{baseurl} . '/jdev/cfg/api', %opts);
	return _err('unreachable', "$res->{baseurl} did not answer") if (!defined $code);
	$code = _effective_code($code, $body);
	return _err('httperror', "jdev/cfg/api returned $code") if ($code != 200);

	my $api = _parse_api_value( _ll_value($body) );
	return _err('parseerror', 'jdev/cfg/api could not be parsed') if (!$api);
	return _err('parseerror', 'jdev/cfg/api has no serial') if (!$api->{snr});

	return { ok => 1, serial => uc($api->{snr}), firmware => $api->{version} };
}

sub _getkey2
{
	my ($res, $user, %opts) = @_;
	my $url = $res->{baseurl} . '/jdev/sys/getkey2/' . URI::Escape::uri_escape($user);
	my ($code, $body) = _call($url, %opts);
	return _err('unreachable', "$res->{baseurl} did not answer") if (!defined $code);
	$code = _effective_code($code, $body);
	return _err('badcredentials', "getkey2 returned $code for user $user") if ($code == 401);
	return _err('httperror', "getkey2 returned $code") if ($code != 200);

	my $v = _ll_value($body);
	return _err('parseerror', 'getkey2 could not be parsed') if (ref($v) ne 'HASH');
	my $alg = _norm_alg( $v->{hashAlg} );
	return _err('parseerror', "getkey2 returned an unknown hashAlg") if (!$alg);
	return { ok => 1, key => $v->{key}, salt => $v->{salt}, alg => $alg };
}

# The serial of a Miniserver number, as far as an earlier run persisted it.
# Looking it up here keeps get_token free of HTTP when a token is cached -
# without it every single call would have to ask jdev/cfg/api first.
sub _serial_from_store
{
	my ($msnr) = @_;
	my $data = _store_read();
	foreach my $s ( sort keys %$data ) {
		next if ( !defined $data->{$s}{msnr} or $data->{$s}{msnr} ne $msnr );
		return ( $s, $data->{$s}{firmware} );
	}
	return (undef, undef);
}

# Like _resolve_ms, but an unknown serial makes every configured Miniserver be
# asked for its own serial. That is the only way a serial can enter the store.
sub _resolve_ms_probing
{
	my ($ms, %opts) = @_;
	my $res = _resolve_ms($ms, %opts);
	return $res if ( $res->{ok} );
	return $res if ( $ms =~ /^\d+$/ );

	my $want = uc($ms);
	my %miniservers = LoxBerry::System::get_miniservers();
	foreach my $msnr ( sort { $a <=> $b } keys %miniservers ) {
		my $cand = _resolve_ms($msnr, %opts);
		next if (! $cand->{ok});
		my $api = _ms_api($cand, %opts);
		next if (! $api->{ok});
		next if ( $api->{serial} ne $want );
		$cand->{serial}   = $want;
		$cand->{firmware} = $api->{firmware};
		return $cand;
	}
	return _err('msnotfound', "No configured Miniserver has serial $ms");
}

##################################################################
# get_token
##################################################################

sub get_token
{
	my ($ms, %opts) = @_;

	my $res = _resolve_ms_probing($ms, %opts);
	return $res if (! $res->{ok});

	my $user = $res->{user};
	return _err('nocredentials', "No user for Miniserver $ms") if (!$user);

	my $perm = defined $opts{perm} ? int($opts{perm}) : $DEFAULT_PERM;

	# The serial is stable and may come from the store - that is what keeps a
	# cached token completely free of HTTP.
	my $serial   = $res->{serial};
	my $firmware = $res->{firmware};
	if (!$serial) {
		my ($s, $f) = _serial_from_store( $res->{msnr} );
		$serial   = $s;
		$firmware = $f if (!$firmware);
	}

	# Cached token, unless force
	if (! $opts{force} and $serial) {
		my $have = _store_get_token($serial, $user);
		if ( $have and $have->{token} and _rights_granted($have->{rights}, $perm) ) {
			return {
				ok         => 1,
				token      => $have->{token},
				validUntil => $have->{validUntil},
				rights     => $have->{rights},
				perm       => $have->{perm},
				user       => $user,
				serial     => $serial,
				firmware   => $firmware,
				msnr       => $res->{msnr},
			};
		}
	}

	# Without a password nothing can be fetched - check that before bothering
	# the Miniserver with a single request.
	my $password = $res->{password};
	return _err('nocredentials', "No password available for user $user")
		if (!defined $password or $password eq '');

	# From here on a token is really fetched. The firmware decides whether that
	# is allowed at all, and unlike the serial it changes with every Miniserver
	# update - so it is never taken from the store, always asked fresh.
	if (! defined $res->{firmware}) {
		my $api = _ms_api($res, %opts);
		return $api if (! $api->{ok});
		$serial   = $api->{serial};
		$firmware = $api->{firmware};
	}

	return _err('fwtooold',
		"Miniserver firmware $firmware is below $MIN_FIRMWARE - tokens would need application encryption")
		if (! _fw_supported($firmware));

	my $k = _getkey2($res, $user, %opts);
	return $k if (! $k->{ok});

	my $pwhash   = _pw_hash($password, $k->{salt}, $k->{alg});
	my $authhash = _auth_hash($user, $pwhash, $k->{key}, $k->{alg});
	my $info     = defined $opts{info} ? $opts{info} : 'LoxBerry ' . LoxBerry::System::lbhostname();

	my $url = $res->{baseurl} . '/jdev/sys/gettoken/'
	        . $authhash . '/'
	        . URI::Escape::uri_escape($user) . '/'
	        . $perm . '/'
	        . _client_uuid($user) . '/'
	        . URI::Escape::uri_escape($info);

	my ($code, $body) = _call($url, %opts);
	return _err('unreachable', "$res->{baseurl} did not answer") if (!defined $code);
	$code = _effective_code($code, $body);
	# A wrong user or password shows up here, NOT at getkey2 - getkey2 answers
	# 200 even for a user that does not exist.
	return _err('badcredentials', "gettoken returned 401 for user $user") if ($code == 401);
	return _err('httperror', "gettoken returned $code") if ($code != 200);

	my $v = _ll_value($body);
	return _err('parseerror', 'gettoken could not be parsed') if (ref($v) ne 'HASH' or !$v->{token});

	if (! _rights_granted($v->{tokenRights}, $perm)) {
		return _err('missingright',
			sprintf("Miniserver granted rights %s, which does not include the requested permission %d (0x%x)",
			        $v->{tokenRights}, $perm, $perm));
	}

	my %tokendata = (
		token      => $v->{token},
		validUntil => $v->{validUntil},
		rights     => $v->{tokenRights},
		perm       => $perm,
		acquired   => LoxBerry::System::epoch2lox(),
		info       => $info,
	);
	_store_put_token( $serial, $user, {
		msnr          => $res->{msnr},
		name          => $res->{name},
		is_lbsystem   => $res->{is_lbsystem},
		lbsystem_user => $res->{lbsystem_user},
		firmware      => $firmware,
		checked       => LoxBerry::System::epoch2lox(),
	}, \%tokendata );

	return { ok => 1, %tokendata, user => $user, serial => $serial,
	         firmware => $firmware, msnr => $res->{msnr} };
}
##################################################################
# token_info / refresh_token / kill_token / request
##################################################################

# Everything the store knows, plus the remaining lifetime in seconds.
# No HTTP unless the serial still has to be resolved.
sub token_info
{
	my ($ms, %opts) = @_;
	my $res = _resolve_ms_probing($ms, %opts);
	return $res if (! $res->{ok});

	my $serial = $res->{serial};
	my $data   = _store_read();
	if (! $serial) {
		# find the serial belonging to this Miniserver number
		foreach my $s ( sort keys %$data ) {
			next if ( !defined $data->{$s}{msnr} or $data->{$s}{msnr} ne $res->{msnr} );
			$serial = $s;
			last;
		}
	}
	return _err('notoken', "No token stored for Miniserver $ms") if (!$serial);

	my $have = $data->{$serial}{users}{ $res->{user} };
	return _err('notoken', "No token stored for user $res->{user}") if (!$have or !$have->{token});

	return {
		ok         => 1,
		token      => $have->{token},
		validUntil => $have->{validUntil},
		rights     => $have->{rights},
		perm       => $have->{perm},
		info       => $have->{info},
		user       => $res->{user},
		serial     => $serial,
		msnr       => $res->{msnr},
		firmware   => $data->{$serial}{firmware},
		expires_in => int($have->{validUntil}) - LoxBerry::System::epoch2lox(),
	};
}

# refreshjwt works with token authentication only - no password involved.
# The endpoint answers with a JWT (eyJ0eXAi...) instead of the hex token; both
# formats are handled the same way from here on.
sub refresh_token
{
	my ($ms, %opts) = @_;
	my $have = token_info($ms, %opts);
	return $have if (! $have->{ok});

	my $res = _resolve_ms_probing($ms, %opts);
	return $res if (! $res->{ok});

	my $k = _getkey2($res, $have->{user}, %opts);
	return $k if (! $k->{ok});
	my $hash = _token_hash($have->{token}, $k->{key}, $k->{alg});

	# The path carries the token HASH, autht the PLAIN token. Measured on
	# 17.1.7.3: hashing both consumes the one-time key twice and the Miniserver
	# answers HTTP 200 with LL.code 401.
	my $url = $res->{baseurl} . '/jdev/sys/refreshjwt/' . $hash . '/'
	        . URI::Escape::uri_escape($have->{user})
	        . '?autht=' . URI::Escape::uri_escape($have->{token})
	        . '&user=' . URI::Escape::uri_escape($have->{user});

	my ($code, $body) = _call($url, %opts);
	return _err('unreachable', "$res->{baseurl} did not answer") if (!defined $code);
	$code = _effective_code($code, $body);
	return _err('revoked', "refreshjwt returned 401 - the token was not accepted")
		if ($code == 401);
	return _err('httperror', "refreshjwt returned $code") if ($code != 200);

	my $v = _ll_value($body);
	return _err('parseerror', 'refreshjwt could not be parsed') if (ref($v) ne 'HASH' or !$v->{token});

	my %tokendata = (
		token      => $v->{token},
		validUntil => $v->{validUntil},
		rights     => defined $v->{tokenRights} ? $v->{tokenRights} : $have->{rights},
		perm       => $have->{perm},
		acquired   => LoxBerry::System::epoch2lox(),
		info       => $have->{info},
	);
	_store_put_token( $have->{serial}, $have->{user},
		{ msnr => $res->{msnr}, checked => LoxBerry::System::epoch2lox() }, \%tokendata );

	return { ok => 1, %tokendata, user => $have->{user}, serial => $have->{serial},
	         firmware => $have->{firmware}, msnr => $res->{msnr} };
}

# Revoking needs the password: killtoken was measured to work with Basic Auth
# only, not with token authentication.
sub kill_token
{
	my ($ms, %opts) = @_;
	my $have = token_info($ms, %opts);
	return $have if (! $have->{ok});

	my $res = _resolve_ms_probing($ms, %opts);
	return $res if (! $res->{ok});
	return _err('nopassword', "kill_token needs the password of user $have->{user}")
		if (!defined $res->{password} or $res->{password} eq '');

	my $k = _getkey2($res, $have->{user}, %opts);
	return $k if (! $k->{ok});
	my $hash = _token_hash($have->{token}, $k->{key}, $k->{alg});

	my $url = $res->{baseurl} . '/jdev/sys/killtoken/' . $hash . '/'
	        . URI::Escape::uri_escape($have->{user});

	my ($code, $body) = _call($url, %opts,
		basicauth_user     => $have->{user},
		basicauth_password => $res->{password} );
	return _err('unreachable', "$res->{baseurl} did not answer") if (!defined $code);
	$code = _effective_code($code, $body);
	return _err('badcredentials', "killtoken returned 401") if ($code == 401);
	return _err('httperror', "killtoken returned $code") if ($code != 200);

	_store_del_token( $have->{serial}, $have->{user} );
	return { ok => 1, user => $have->{user}, serial => $have->{serial} };
}

sub _sign_url
{
	my ($baseurl, $command, $token, $user, $res, %opts) = @_;
	my $k = _getkey2($res, $user, %opts);
	return (undef, $k) if (! $k->{ok});
	my $hash = _token_hash($token, $k->{key}, $k->{alg});
	my $sep = ( index($command, '?') != -1 ) ? '&' : '?';
	return ( $baseurl . $command . $sep . 'autht=' . $hash
	         . '&user=' . URI::Escape::uri_escape($user), undef );
}

# Runs a Miniserver command with token authentication.
# Returns ($content, \%info) - same keys as LoxBerry::IO::mshttp_call2, plus
# errcode carrying the error code of this lib.
sub request
{
	my ($ms, $command, %opts) = @_;
	my %info = ( code => undef, status => undef, error => 1, message => '', errcode => undef );

	my $tok = get_token($ms, %opts);
	if (! $tok->{ok}) {
		$info{errcode} = $tok->{error};
		$info{message} = $tok->{message};
		return (undef, \%info);
	}

	# expired -> new token; below the threshold -> renew without a password
	my $left = int($tok->{validUntil}) - LoxBerry::System::epoch2lox();
	if ($left <= 0) {
		$tok = get_token($ms, %opts, force => 1);
	} elsif ($left < $REFRESH_THRESHOLD) {
		my $r = refresh_token($ms, %opts);
		$tok = $r if ( $r->{ok} );
	}
	if (! $tok->{ok}) {
		$info{errcode} = $tok->{error};
		$info{message} = $tok->{message};
		return (undef, \%info);
	}

	my $res = _resolve_ms_probing($ms, %opts);
	if (! $res->{ok}) {
		$info{errcode} = $res->{error};
		$info{message} = $res->{message};
		return (undef, \%info);
	}

	foreach my $attempt (1, 2) {
		my ($url, $urlerr) = _sign_url($res->{baseurl}, $command, $tok->{token},
		                               $tok->{user}, $res, %opts);
		if (!$url) {
			$info{errcode} = $urlerr->{error};
			$info{message} = $urlerr->{message};
			return (undef, \%info);
		}

		my ($code, $body, $status) = _call($url, %opts);
		if (!defined $code) {
			$info{errcode} = 'unreachable';
			$info{message} = "$res->{baseurl} did not answer";
			return (undef, \%info);
		}

		$code = _effective_code($code, $body);
		$info{code}   = $code;
		$info{status} = $status;

		if ($code == 401) {
			# The token may have been deleted on the Miniserver although
			# validUntil still looks fine. Fetch a new one and retry ONCE.
			if ($attempt == 1) {
				my $fresh = get_token($ms, %opts, force => 1);
				if ($fresh->{ok}) {
					$tok = $fresh;
					next;
				}
				$info{errcode} = $fresh->{error};
				$info{message} = $fresh->{message};
				return (undef, \%info);
			}
			$info{errcode} = 'revoked';
			$info{message} = "$command returned 401 twice - the token was revoked";
			return (undef, \%info);
		}

		if ($code < 200 or $code >= 300) {
			$info{errcode} = 'httperror';
			$info{message} = "$command FAILED - Error $code";
			return (undef, \%info);
		}

		$info{error}   = 0;
		$info{message} = 'Request ok';
		return ($body, \%info);
	}
}

#####################################################
# Finally 1; ########################################
#####################################################
1;
