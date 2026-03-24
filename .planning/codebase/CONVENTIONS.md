# Coding Conventions

**Analysis Date:** 2026-03-15

## Language Overview

LoxBerry is a multi-language project. Conventions vary by language layer. The primary languages are:

- **Perl** — Core library modules (`libs/perllib/LoxBerry/*.pm`), system scripts (`sbin/*.pl`), CGI handlers
- **PHP** — Web library (`libs/phplib/loxberry_*.php`), web frontend CGI pages, MQTT transform scripts
- **Bash** — System init scripts (`sbin/*.sh`), log library (`libs/bashlib/loxberry_log.sh`), plugin install hooks

All three language variants implement the same logical API surface (System, Log, IO, JSON, Web) so conventions must be understood per-language.

---

## Naming Patterns

**Perl Modules:**
- Package names use `TitleCase` namespaced under `LoxBerry::` (e.g. `LoxBerry::System`, `LoxBerry::Log`, `LoxBerry::IO`)
- Sub-namespace modules use `::` separator: `LoxBerry::System::General`, `LoxBerry::System::PluginDB`
- Module files follow Perl convention: `TitleCase.pm` under `libs/perllib/LoxBerry/`

**Perl Variables:**
- Module-level exported variables use lowercase with `lb` prefix: `$lbhomedir`, `$lbpplugindir`, `$lbslogdir`
- System directory variables use `lbs` prefix (system), `lbp` prefix (plugin): `$lbshtmldir`, `$lbphtmldir`
- Internal (non-exported) variables: lowercase with underscores: `$cfgwasread`, `$plugindb_timestamp`
- Hash keys for plugin database use `UPPER_SNAKE_CASE`: `PLUGINDB_NAME`, `PLUGINDB_VERSION`, `PLUGINDB_FOLDER`
- Hash keys for Miniserver data use `TitleCase`: `IPAddress`, `UseCloudDNS`, `PortHttps`

**PHP Variables and Constants:**
- Constants use `UPPER_SNAKE_CASE` with `LB` prefix: `LBHOMEDIR`, `LBPHTMLDIR`, `LBSCONFIGDIR`
- Variables shadow their constants in lowercase: `$lbhomedir`, `$lbphtmldir`, `$lbsconfigdir`
- Class names use `TitleCase` with `LB` prefix: `LBSystem`, `LBWeb`, `LBLog`, `LBJSON`
- Static methods accessed as `LBSystem::methodname()`, `LBLog::newLog()`, `LBWeb::head()`

**PHP Functions (procedural globals):**
- Procedural wrappers use lowercase: `currtime()`, `lbhostname()`, `lbfriendlyname()`, `is_enabled()`, `notify()`

**Bash Functions:**
- Log level functions: `LOGDEB`, `LOGINF`, `LOGOK`, `LOGWARN`, `LOGERR`, `LOGCRIT`, `LOGALERT`, `LOGEMERGE`, `LOGSTART`, `LOGEND`
- Internal helpers: `loadvariables`, `WRITE`
- Log session config variables: `UPPERCASE` — `PACKAGE`, `NAME`, `LOGDIR`, `FILENAME`, `LOGLEVEL`, `APPEND`, `ADDTIME`

**Files:**
- Perl modules: `TitleCase.pm` (e.g. `System.pm`, `Log.pm`, `Web.pm`)
- PHP libraries: `lowercase_snake.php` with `loxberry_` prefix (e.g. `loxberry_system.php`, `loxberry_log.php`)
- Bash libs: `lowercase_snake.sh` with `loxberry_` prefix (e.g. `loxberry_log.sh`)
- Test scripts: `test<feature>.{pl|php|sh}` or `test_<feature>.{pl|php|sh}` — both patterns exist

---

## Code Style

**Formatting:**
- `.editorconfig` enforces: `indent_style = tab`, `indent_size = 4` for all JS, HTML, Sass, CGI, Perl, Bash, PHP files
- Do NOT use spaces for indentation in any file type covered above

**Linting:**
- No linting tools configured (no `.eslintrc`, no `phpcs.xml`, no `perltidy`)
- Code formatting is enforced only via editorconfig

---

## Version Header Convention

Every Perl module begins with a mandatory version comment and version variable:

```perl
# Please increment version number on EVERY change
# Major.Minor represents LoxBerry version (e.g. 0.3.1.12 = LoxBerry V0.3.1 the 12th change)
our $VERSION = "3.0.0.7";
```

PHP libraries carry version in a class static:
```php
public static $LBSYSTEMVERSION = "2.2.1.1";
public static $LBWEBVERSION = "3.0.0.3";
```

**Rule:** Always update the version number on every change to a library file.

---

## Import Organization

**Perl:**
```perl
use strict;                        # Always first
use warnings;                      # Optional but present in test scripts
use SomeModule;                    # CPAN/bundled modules
use LoxBerry::System;              # LoxBerry core modules
use LoxBerry::Log;
```

Lazy loading (inside functions) is used for optional heavy modules:
```perl
require JSON;
require LoxBerry::IO;
require LWP::UserAgent;
```

**PHP:**
```php
require_once "loxberry_system.php";   # Always include system first
require_once "loxberry_log.php";      # Then log if needed
```

**Bash:**
```bash
source $LBHOMEDIR/libs/bashlib/loxberry_log.sh
source $LBHOMEDIR/libs/bashlib/notify.sh
```

---

## Error Handling

