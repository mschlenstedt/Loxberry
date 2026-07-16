#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
libcompare_run.py - Perl <-> Python library parity test runner.

Runs both emitters on the LIVE LoxBerry:

    libs/perllib/...            (via libcompare.pl -> Perl master libs)
    libs/pythonlib/testing/libcompare.py   (ported Python libs)

Each emitter prints one line per test case:  @@<name>@@<single-line-json>

For every test name present on both sides the JSON is normalised
(all scalars -> string, a few volatile keys removed) and compared
canonically (sorted keys). Prints a PASS/FAIL table and, on failure,
the differing normalised values.

Usage:  python3 libcompare_run.py [-v]
        -v  also print the normalised value of every PASS
"""

import json
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
PERL_SCRIPT = os.path.join(HERE, "libcompare.pl")
PY_SCRIPT = os.path.join(HERE, "libcompare.py")

# Volatile keys removed (recursively, by key name) before comparing.
IGNORE = {
    # get_miniservers: for CloudDNS miniservers the Python port does not yet
    # resolve the address (set_clouddns is step 2), so IP/URI-derived fields
    # can differ. On local (non-CloudDNS) setups everything matches.
}

NOTES = {
    "get_miniservers": "CloudDNS miniservers may differ until set_clouddns is "
                       "ported (step 2). Local setups match fully.",
    "epoch2lox_fixed": "Depends on host timezone; identical on both sides.",
    "lox2epoch_fixed": "Depends on host timezone; identical on both sides.",
}


def run(cmd):
    p = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    return (p.stdout.decode("utf-8", "replace"),
            p.stderr.decode("utf-8", "replace"), p.returncode)


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
    py_out, py_err, py_rc = run([sys.executable, PY_SCRIPT])

    perl = parse(perl_out)
    py = parse(py_out)

    if perl_rc != 0 or not perl:
        print("!! Perl emitter problem (rc=%d)" % perl_rc)
        if perl_err.strip():
            print(perl_err.strip()[:2000])
    if py_rc != 0 or not py:
        print("!! Python emitter problem (rc=%d)" % py_rc)
        if py_err.strip():
            print(py_err.strip()[:2000])

    names = sorted(set(perl) | set(py))
    passed = failed = 0
    fails = []

    try:
        host = os.uname()[1]
    except AttributeError:
        host = os.environ.get("COMPUTERNAME", "unknown")

    print("=" * 78)
    print("  Perl <-> Python library parity test   (host: %s)" % host)
    print("=" * 78)

    for name in names:
        ignore = IGNORE.get(name, set())
        if name not in perl:
            status = "MISSING-PERL"
        elif name not in py:
            status = "MISSING-PY"
        else:
            cp = canon(perl[name], ignore)
            cq = canon(py[name], ignore)
            status = "PASS" if cp == cq else "FAIL"

        if status == "PASS":
            passed += 1
        else:
            failed += 1
            fails.append(name)

        note = NOTES.get(name, "")
        print("  [%-12s] %-30s %s" % (status, name, note))

        if verbose and status == "PASS":
            print("       = %s" % canon(perl[name], ignore)[:300])
        if status == "FAIL":
            print("       PERL: %s" % canon(perl[name], ignore)[:600])
            print("       PY  : %s" % canon(py[name], ignore)[:600])

    print("-" * 78)
    print("  Total: %d   PASS: %d   FAIL/OTHER: %d" % (len(names), passed, failed))
    if fails:
        print("  Not passing: %s" % ", ".join(fails))
    print("=" * 78)

    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
