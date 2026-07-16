#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
libcompare.py - Python side of the Perl <-> Python library parity test.

Emits one line per test case in the form:
    @@<testname>@@<single-line-json>

The companion Perl emitter (libcompare.pl) produces the identical set of
testnames from the Perl master libs; libcompare_run.py runs both and compares
the JSON per test case.

Only deterministic (pure) or file-derived (general.json) functions are tested,
so the results are identical on both sides for a given host. Booleans from
is_enabled/is_disabled are emitted as 1/None to match Perl's 1/undef.
"""

import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from loxberry import system as lb


def emit(name, data):
    sys.stdout.write("@@%s@@%s\n" % (name, json.dumps(data, sort_keys=True,
                                                       ensure_ascii=False)))


def b(x):
    """Perl-style 1/undef for a boolean."""
    return 1 if x else None


# --- bytes_humanreadable (pure) ---
bh_cases = [
    (0, ""), (1, ""), (1023, ""), (1024, ""), (1025, ""),
    (1048576, ""), (1500000, ""), (1073741824, ""),
    (137, "K"), (1536, "K"), (123124, "K"),
    (2, "M"), (2, "G"), (1, "T"), (0, "K"),
]
emit("bytes_humanreadable", [lb.bytes_humanreadable(s, f) for s, f in bh_cases])

# --- is_enabled / is_disabled (pure) ---
bool_inputs = ["true", "YES", " on ", "Enabled", "1", "check", "selected",
               "false", "0", "", "no", "random"]
emit("is_enabled", [b(lb.is_enabled(v)) for v in bool_inputs])
emit("is_disabled", [b(lb.is_disabled(v)) for v in bool_inputs])

# --- trim / ltrim / rtrim (pure) ---
trim_inputs = ["  hello  ", "\tx\n", "nospace", "   ", " a b "]
emit("trim", [lb.trim(v) for v in trim_inputs])
emit("ltrim", [lb.ltrim(v) for v in trim_inputs])
emit("rtrim", [lb.rtrim(v) for v in trim_inputs])

# --- vers_tag (pure) ---
vt_cases = [("1.2.3", False), ("v1.2.3", False), ("1.2.3", True),
            ("v1.2.3", True), ("  V2.0  ", False)]
emit("vers_tag", [lb.vers_tag(v, r) for v, r in vt_cases])

# --- plugin_version_compare (pure) ---
pvc_pairs = [
    ("1.2.3", "1.2.4"), ("1.2.3", "1.2.3"), ("1.2.4", "1.2.3"),
    ("1.2.0", "1.2.0-beta"), ("1.2.0-beta", "1.2.0"),
    ("1.2.0-alpha", "1.2.0-beta"), ("1.2.0-1", "1.2.0-2"),
    ("4.0.0.14", "4.0.0.13"), ("4.0.0.2", "4.0.0.10"),
    ("v4.0.0.1", "4.0.0.1"), ("1.0", "1.0.0"), ("abc", "1.0"),
]
emit("plugin_version_compare", [lb.plugin_version_compare(a, c) for a, c in pvc_pairs])

# --- plugin_version_has_prerelease (pure) ---
pvh_inputs = ["1.2.0", "1.2.0-beta", "4.0.0.14", "", "v2.0.0-rc.1"]
emit("plugin_version_has_prerelease", [lb.plugin_version_has_prerelease(v) for v in pvh_inputs])

# --- epoch2lox / lox2epoch (host timezone, identical on both sides) ---
emit("epoch2lox_fixed", {"value": lb.epoch2lox(1600000000)})
emit("lox2epoch_fixed", {"value": lb.lox2epoch(400000000)})

# --- general.json-derived accessors (identical on the same host) ---
try:
    emit("systemloglevel", {"value": lb.systemloglevel()})
    emit("lbversion", {"value": lb.lbversion()})
    emit("lbfriendlyname", {"value": lb.lbfriendlyname()})
    emit("lbwebserverport", {"value": lb.lbwebserverport()})
    emit("lblanguage", {"value": lb.lblanguage()})
    emit("lbcountry", {"value": lb.lbcountry()})
    emit("get_miniservers", lb.get_miniservers())
except Exception as exc:
    emit("general_json_error", {"error": str(exc)})

# --- get_binaries (deterministic) ---
emit("get_binaries", lb.get_binaries())

# --- diskspaceinfo (single folder "/") ---
emit("diskspaceinfo_root", lb.diskspaceinfo("/"))

# --- get_plugins ---
plugins = lb.get_plugins()
emit("get_plugins", plugins)

# --- pluginversion / pluginloglevel of the first plugin (by folder) ---
folder = plugins[0]["PLUGINDB_FOLDER"] if plugins else ""
emit("pluginversion_named", {"folder": folder, "version": lb.pluginversion(folder)})
emit("pluginloglevel_named", {"folder": folder, "loglevel": lb.pluginloglevel(folder)})

# --- check_securepin (invalid PIN, counter reset around the call) ---
_errfile = "%s/log/system_tmpfs/securepin.errors" % lb.lbhomedir
if os.path.exists(_errfile):
    os.unlink(_errfile)
_r = lb.check_securepin("zzz_invalid_pin_zzz")
emit("check_securepin_invalid", {"result": _r})
if os.path.exists(_errfile):
    os.unlink(_errfile)

# --- lock / unlock (dedicated test lockfile) ---
lb.unlock(lockfile="libcompare_py_test")
_rlock = lb.lock(lockfile="libcompare_py_test", wait=0)
_runlock = lb.unlock(lockfile="libcompare_py_test")
emit("lock_unlock", {"lock": _rlock, "unlock": _runlock})

sys.exit(0)
