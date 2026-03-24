# Testing Patterns

**Analysis Date:** 2026-03-15

## Test Framework

**Runner:**
- No automated test runner configured
- No `Makefile.PL`, `prove`, `phpunit.xml`, `jest.config`, or any test harness present
- Tests are manual execution scripts that exercise live system APIs

**Assertion Library:**
- None — tests use `print` statements and visual inspection of output

**Run Commands:**
```bash
# Perl test scripts - run directly on a live LoxBerry system
perl /opt/loxberry/libs/perllib/LoxBerry/testing/testlog.pl

# PHP test scripts - run directly via PHP CLI
php /opt/loxberry/libs/phplib/testing/testlog.php

# Bash test scripts
bash /opt/loxberry/libs/bashlib/testing/testlog.sh
```

All tests require a running LoxBerry environment (`LBHOMEDIR` set, config files present).

---

## Test File Organization

**Location:**
Tests are co-located with their libraries in `testing/` subdirectories:

```
libs/
  perllib/
    LoxBerry/
      testing/           # Perl integration tests
        testlog.pl
        testsystem.pl
        testnotify.pl
        testio_http.pl
        test_general.pl
        test_plugindb_v2.pl
        ...
  phplib/
    testing/             # PHP integration tests
      testlog.php
      testlblog.php
      testnotify.php
      testgetminiservers.php
      testscript_loxberry_system.php
      ...
  bashlib/
    testing/             # Bash integration tests
      testlog.sh
      testnotify.sh
```

**Naming:**
- Pattern 1: `test<feature>.{pl|php|sh}` — e.g. `testlog.pl`, `testnotify.php`
- Pattern 2: `test_<feature>.{pl|php|sh}` — e.g. `test_general.pl`, `test_plugindb_shadow.pl`
- Both naming patterns exist; prefer `test_<feature>` for new files to match the underscore convention used in more recent tests

---

## Test Structure

**Perl test script structure:**
```perl
#!/usr/bin/perl

use LoxBerry::Log;   # Module under test
use strict;
use warnings;

# Print test section headers
print "\nTest Notification\n";
print "=================\n";
print "Documentation URL: https://wiki.loxberry.de/...\n\n";

# Setup test data
my $package = "test";
my $group   = "testing";

# Call function under test
print "TEST: Setting two info notifications\n";
notify($package, $group, "First notification");
notify($package, $group, "Error notification", 1);
print "Notifications created\n";

# Verify result manually
my ($err, $ok, $sum) = get_notification_count($package, $group);
print "We have $err errors and $ok infos, together $sum notifications.\n";

print "\nTESTS FINISHED.\n";
```

**PHP test script structure:**
```php
#!/usr/bin/env php
<?php
require_once "loxberry_system.php";   // or loxberry_log.php

// Direct API calls with printed output for manual inspection
$ms = LBSystem::get_miniservers();
if (!is_array($ms)) {
    echo "No Miniservers configured.\n";
}
foreach ($ms as $miniserver) {
    echo "Name: {$miniserver['Name']} IP: {$miniserver['IPAddress']}\n";
}
?>
```

**Bash test script structure:**
```bash
#!/bin/bash
source $LBHOMEDIR/libs/bashlib/loxberry_log.sh

PACKAGE=myplugin
NAME=TestScript
LOGDIR=$LBSLOGDIR

LOGSTART "Test started"
LOGINF "Info message"
LOGERR "Error message"
LOGEND "Test done"

# Print resulting logfile for visual inspection
echo "Logfile contents:"
cat $FILENAME
```

---

## Test Patterns

**API Smoke Tests:**
The most common pattern — call every public function and print results for visual review. No assertions:
```perl
# From testsystem.pl
print "Current Time: " . currtime() . "\n";
my %folderinfo = LoxBerry::System::diskspaceinfo('/opt/loxberry/config/system');
print "Mountpoint: $folderinfo{filesystem} | $folderinfo{used}\n";
```

**State-Change Tests:**
Verify that write operations persist:
```perl
# From test_general.pl
my $cfgobj = LoxBerry::System::General->new();
my $cfg = $cfgobj->open(writeonclose => 1);
$cfg->{Timeserver}->{TEST} = int(rand(100));
# writeonclose => 1 means it writes on $cfgobj going out of scope
```

**Lifecycle Tests:**
Create → use → verify → teardown (manual notification tests):
```perl
# Create
notify($package, $group, "message");

# Verify count
my ($err, $ok, $sum) = get_notification_count($package, $group);
print "Notifications: $err errors, $ok infos\n";

# List contents
my @notifications = get_notifications($package);
for my $n (@notifications) { print "$n->{DATESTR}: $n->{NAME}\n"; }

# Cleanup
delete_notifications($package);
```

**Debug Mode Tests:**
Modules support a `$DEBUG` flag. Tests toggle it to inspect internal flow:
```perl
# From testio_http.pl
$LoxBerry::IO::DEBUG = 1;
$LoxBerry::System::DEBUG = 1;
```

