#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
currtime.py - Test all currtime() formats.
Analogous to perllib/LoxBerry/testing/currtime.pl.
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from loxberry import system as lb

for fmt in ("", "hr", "hrtime", "hrtimehires", "file", "filehires", "iso"):
    print("  currtime(%-12r) = %s" % (fmt, lb.currtime(fmt)))

print("\nOK")
