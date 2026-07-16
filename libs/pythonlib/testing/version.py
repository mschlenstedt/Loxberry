#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
version.py - Test vers_tag / plugin_version_compare / plugin_version_has_prerelease.
Analogous to perllib/LoxBerry/testing/version.pl.
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from loxberry import system as lb

print("=== vers_tag ===")
for v, rev in (("1.2.3", False), ("v1.2.3", False),
               ("1.2.3", True), ("v1.2.3", True), ("  V2.0  ", False)):
    print("  vers_tag(%-10r, reverse=%s) = %r" % (v, rev, lb.vers_tag(v, rev)))

print("\n=== plugin_version_compare ===")
pairs = [
    ("1.2.3", "1.2.4"),
    ("1.2.3", "1.2.3"),
    ("1.2.4", "1.2.3"),
    ("1.2.0", "1.2.0-beta"),
    ("1.2.0-beta", "1.2.0"),
    ("1.2.0-alpha", "1.2.0-beta"),
    ("1.2.0-1", "1.2.0-2"),
    ("4.0.0.14", "4.0.0.13"),
    ("4.0.0.2", "4.0.0.10"),
    ("v4.0.0.1", "4.0.0.1"),
    ("1.0", "1.0.0"),
    ("abc", "1.0"),
]
for a, b in pairs:
    print("  compare(%-14r, %-12r) = %s" % (a, b, lb.plugin_version_compare(a, b)))

print("\n=== plugin_version_has_prerelease ===")
for v in ("1.2.0", "1.2.0-beta", "4.0.0.14", "", "v2.0.0-rc.1"):
    print("  has_prerelease(%-14r) = %s" % (v, lb.plugin_version_has_prerelease(v)))

print("\nOK")