**Perl — die/eval pattern for JSON/file operations:**
```perl
eval {
    $cfg = JSON::from_json( LoxBerry::System::read_file("$lbsconfigdir/general.json") );
};
if ($@ or !$cfg) {
    Carp::croak "Could not read general.json. $@";
}
```

**Perl — Carp for library errors:**
- Use `Carp::croak` for fatal errors in library code (die with caller's perspective)
- Use `Carp::carp` for warnings that should not stop execution
- Never use plain `die` in library modules; prefer `Carp::croak`

**Perl — Return undef on soft failure:**
```perl
open(my $fh, "<", $plugindb_file) or ($openerr = 1);
if ($openerr) {
    Carp::carp "Error opening plugin database $plugindb_file";
    return undef;
}
```

**PHP — echo + exit on fatal error:**
```php
if (!isset($this->params["name"]) && !isset($this->params["nofile"])) {
    echo "The name parameter must be defined.\n";
    exit(1);
}
```

**PHP — error_log for non-fatal:**
```php
error_log("loxberry_json: write: ERROR writing file " . $this->filename);
```

**Bash — exit 1 on failure, echo to stderr:**
```bash
echo "Log could not be started" 1>&2
exit 1
```

---

## Logging

**Framework:** LoxBerry's own LoxBerry::Log (Perl), LBLog (PHP), loxberry_log.sh (Bash)

**Severity Levels (shared across all languages):**

| Level | Label    | Numeric |
|-------|----------|---------|
| EMERGE | Emergency | 0 |
| ALERT  | Alert     | 1 |
| CRITICAL | Critical | 2 |
| ERROR  | Error     | 3 |
| WARNING | Warning  | 4 |
| OK     | OK        | 5 |
| INFO   | Info      | 6 |
| DEBUG  | Debug     | 7 |

**Perl logging pattern:**
```perl
my $log = LoxBerry::Log->new(
    package  => 'myplugin',    # plugin folder name
    name     => 'mytask',      # log session name
    logdir   => $lbplogdir,    # or filename =>
    loglevel => 7,
    stderr   => 1,
);
LOGSTART "Task started";
LOGINF "Informational message";
LOGOK "Completed successfully";
LOGERR "Something failed";
LOGEND "Task finished";
```

**PHP logging pattern:**
```php
$mylog = LBLog::newLog(array(
    "name"    => "PHPLog",
    "package" => "myplugin",
    "logdir"  => $lbplogdir
));
LOGSTART("Log session started");
LOGINF("Info message");
LOGERR("Error message");
LOGEND("Done");
```

**Bash logging pattern:**
```bash
source $LBHOMEDIR/libs/bashlib/loxberry_log.sh
PACKAGE=myplugin
NAME=taskname
LOGDIR=$LBPLOGDIR
LOGSTART "Session started"
LOGINF "Info message"
LOGERR "Error"
LOGEND "Done"
```

**Debug output convention:**
- Perl modules use `print STDERR "..." if ($DEBUG)` throughout, never plain print for debug
- PHP libraries use `// error_log("...")` for debug lines (commented out in production)
- Debug mode enabled per-module via `$LoxBerry::ModuleName::DEBUG = 1`

---

## Comments

**Perl — Section delimiters:**
```perl
##################################################################
# Sub description
##################################################################
```

**Perl — Parameter documentation:**
```perl
## Constructor
## Params [square brackets mean optional]
## See https://wiki.loxberry.de/...
```

**PHP — Triple-slash for method sections:**
```php
///////////////////////////////////////////////////////////////////
// Method description
///////////////////////////////////////////////////////////////////
```

**When to comment:**
- All exported/public functions get a header comment explaining purpose and parameters
- Internal implementation logic gets inline comments on non-obvious decisions
- Disabled/experimental code is commented out (not deleted) in test files
- Debugging code is always wrapped in a debug flag check, never left as bare print

---

## Module Design

**Perl Exports:**
All public symbols are explicitly declared in `@EXPORT`:
```perl
our @EXPORT = qw (
    $lbhomedir
    $lbpplugindir
    get_miniservers
    is_enabled
    trim
);
```

Non-exported functions are accessed via full namespace: `LoxBerry::System::is_enabled()`

**PHP Class Pattern:**
Static class with no constructor for system-level functions:
```php
class LBSystem {
    public static $LBSYSTEMVERSION = "2.2.1.1";
    public static function get_miniservers() { ... }
}
```

Object-instantiated for I/O classes:
```php
$log = LBLog::newLog(array(...));
$json = new LBJSON($filename);
```

**Dual export — Constants AND variables in PHP:**
PHP cannot concatenate constants in strings, so every `define("LBHOMEDIR", ...)` is mirrored with `$lbhomedir = LBHOMEDIR`. Always maintain both when adding directory definitions.

---

## Function Design

**Parameters:**
- Perl: named parameters passed as hash `my %params = @_` for constructors with multiple options
- Perl: positional parameters for simple utility functions: `my ($msnr) = @_;`
- PHP: array of named parameters: `LBLog::newLog(array("name" => ..., "package" => ...))`
- Bash: environment variables set before calling functions (not argument-based)

**Return Values:**
- Perl functions return `undef` on failure, value/hash/array on success
- PHP functions return `null` on failure (PHP `NULL`)
- Multi-value Perl returns use list context: `my ($value, $status) = LoxBerry::IO::mshttp_call(...)`

**Caching Pattern:**
Module-level variables cache expensive reads. Always check cache before re-reading:
```perl
if ($cfgwasread) {
    return 1;
}
# ... read file, set $cfgwasread = 1
```

---

*Convention analysis: 2026-03-15*
