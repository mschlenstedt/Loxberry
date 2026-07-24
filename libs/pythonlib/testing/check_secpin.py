#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
check_secpin.py - Test check_securepin().
Analogous to perllib/LoxBerry/testing/check_secpin.pl.

Only tests with a deliberately INVALID pin and resets the brute-force counter
file around the call, so no lasting state remains and no real PIN is exposed.
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from loxberry import system as lb

errfile = "%s/log/system_tmpfs/securepin.errors" % lb.lbhomedir

if os.path.exists(errfile):
    os.unlink(errfile)

result = lb.check_securepin("zzz_invalid_pin_zzz")
print("check_securepin(invalid) -> %r  (None=ok, 1=wrong, 3=locked)" % result)

if os.path.exists(errfile):
    os.unlink(errfile)

print("\nOK")
