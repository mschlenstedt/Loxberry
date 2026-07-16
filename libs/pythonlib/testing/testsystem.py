#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
testsystem.py - Overview test for loxberry.system (path vars + simple helpers).
Analogous to perllib/LoxBerry/testing/testsystem.pl.

Run directly on a LoxBerry:  python3 testsystem.py
"""

import os
import sys

# Make the library importable without the installed loxberry.pth (dev + on-device)
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from loxberry import system as lb


def line(k, v):
    print("  %-22s = %r" % (k, v))


print("=== Path variables ===")
for name in ("lbhomedir", "lbpplugindir", "lbpconfigdir", "lbpdatadir",
             "lbplogdir", "lbpbindir", "lbphtmldir", "lbphtmlauthdir",
             "lbcgidir", "lbptemplatedir",
             "lbsconfigdir", "lbsdatadir", "lbslogdir", "lbstmpfslogdir",
             "lbstemplatedir", "lbshtmldir", "lbshtmlauthdir",
             "lbsbindir", "lbssbindir"):
    line(name, getattr(lb, name))

print("\n=== Host / version ===")
line("lbhostname()", lb.lbhostname())
line("get_localip()", lb.get_localip())
try:
    line("lbversion()", lb.lbversion())
    line("systemloglevel()", lb.systemloglevel())
    line("lbfriendlyname()", lb.lbfriendlyname())
    line("lbwebserverport()", lb.lbwebserverport())
    line("lblanguage()", lb.lblanguage())
    line("lbcountry()", lb.lbcountry())
except Exception as exc:
    print("  (general.json not readable here: %s)" % exc)

print("\n=== is_enabled / is_disabled ===")
for v in ("true", "YES", " on ", "Enabled", "1", "check", "selected",
          "false", "0", "", "no", "random"):
    print("  %-10r enabled=%-5s disabled=%-5s"
          % (v, lb.is_enabled(v), lb.is_disabled(v)))

print("\n=== trim / ltrim / rtrim ===")
for v in ("  hello  ", "\tx\n", "nospace", "   "):
    print("  %-12r trim=%r ltrim=%r rtrim=%r"
          % (v, lb.trim(v), lb.ltrim(v), lb.rtrim(v)))

print("\n=== begins_with ===")
for s, p in (("loxberry", "lox"), ("loxberry", "berry"), ("abc", "")):
    print("  begins_with(%r, %r) = %s" % (s, p, lb.begins_with(s, p)))

print("\n=== bytes_humanreadable ===")
for size, factor in ((0, ""), (1023, ""), (1024, ""), (1500000, ""),
                     (1073741824, ""), (137, "K"), (2, "M"), (2, "G"), (1, "T")):
    print("  bytes_humanreadable(%s, %r) = %s"
          % (size, factor, lb.bytes_humanreadable(size, factor)))

print("\nOK")
