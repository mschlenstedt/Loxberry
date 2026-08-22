#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
testauth.py - loxberry/auth.py against a real Miniserver.
Runs on a live LoxBerry. Analogous to the Perl and PHP scripts.

    python3 testauth.py [msnr|serial] [--store PATH] [--keep]

Without --store the token is kept in /tmp so the productive
data/system/tokens.json is not touched. Without --keep the token is revoked at
the end - the Miniserver must not collect orphans in its token list.
"""

from __future__ import annotations

import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from loxberry import auth
from loxberry import system as lb

args = sys.argv[1:]
ms = args.pop(0) if args and not args[0].startswith("--") else 1
keep = False
store = "/tmp/testauth_tokens_py.json"
while args:
    a = args.pop(0)
    if a == "--keep":
        keep = True
    elif a == "--store" and args:
        store = args.pop(0)

auth.store_file = store

print("Miniserver : %s" % ms)
print("Token store: %s" % store)
print("auth_method: %s" % auth.auth_method(ms))

failed = 0


def step(name, res):
    global failed
    if isinstance(res, dict) and res.get("ok"):
        print("OK   %s" % name)
        return True
    failed += 1
    print("FAIL %s: %s - %s" % (name, res.get("error"), res.get("message")))
    return False


print("\n=== get_token ===")
t = auth.get_token(ms, info="LoxBerry Auth selftest Python", force=1)
if step("get_token", t):
    print("     serial     : %s" % t["serial"])
    print("     firmware   : %s" % t["firmware"])
    print("     perm       : %d (0x%x)" % (t["perm"], t["perm"]))
    print("     rights     : %d" % t["rights"])
    print("     validUntil : %d (lox) = %s"
          % (t["validUntil"], time.strftime("%Y-%m-%d %H:%M:%S",
                                            time.localtime(lb.lox2epoch(t["validUntil"])))))
    days = (t["validUntil"] - lb.epoch2lox()) / 86400.0
    print("     lifetime   : %.1f days%s"
          % (days, " (matches the ~3 months measured for 0x104)" if days > 80
             else " (SHORTER THAN EXPECTED)"))
    print("     Sys-WS bit : %s"
          % ("granted - reboot would be allowed"
             if auth._rights_granted(t["rights"], auth.PERM_SYSWS) else "MISSING"))

print("\n=== token_info ===")
ti = auth.token_info(ms)
if step("token_info", ti):
    print("     expires_in : %d s" % ti["expires_in"])

print("\n=== request /jdev/cfg/version ===")
content, info = auth.request(ms, "/jdev/cfg/version")
if info["error"] == 0:
    print("OK   request (code %s)" % info["code"])
    print("     %s" % content)
else:
    failed += 1
    print("FAIL request: %s - %s" % (info["errcode"], info["message"]))

print("\n=== second request: the one-time key must be fetched again ===")
_c2, i2 = auth.request(ms, "/jdev/cfg/version")
if i2["error"] == 0:
    print("OK   second request (code %s)" % i2["code"])
else:
    failed += 1
    print("FAIL second request: %s - %s" % (i2["errcode"], i2["message"]))

print("\n=== refresh_token (password free) ===")
rt = auth.refresh_token(ms)
if step("refresh_token", rt):
    print("     token      : %s..." % rt["token"][:12])
    print("     format     : %s" % ("JWT" if rt["token"].startswith("eyJ") else "hex"))

print("\n=== request with the refreshed token ===")
_c3, i3 = auth.request(ms, "/jdev/cfg/version")
if i3["error"] == 0:
    print("OK   request after refresh (code %s)" % i3["code"])
else:
    failed += 1
    print("FAIL request after refresh: %s - %s" % (i3["errcode"], i3["message"]))

print("\n=== cleanup: kill_token ===")
if keep:
    print("SKIP --keep given - the token stays on the Miniserver")
else:
    step("kill_token", auth.kill_token(ms))
    after = auth.token_info(ms)
    if not after.get("ok") and after.get("error") == "notoken":
        print("OK   store entry removed")
    else:
        failed += 1
        print("FAIL store entry still present")
    # a request re-fetches a token automatically - that one has to go as well
    auth.request(ms, "/jdev/cfg/version")
    auth.kill_token(ms)

print("\n%s" % ("%d STEP(S) FAILED" % failed if failed else "ALL STEPS OK"))
sys.exit(1 if failed else 0)
