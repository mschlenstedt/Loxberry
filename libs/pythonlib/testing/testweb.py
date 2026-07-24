#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
testweb.py - Test the ported LoxBerry::Web data functions.
Analogous to perllib/LoxBerry/testing (iso_languages part).
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from loxberry import web

print("=== iso_languages ===")
vals = web.iso_languages(selection="values")
print("  all languages: %d codes" % len(vals))
avail = web.iso_languages(onlyavail=True, selection="values")
print("  available (system language files):", avail)
labels = web.iso_languages(selection="labels")
for code in ("en", "de", "fr", "es"):
    print("    %s = %s" % (code, labels.get(code)))

print("\n=== get_plugin_icon ===")
print("  get_plugin_icon(64)  =", web.get_plugin_icon(64))
print("  (None when not run from within a plugin)")

print("\nOK")
