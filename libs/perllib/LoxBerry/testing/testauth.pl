#!/usr/bin/perl
# testauth.pl - LoxBerry::Auth against a real Miniserver.
# Runs on a live LoxBerry. Analogous to the other testing/ scripts.
#
#   perl testauth.pl [msnr|serial] [--store <path>] [--keep]
#
# Without --store the token is kept in /tmp, so the productive
# data/system/tokens.json is not touched.
# Without --keep the token is revoked at the end - the Miniserver must not
# collect orphaned tokens in its token list.

use strict;
use warnings;
use LoxBerry::System;
use LoxBerry::Auth;

my $ms    = (defined $ARGV[0] and $ARGV[0] !~ /^--/) ? shift(@ARGV) : 1;
my $keep  = 0;
my $store = "/tmp/testauth_tokens.json";
while (my $a = shift(@ARGV)) {
	$keep  = 1            if ($a eq '--keep');
	$store = shift(@ARGV) if ($a eq '--store');
}
$LoxBerry::Auth::store_file = $store;

print "Miniserver : $ms\n";
print "Token store: $store\n";
print "auth_method: " . LoxBerry::Auth::auth_method($ms) . "\n";

my $failed = 0;
sub step {
	my ($name, $res) = @_;
	if ( ref($res) eq 'HASH' and $res->{ok} ) {
		print "OK   $name\n";
		return 1;
	}
	$failed++;
	print "FAIL $name: " . ($res->{error} // '?') . " - " . ($res->{message} // '') . "\n";
	return 0;
}

print "\n=== get_token ===\n";
my $t = LoxBerry::Auth::get_token($ms, info => 'LoxBerry Auth selftest', force => 1);
if ( step('get_token', $t) ) {
	printf "     serial     : %s\n", $t->{serial};
	printf "     firmware   : %s\n", $t->{firmware};
	printf "     perm       : %d (0x%x)\n", $t->{perm}, $t->{perm};
	printf "     rights     : %d\n", $t->{rights};
	printf "     validUntil : %d (lox) = %s\n", $t->{validUntil},
	       scalar localtime( LoxBerry::System::lox2epoch($t->{validUntil}) );
	printf "     token      : %s...\n", substr($t->{token}, 0, 12);
	my $days = ( $t->{validUntil} - LoxBerry::System::epoch2lox() ) / 86400;
	printf "     lifetime   : %.1f days%s\n", $days,
	       ($days > 80 ? ' (matches the ~3 months measured for 0x104)' : ' (SHORTER THAN EXPECTED)');
	printf "     Sys-WS bit : %s\n",
	       LoxBerry::Auth::_rights_granted($t->{rights}, $LoxBerry::Auth::PERM_SYSWS)
	       ? 'granted - reboot would be allowed' : 'MISSING';
}

print "\n=== token_info ===\n";
my $ti = LoxBerry::Auth::token_info($ms);
step('token_info', $ti);
printf "     expires_in : %d s\n", $ti->{expires_in} if ($ti->{ok});

print "\n=== request /jdev/cfg/version ===\n";
my ($content, $info) = LoxBerry::Auth::request($ms, '/jdev/cfg/version');
if ( $info->{error} == 0 ) {
	print "OK   request (code $info->{code})\n";
	print "     $content\n";
} else {
	$failed++;
	print "FAIL request: " . ($info->{errcode} // '?') . " - $info->{message}\n";
}

print "\n=== request twice: the one-time key must be fetched again ===\n";
my (undef, $info2) = LoxBerry::Auth::request($ms, '/jdev/cfg/version');
if ( $info2->{error} == 0 ) {
	print "OK   second request (code $info2->{code})\n";
} else {
	$failed++;
	print "FAIL second request: " . ($info2->{errcode} // '?') . " - $info2->{message}\n";
}

print "\n=== refresh_token (password free) ===\n";
my $rt = LoxBerry::Auth::refresh_token($ms);
if ( step('refresh_token', $rt) ) {
	printf "     token      : %s...\n", substr($rt->{token}, 0, 12);
	printf "     format     : %s\n", ($rt->{token} =~ /^eyJ/) ? 'JWT' : 'hex';
	printf "     validUntil : %d\n", $rt->{validUntil};
}

print "\n=== request with the refreshed token ===\n";
my (undef, $info3) = LoxBerry::Auth::request($ms, '/jdev/cfg/version');
if ( $info3->{error} == 0 ) {
	print "OK   request after refresh (code $info3->{code})\n";
} else {
	$failed++;
	print "FAIL request after refresh: " . ($info3->{errcode} // '?') . " - $info3->{message}\n";
}

print "\n=== cleanup: kill_token ===\n";
if ($keep) {
	print "SKIP --keep given - the token stays on the Miniserver\n";
} else {
	my $kt = LoxBerry::Auth::kill_token($ms);
	step('kill_token', $kt);
	my $after = LoxBerry::Auth::token_info($ms);
	if ( !$after->{ok} and $after->{error} eq 'notoken' ) {
		print "OK   store entry removed\n";
	} else {
		$failed++;
		print "FAIL store entry still present\n";
	}
	my (undef, $info4) = LoxBerry::Auth::request($ms, '/jdev/cfg/version');
	print "     request after kill: code="
	    . (defined $info4->{code} ? $info4->{code} : 'none')
	    . " errcode=" . ($info4->{errcode} // 'none')
	    . " (a fresh token is fetched automatically - that is correct)\n";
	# the automatically re-fetched token has to go as well
	LoxBerry::Auth::kill_token($ms);
}

print "\n" . ($failed ? "$failed STEP(S) FAILED\n" : "ALL STEPS OK\n");
exit( $failed ? 1 : 0 );
