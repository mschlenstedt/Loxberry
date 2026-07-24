#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
test_get_ftpport.py - Test get_ftpport().
Analogous to perllib/LoxBerry/testing/test_get_ftpport.pl.

Note: for non-CloudDNS miniservers this queries the Miniserver live over HTTP
(requests) - only meaningful when run on a LoxBerry that can reach the MS.
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from loxberry import system as lb

try:
    ms = lb.get_miniservers()
except Exception as exc:
    print("Could not read miniservers (general.json): %s" % exc)
    sys.exit(1)

if not ms:
    print("No miniservers configured - nothing to test.")
    sys.exit(0)

for msnr in ms:
    port = lb.get_ftpport(msnr)
    print("  get_ftpport(%r) = %r" % (msnr, port))

print("\nOK")
