#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
readlang.py - Test readlanguage() (system phrases, and plugin phrases if run
from within a plugin context).
Analogous to perllib/LoxBerry/testing/readlang.pl.
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from loxberry import system as lb

print("Detected language: %r" % lb.lblanguage())

print("\n=== System phrases (syslang=True) ===")
sl = lb.readlanguage(syslang=True)
print("  %d phrase(s) loaded" % len(sl))
for k in list(sorted(sl))[:10]:
    print("    %s = %s" % (k, sl[k]))
if len(sl) > 10:
    print("    ... (%d more)" % (len(sl) - 10))

if lb.lbpplugindir:
    print("\n=== Plugin phrases (language.ini) ===")
    pl = lb.readlanguage("language.ini")
    print("  plugin %r: %d phrase(s) loaded" % (lb.lbpplugindir, len(pl)))
    for k in list(sorted(pl))[:10]:
        print("    %s = %s" % (k, pl[k]))
else:
    print("\n(no plugin context - skipping plugin phrases)")

print("\nOK")
