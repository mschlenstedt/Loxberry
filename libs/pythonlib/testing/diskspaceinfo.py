#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
diskspaceinfo.py - Test diskspaceinfo().
"""

import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from loxberry import system as lb

print("=== diskspaceinfo('/') - single folder ===")
di = lb.diskspaceinfo("/")
print(json.dumps(di, indent=2, ensure_ascii=False, sort_keys=True))

print("\n=== diskspaceinfo() - all mountpoints ===")
allinfo = lb.diskspaceinfo()
if allinfo:
    for mp in sorted(allinfo):
        d = allinfo[mp]
        print("  %-25s %s on %s (%s used)"
              % (mp, lb.bytes_humanreadable(d["size"], "K"), d["filesystem"], d["usedpercent"]))

print("\nOK")