---

## Mocking

**Framework:** None

**Approach:** Tests run against a live system. There is no mocking infrastructure. Tests that require a Miniserver (e.g. `testio_http.pl`) will fail if no Miniserver is reachable.

**Environment substitution:**
Some tests work around live dependencies by setting environment variables:
```bash
export LBHOMEDIR=/opt/loxberry    # Required for all tests
```

**What IS tested against live system:**
- File I/O (reading `general.json`, plugin database, log directories)
- Network calls (Miniserver HTTP/UDP, CloudDNS, MQTT broker)
- Database operations (SQLite log session DB)
- System calls (hostname, disk info)

**What is NOT isolated:**
- Nothing is isolated — all tests are integration tests by nature

---

## Test Data

**Config fixtures:**
Tests rely on live system config files:
- `config/system/general.json` — Miniserver and system settings
- `data/system/plugindatabase.json` — Plugin registry
- `data/system/logpackages.json` — Log session database

**Static test data:**
```
libs/perllib/LoxBerry/testing/jsontestdata2.json   # JSON parse test fixture
libs/perllib/LoxBerry/testing/json_param.tmpl      # Template test fixture
```

**No synthetic test data factories exist.** Tests either use live data or hardcode specific values (e.g. known plugin MD5 checksums in `test_plugindb_v2.pl`).

---

## Coverage

**Requirements:** None enforced — no coverage tooling configured

**View Coverage:**
Not applicable — no coverage framework exists

**Coverage by area:**

| Area | Perl Tests | PHP Tests | Bash Tests |
|------|-----------|-----------|------------|
| Log system | testlog.pl, testlogdb.pl, testlog_*.pl | testlog.php, testlblog.php, testlog_*.php | testlog.sh |
| Notifications | testnotify.pl | testnotify.php, testnotify_ext.php | testnotify.sh |
| System/Config | testsystem.pl, test_general.pl | testscript_loxberry_system.php | - |
| Plugin DB | test_plugindb_v2.pl, test_plugindb_shadow.pl | - | - |
| Miniserver IO | testgetminiservers.pl, testio_http.pl, testio_udp.pl | testgetminiservers.php, mshttp.php | - |
| JSON | json_testing.pl, json_encode.pl, json_flat.pl | - | - |
| MQTT | testmqttcred.pl | mqtt_connect.php, mqtt_publish.php | - |
| Locking | testlock.pl, testlock2.pl, testlock3.pl | - | - |
| Language | readlang.pl | testlang.php | - |
| SSL | testssl.pl | - | - |
| Storage | teststorage.cgi | - | - |

---

## Test Types

**Integration Tests (all tests):**
All tests in `testing/` directories are integration tests. They test the full call chain from library API through file system and network. There are no unit tests.

**Scope:** Each test file covers one module or one feature area. There is no cross-module test suite.

**Manual Test Execution:**
Tests are run manually by developers on a live LoxBerry device. There is no CI/CD pipeline executing these tests automatically.

---

## Adding New Tests

**Perl:** Create `libs/perllib/LoxBerry/testing/test_<feature>.pl`
```perl
#!/usr/bin/perl
use LoxBerry::TheModule;
use strict;
use warnings;

print "Testing TheModule\n";
print "=================\n";

# Test each public function
my $result = TheModule::some_function("param");
print "some_function result: $result\n";

print "DONE\n";
```

**PHP:** Create `libs/phplib/testing/test<feature>.php`
```php
#!/usr/bin/env php
<?php
require_once "loxberry_<module>.php";

$result = LBTheModule::some_function("param");
echo "Result: $result\n";
?>
```

**Bash:** Create `libs/bashlib/testing/test<feature>.sh`
```bash
#!/bin/bash
source $LBHOMEDIR/libs/bashlib/loxberry_<module>.sh

# Exercise the feature
# Print output for visual confirmation
```

---

## Common Patterns

**Commented-out test variants:**
Test files frequently contain large blocks of commented-out alternative test scenarios. This is the established pattern for preserving test variations without deleting them:
```perl
# my $plugin1 = LoxBerry::System::PluginDB->plugin( md5 => '07a6053111afa90479675dbcd29d54b5' );
# if($plugin1) {
#     print "Plugin exists\n";
# } else {
#     print "Plugin not defined\n";
# }
```
This is intentional — preserve commented alternatives as documentation of tested scenarios.

**Print-based verification:**
All tests output results to stdout/stderr. Verification is by reading printed output:
```perl
print "We have $check_err errors and $check_ok infos, together $check_sum notifications.\n";
```

**Dumper for complex structures:**
`Data::Dumper` is used in Perl tests to inspect complex return values:
```perl
use Data::Dumper;
my $response = LoxBerry::IO::mshttp_call(2, '/dev/sps/io/...');
print Dumper($response);
```

---

*Testing analysis: 2026-03-15*
