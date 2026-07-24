#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
lbcountry.py - Test lblanguage / lbcountry.
Analogous to perllib/LoxBerry/testing/lbcountry.pl.
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from loxberry import system as lb

try:
    print("lblanguage() = %r" % lb.lblanguage())
    print("lbcountry()  = %r" % lb.lbcountry())
except Exception as exc:
    print("general.json not readable here: %s" % exc)
    sys.exit(1)

print("\nOK")
