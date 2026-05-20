#!/usr/bin/perl
# Test script for log_maint.pl cleanup behavior
# Tests: LoxBerry::Log with/without LOGEND, arbitrary files, system + plugin paths

use strict;
use warnings;
use LoxBerry::System;
use LoxBerry::Log;
use DBI;
use File::Find::Rule;
use POSIX qw(strftime);

my $lbhomedir = $LoxBerry::System::lbhomedir;
my $sys_logdir  = "$lbhomedir/log/system_tmpfs";
my $plug_logdir = "$lbhomedir/log/plugins/weather4lox";
my $logdb       = "$lbhomedir/log/system_tmpfs/logs_sqlite.dat";
my $log_maint   = "$lbhomedir/sbin/log_maint.pl";

my $N = 1000;  # files per scenario

# ─────────────────────────────────────────────────────────────
# Helper: count files
sub count_files {
    my ($dir, $pat) = @_;
    return scalar File::Find::Rule->file()->name($pat)->in($dir);
}

# Helper: count DB entries for a package
sub count_db {
    my ($pkg) = @_;
    my $dbh = DBI->connect("dbi:SQLite:dbname=$logdb", '', '', { RaiseError=>0, PrintError=>0 }) or return -1;
    my ($n) = $dbh->selectrow_array("SELECT COUNT(*) FROM logs WHERE PACKAGE=?", undef, $pkg);
    $dbh->disconnect;
    return $n // 0;
}

# Helper: count all DB entries
sub count_db_total {
    my $dbh = DBI->connect("dbi:SQLite:dbname=$logdb", '', '', { RaiseError=>0, PrintError=>0 }) or return -1;
    my ($n) = $dbh->selectrow_array("SELECT COUNT(*) FROM logs");
    $dbh->disconnect;
    return $n // 0;
}

sub section { print "\n" . "=" x 70 . "\n$_[0]\n" . "=" x 70 . "\n" }
sub ok   { printf "  [PASS] %s\n", $_[0] }
sub fail { printf "  [FAIL] %s\n", $_[0] }
sub info { printf "  [INFO] %s\n", $_[0] }

sub check {
    my ($label, $got, $op, $expected) = @_;
    my $pass;
    $pass = ($got == $expected)  if $op eq '==';
    $pass = ($got <= $expected)  if $op eq '<=';
    $pass = ($got >= $expected)  if $op eq '>=';
    $pass = ($got == 0)          if $op eq 'zero';
    if ($pass) { ok  "$label: $got $op $expected" }
    else       { fail "$label: got $got, expected $op $expected" }
}

# ─────────────────────────────────────────────────────────────
section("INITIAL STATE");
my $db_before = count_db_total();
my $sys_log_before  = count_files($sys_logdir,  '*.log') + count_files($sys_logdir,  '*.log.gz');
my $plug_log_before = count_files($plug_logdir, '*.log') + count_files($plug_logdir, '*.log.gz');
info "DB entries total: $db_before";
info "system_tmpfs .log/.gz files: $sys_log_before";
info "weather4lox  .log/.gz files: $plug_log_before";

# ─────────────────────────────────────────────────────────────
section("CREATING TEST DATA ($N files per scenario)");

# 1. System logs WITH LOGEND (same package+name → logdb count limit applicable)
print "  Creating $N system logs WITH LOGEND...\n";
for my $i (1..$N) {
    my $log = LoxBerry::Log->new(
        package  => 'test_sys_logend',
        name     => 'syslogtest',
        logdir   => $sys_logdir,
        loglevel => 3,
        addtime  => 0,
    );
    $log->LOGSTART("Systemtest WITH LOGEND #$i");
    $log->INF("Test entry $i");
    $log->LOGEND;
    print "    $i/$N\r" if $i % 100 == 0;
}
print "  Done.\n";

