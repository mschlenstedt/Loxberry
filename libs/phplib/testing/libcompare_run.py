#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
libcompare_run.py - Perl<->PHP library parity test runner.

Runs both emitters on the LIVE LoxBerry (this is required because the live
systems run PHP 7.4, which is not available on the dev workstation):

    perllib/LoxBerry/testing/libcompare.pl   (Perl master libs)
    phplib/testing/libcompare.php            (ported PHP libs)

Each emitter prints one line per test case:  @@<name>@@<single-line-json>

For every test name present on both sides the JSON is normalised
(all scalars -> string, a few volatile keys removed) and compared
canonically (sorted keys). Prints a PASS/FAIL table and, on failure,
the differing normalised values.

Usage:  python3 libcompare_run.py [-v]
        -v  also print the normalised value of every PASS
"""

import json
import subprocess
import sys
import os

HERE = os.path.dirname(os.path.abspath(__file__))
HOME = os.environ.get("LBHOMEDIR", "/opt/loxberry")
PHP_SCRIPT = os.path.join(HERE, "libcompare.php")
PERL_SCRIPT = os.path.join(HOME, "libs", "perllib", "LoxBerry", "testing", "libcompare.pl")

# Volatile keys removed (recursively, by key name) before comparing.
IGNORE = {
    "diskspaceinfo_root": {"used", "available", "usedpercent"},
    "mshttp_call2_ms1": {"error", "status", "message", "filename"},
    "get_netshares": {"NETSHARE_USED", "NETSHARE_USED_HR", "NETSHARE_AVAILABLE",
                      "NETSHARE_AVAILABLE_HR", "NETSHARE_USEDPERCENT"},
    "get_usbstorage": {"USBSTORAGE_USED", "USBSTORAGE_AVAILABLE",
                       "USBSTORAGE_CAPACITY", "USBSTORAGE_USEDPERCENT"},
    "get_storage": {"USED", "AVAILABLE"},
    "get_logs": {"LASTMODIFIEDISO", "LASTMODIFIEDSTR", "LOGENDISO", "LOGENDSTR",
                 "FILESIZE"},
}

# Notes shown in the report for tests with a known, intentional difference.
NOTES = {
    "mshttp_call2_ms1": "Only 'code' compared. 'error' differs on purpose: "
                        "PHP sets 0 on success (bugfix), Perl master leaves it 1.",
    "diskspaceinfo_root": "used/available/usedpercent ignored (change between runs).",
    "get_netshares": "used/available fields ignored (volatile).",
    "get_usbstorage": "used/available fields ignored (volatile).",
    "get_storage": "USED/AVAILABLE ignored (volatile).",
    "get_logs": "LASTMODIFIED/LOGEND/FILESIZE ignored (active sessions keep writing).",
    "check_securepin_invalid": "Invalid PIN; counter file reset around the call.",
    "lock_unlock": "Dedicated test lockfile 'libcompare_test'.",
}


def run(cmd):
    p = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    return p.stdout.decode("utf-8", "replace"), p.stderr.decode("utf-8", "replace"), p.returncode


def parse(output):
    result = {}
    for line in output.splitlines():
        if not line.startswith("@@"):
            continue
        try:
            _, name, payload = line.split("@@", 2)
        except ValueError:
            continue
        try:
            result[name] = json.loads(payload)
        except json.JSONDecodeError as e:
            result[name] = {"__PARSE_ERROR__": str(e), "__RAW__": payload[:200]}
    return result


def normalise(value, ignore):
    """Recursively: drop ignored keys, turn every scalar into a string marker."""
    if isinstance(value, dict):
        return {k: normalise(v, ignore) for k, v in value.items() if k not in ignore}
    if isinstance(value, list):
        return [normalise(v, ignore) for v in value]
    if value is None:
        return "\x00null"
    if isinstance(value, bool):
        return "true" if value else "false"
    return str(value)


def canon(value, ignore):
    return json.dumps(normalise(value, ignore), sort_keys=True, ensure_ascii=False)


def main():
    verbose = "-v" in sys.argv

    perl_out, perl_err, perl_rc = run(["perl", PERL_SCRIPT])
    php_out, php_err, php_rc = run(["php", PHP_SCRIPT])

    perl = parse(perl_out)
    php = parse(php_out)

    if perl_rc != 0 or not perl:
        print("!! Perl emitter problem (rc=%d)" % perl_rc)
        if perl_err.strip():
            print(perl_err.strip()[:2000])
    if php_rc != 0 or not php:
        print("!! PHP emitter problem (rc=%d)" % php_rc)
        if php_err.strip():
            print(php_err.strip()[:2000])

    names = sorted(set(perl) | set(php))
    passed = failed = 0
    fails = []

    print("=" * 78)
    print("  Perl <-> PHP library parity test   (host: %s)" % os.uname()[1])
    print("=" * 78)

    for name in names:
        ignore = IGNORE.get(name, set())
        if name not in perl:
            status = "MISSING-PERL"
        elif name not in php:
            status = "MISSING-PHP"
        else:
            cp = canon(perl[name], ignore)
            cq = canon(php[name], ignore)
            status = "PASS" if cp == cq else "FAIL"

        if status == "PASS":
            passed += 1
        else:
            failed += 1
            fails.append(name)

        note = NOTES.get(name, "")
        print("  [%-12s] %-28s %s" % (status, name, note))

        if verbose and status == "PASS":
            print("       = %s" % canon(perl[name], ignore)[:300])

        if status == "FAIL":
            print("       PERL: %s" % canon(perl[name], ignore)[:600])
            print("       PHP : %s" % canon(php[name], ignore)[:600])

    print("-" * 78)
    print("  Total: %d   PASS: %d   FAIL/OTHER: %d" % (len(names), passed, failed))
    if fails:
        print("  Not passing: %s" % ", ".join(fails))
    print("=" * 78)

    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
