#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);
use FindBin;
use lib "$FindBin::Bin/..";
use LoxBerry::WebLogin;

my $dir = tempdir(CLEANUP => 1);
chmod 0700, $dir;
my $users = "$dir/htusers";
open my $fh, '>', $users or die $!;
print {$fh} "admin:example-hash\n";
close $fh;
my $now = 10000;
my $db = LoxBerry::WebLogin->new(state => $dir, users => $users, now => sub { $now });
my ($anon, $pre) = $db->create_session;
like($anon, qr/\A[0-9a-f]{64}\z/, '256-bit random session ID');
is($db->session($anon)->{user}, '', 'anonymous session cannot access admin');
ok(!$db->consume_login($anon, 'wrong'), 'login CSRF rejected');
ok($db->consume_login($anon, $pre->{csrf}), 'login CSRF accepted');
ok(!$db->consume_login($anon, $pre->{csrf}), 'anonymous session consumed once');
ok(!$db->session($anon), 'anonymous cookie invalidated');
my ($token, $s) = $db->create_session('admin');
isnt($token, $anon, 'ID rotated after authentication');
isnt($s->{id}, $token, 'database stores digest rather than bearer token');
is($db->session($token)->{user}, 'admin', 'valid session works');
ok(!$db->session('a' x 64), 'forged cookie rejected');
ok(!$db->session('../sessions.sqlite'), 'invalid cookie rejected');
ok(!$db->session(undef), 'missing cookie rejected');
ok(!$db->session($token . 'x'), 'oversized cookie rejected');
$now += 1800;
ok(!$db->session($token), 'idle session expires');
($token, $s) = $db->create_session('admin');
for (1..31) { $now += 900; ok($db->session($token), 'activity keeps idle session alive') }
$now += 900;
ok(!$db->session($token), 'absolute eight-hour limit applies despite activity');
($token, $s) = $db->create_session('admin');
$db->revoke($token);
ok(!$db->session($token), 'logout invalidates server-side session');
($token, $s) = $db->create_session('admin');
open $fh, '>', $users or die $!; print {$fh} "admin:new-hash\n"; close $fh;
ok(!$db->session($token), 'password change invalidates sessions');
($token, $s) = $db->create_session('admin');
open $fh, '>', $users or die $!; print {$fh} "renamed:new-hash\n"; close $fh;
ok(!$db->session($token), 'username change invalidates sessions');
eval { $db->create_session('renamed', 'stale fingerprint') };
like($@, qr/Credentials changed/, 'credential change during login fails closed');
ok(LoxBerry::WebLogin::constant_equal('abc', 'abc'), 'equal comparison');
ok(!LoxBerry::WebLogin::constant_equal('abc', 'abd'), 'different comparison');
ok(!LoxBerry::WebLogin::constant_equal('abc', undef), 'undefined comparison');
for (1..10) { ok($db->allow_attempt('192.0.2.1', 'admin'), 'allowed within user rate limit') }
ok(!$db->allow_attempt('192.0.2.2', 'admin'), 'user rate limit spans IPs');
for (1..30) { ok($db->allow_attempt('192.0.2.3', "user$_"), 'allowed within IP rate limit') }
ok(!$db->allow_attempt('192.0.2.3', 'other'), 'IP rate limit spans users');
$now += 300;
ok($db->allow_attempt('192.0.2.1', 'admin'), 'rate limit resets');
is(LoxBerry::WebLogin::safe_return('/auth/plugins/a/index.cgi?q=1'), '/auth/plugins/a/index.cgi?q=1', 'plugin deep link preserved');
for my $bad ('https://evil.example/', '//evil.example/', '/\\evil.example/', '/admin/\r\nX:1', '/admin/%0d%0aLocation:x', '/admin/%5cevil', '/admin/../login', '/admin/%2e%2e%2flogin', '/login', undef) {
    is(LoxBerry::WebLogin::safe_return($bad), '/admin/system/index.cgi', 'unsafe redirect replaced');
}
is((stat("$dir/sessions.sqlite"))[2] & 0777, 0600, 'private session database');
chmod 0755, $dir;
eval { LoxBerry::WebLogin->new(state => $dir, users => $users) };
like($@, qr/private/, 'unsafe state directory rejected');
done_testing;
