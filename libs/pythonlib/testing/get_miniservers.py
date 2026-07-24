#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
get_miniservers.py - Test get_miniservers / get_miniserver_by_ip / _by_name.
Analogous to perllib/LoxBerry/testing/get_miniservers.pl.
"""

import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from loxberry import system as lb

try:
    ms = lb.get_miniservers()
except Exception as exc:
    print("Could not read miniservers (general.json): %s" % exc)
    sys.exit(1)

print("Found %d miniserver(s):\n" % len(ms))
for msnr, entry in ms.items():
    print("--- Miniserver %s ---" % msnr)
    print(json.dumps(entry, indent=2, ensure_ascii=False, sort_keys=True))
    print()

# Reverse lookups using the first miniserver
if ms:
    first = next(iter(ms.values()))
    ip = first.get("IPAddress")
    name = first.get("Name")
    print("get_miniserver_by_ip(%r)   = %r" % (ip, lb.get_miniserver_by_ip(ip)))
    print("get_miniserver_by_name(%r) = %r" % (name, lb.get_miniserver_by_name(name)))
    print("get_ftpport(1)             = %r (may query the Miniserver live)"
          % None)  # placeholder; see test_get_ftpport.py for the live call

print("OK")