# 2. System logs WITHOUT LOGEND
print "  Creating $N system logs WITHOUT LOGEND...\n";
for my $i (1..$N) {
    my $log = LoxBerry::Log->new(
        package  => 'test_sys_nologend',
        name     => 'syslogtest',
        logdir   => $sys_logdir,
        loglevel => 3,
        addtime  => 0,
    );
    $log->LOGSTART("Systemtest WITHOUT LOGEND #$i");
    $log->INF("Test entry $i");
    # intentionally no LOGEND
    print "    $i/$N\r" if $i % 100 == 0;
}
print "  Done.\n";

# 3. Arbitrary files in system log dir (not via Log lib, no DB entry)
print "  Creating $N arbitrary .log files in system_tmpfs...\n";
for my $i (1..$N) {
    open(my $fh, '>', "$sys_logdir/test_arbitrary_sys_$i.log") or warn "Cannot create: $!";
    print $fh "Arbitrary system test file $i - no DB entry\n";
    close($fh);
    print "    $i/$N\r" if $i % 100 == 0;
}
print "  Done.\n";

# 4. Plugin logs (weather4lox) WITH LOGEND
print "  Creating $N plugin logs (weather4lox) WITH LOGEND...\n";
for my $i (1..$N) {
    my $log = LoxBerry::Log->new(
        package  => 'test_plug_logend',
        name     => 'pluglogtest',
        logdir   => $plug_logdir,
        loglevel => 3,
        addtime  => 0,
    );
    $log->LOGSTART("Plugin test WITH LOGEND #$i");
    $log->INF("Test entry $i");
    $log->LOGEND;
    print "    $i/$N\r" if $i % 100 == 0;
}
print "  Done.\n";

# 5. Plugin logs WITHOUT LOGEND
print "  Creating $N plugin logs (weather4lox) WITHOUT LOGEND...\n";
for my $i (1..$N) {
    my $log = LoxBerry::Log->new(
        package  => 'test_plug_nologend',
        name     => 'pluglogtest',
        logdir   => $plug_logdir,
        loglevel => 3,
        addtime  => 0,
    );
    $log->LOGSTART("Plugin test WITHOUT LOGEND #$i");
    $log->INF("Test entry $i");
    # intentionally no LOGEND
    print "    $i/$N\r" if $i % 100 == 0;
}
print "  Done.\n";

# 6. Arbitrary files in plugin log dir
print "  Creating $N arbitrary .log files in weather4lox...\n";
for my $i (1..$N) {
    open(my $fh, '>', "$plug_logdir/test_arbitrary_plug_$i.log") or warn "Cannot create: $!";
    print $fh "Arbitrary plugin test file $i - no DB entry\n";
    close($fh);
    print "    $i/$N\r" if $i % 100 == 0;
}
print "  Done.\n";

# ─────────────────────────────────────────────────────────────
section("STATE AFTER CREATION");
my $sys_after_create  = count_files($sys_logdir,  '*.log') + count_files($sys_logdir,  '*.log.gz');
my $plug_after_create = count_files($plug_logdir, '*.log') + count_files($plug_logdir, '*.log.gz');
my $db_logend    = count_db('test_sys_logend');
my $db_nologend  = count_db('test_sys_nologend');
my $db_plugend   = count_db('test_plug_logend');
my $db_plugnoend = count_db('test_plug_nologend');
my $db_after_create = count_db_total();

info "system_tmpfs files: $sys_after_create  (expected ~" . ($sys_log_before + 3*$N) . ")";
info "weather4lox  files: $plug_after_create (expected ~" . ($plug_log_before + 3*$N) . ")";
info "DB entries test_sys_logend:     $db_logend    (expected $N)";
info "DB entries test_sys_nologend:   $db_nologend  (expected $N)";
info "DB entries test_plug_logend:    $db_plugend   (expected $N)";
info "DB entries test_plug_nologend:  $db_plugnoend (expected $N)";
info "DB total: $db_after_create";

