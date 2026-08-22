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
from loxberry import web as lbweb
from loxberry import storage as lbstorage


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

# --- Web::iso_languages ---
emit("iso_languages_values", lbweb.iso_languages(selection="values"))
emit("iso_languages_labels", lbweb.iso_languages(selection="labels"))
emit("iso_languages_values_avail", lbweb.iso_languages(onlyavail=True, selection="values"))

# --- Storage::get_netservers / get_usbstorage ---
emit("get_netservers", lbstorage.get_netservers())
emit("get_usbstorage", lbstorage.get_usbstorage(""))

# --- loxberry.auth (pure functions) ---
from loxberry import auth as lbauth

_auth_key = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
_auth_apiv = ("{'snr': 'AB:CD:EF:01:02:03', 'version':'17.1.7.3', 'hasEventSlots':true, "
              "'isInTrust':false, 'local':true,'certTLD':'com'}")

emit("auth_norm_alg", [lbauth._norm_alg(a) for a in ("SHA256", "sha-256", "SHA1", "", "MD5")])

_auth_pw256 = lbauth._pw_hash("Test1234", "41B0A8F1", "SHA256")
_auth_pw1 = lbauth._pw_hash("Test1234", "41B0A8F1", "SHA1")
emit("auth_hashes", {
    "pw_sha256": _auth_pw256,
    "pw_sha1": _auth_pw1,
    "auth_sha256": lbauth._auth_hash("loxberry", _auth_pw256, _auth_key, "SHA256"),
    "auth_sha1": lbauth._auth_hash("loxberry", _auth_pw1, _auth_key, "SHA1"),
    "token_sha256": lbauth._token_hash("a1b2c3d4e5f60718293a4b5c6d7e8f90", _auth_key, "SHA256"),
    "token_sha1": lbauth._token_hash("a1b2c3d4e5f60718293a4b5c6d7e8f90", _auth_key, "SHA1"),
})

emit("auth_parse_api_value", lbauth._parse_api_value(_auth_apiv))

emit("auth_fw_supported", [lbauth._fw_supported(f) for f in
                           ("17.1.7.3", "11.2.10.22", "11.2.10.21", "11.2.9.99", "12.0", "")])

emit("auth_rights_granted", [
    lbauth._rights_granted(1924, 0x100),
    lbauth._rights_granted(1924, 0x04),
    lbauth._rights_granted(4, 0x100),
    lbauth._rights_granted(1924, 0x104),
])

emit("auth_ll_codes", [
    lbauth._ll_code('{"LL":{"value":{},"code":"401"}}'),
    lbauth._ll_code('{"LL":{"value":"x","Code":"200"}}'),
    lbauth._ll_code("<html>401</html>"),
    lbauth._effective_code(200, '{"LL":{"value":{},"code":"401"}}'),
    lbauth._effective_code(200, '{"LL":{"value":"x","Code":"200"}}'),
    lbauth._effective_code(401, "<html>401</html>"),
])

emit("auth_constants", {
    "default_perm": lbauth.DEFAULT_PERM,
    "refresh_threshold": lbauth.REFRESH_THRESHOLD,
    "min_firmware": lbauth.MIN_FIRMWARE,
    "perm_app": lbauth.PERM_APP,
    "perm_sysws": lbauth.PERM_SYSWS,
})

_auth_ms = lb.get_miniservers() or {}
emit("auth_ms_baseurl", lbauth._ms_baseurl(_auth_ms.get("1")) if _auth_ms.get("1") else None)
emit("auth_auth_method_ms1", lbauth.auth_method(1))

sys.exit(0)