check("system_tmpfs file count",  $sys_after_create,  '>=', $sys_log_before + 3*$N - 5);
check("weather4lox file count",   $plug_after_create, '>=', $plug_log_before + 3*$N - 5);
check("DB entries test_sys_logend",    $db_logend,    '==', $N);
check("DB entries test_sys_nologend",  $db_nologend,  '==', $N);
check("DB entries test_plug_logend",   $db_plugend,   '==', $N);
check("DB entries test_plug_nologend", $db_plugnoend, '==', $N);

# ─────────────────────────────────────────────────────────────
section("RUNNING log_maint.pl");
print "  (this may take a moment...)\n";
my $output = qx{ cd $lbhomedir && perl $log_maint action=reduce_logfiles 2>&1 };
print "  log_maint.pl output:\n";
for my $line (split /\n/, $output) {
    next if $line =~ /^={80}$/;
    print "  | $line\n" if $line =~ /WARNING|EMERGENCY|log files|too old|dbkey|LOGSTART|LOGEND|Finished|TASK|Stage/i;
}

# ─────────────────────────────────────────────────────────────
section("STATE AFTER CLEANUP");
my $sys_after_clean  = count_files($sys_logdir,  '*.log') + count_files($sys_logdir,  '*.log.gz');
my $plug_after_clean = count_files($plug_logdir, '*.log') + count_files($plug_logdir, '*.log.gz');
my $db_logend_after    = count_db('test_sys_logend');
my $db_nologend_after  = count_db('test_sys_nologend');
my $db_plugend_after   = count_db('test_plug_logend');
my $db_plugnoend_after = count_db('test_plug_nologend');
my $db_after_clean = count_db_total();

info "system_tmpfs files after cleanup: $sys_after_clean  (before cleanup: $sys_after_create)";
info "weather4lox  files after cleanup: $plug_after_clean (before cleanup: $plug_after_create)";
info "DB entries test_sys_logend after:    $db_logend_after";
info "DB entries test_sys_nologend after:  $db_nologend_after";
info "DB entries test_plug_logend after:   $db_plugend_after";
info "DB entries test_plug_nologend after: $db_plugnoend_after";
info "DB total after: $db_after_clean (before: $db_after_create)";

# Assertions: test files should be cleaned up
check("test_sys_logend files cleaned",    $sys_after_clean,       '<=', $sys_log_before + 10);
check("weather4lox files cleaned",        $plug_after_clean,      '<=', $plug_log_before + 10);
check("DB test_sys_logend cleaned",       $db_logend_after,       '<=', 24);
check("DB test_sys_nologend cleaned",     $db_nologend_after,     '<=', 24);
check("DB test_plug_logend cleaned",      $db_plugend_after,      '<=', 24);
check("DB test_plug_nologend cleaned",    $db_plugnoend_after,    '<=', 24);
check("DB total reduced",                 $db_after_clean,        '<=', $db_before + 50);

# Verify no orphan DB entries (entries without file)
section("ORPHAN CHECK (DB entries without file on disk)");
my $dbh = DBI->connect("dbi:SQLite:dbname=$logdb", '', '', { RaiseError=>0, PrintError=>0 });
if ($dbh) {
    my $rows = $dbh->selectall_arrayref("SELECT PACKAGE, NAME, FILENAME, LOGEND FROM logs ORDER BY PACKAGE, NAME", { Slice => {} });
    my $orphans = 0;
    for my $r (@$rows) {
        next unless $r->{FILENAME};
        if (! -e $r->{FILENAME}) {
            $orphans++;
            info "Orphan: $r->{PACKAGE}/$r->{NAME} → $r->{FILENAME}";
        }
    }
    $dbh->disconnect;
    if ($orphans == 0) {
        ok "No orphan DB entries found";
    } else {
        fail "$orphans orphan DB entries (entries without file on disk)";
    }
} else {
    fail "Could not open DB for orphan check";
}

section("SUMMARY");
my $total_files_removed = ($sys_after_create - $sys_after_clean) + ($plug_after_create - $plug_after_clean);
my $total_db_removed    = $db_after_create - $db_after_clean;
info "Files removed: $total_files_removed";
info "DB entries removed: $total_db_removed";
