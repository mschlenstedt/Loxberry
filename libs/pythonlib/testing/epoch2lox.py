#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
epoch2lox.py - Test epoch2lox / lox2epoch / tz_offset.
Analogous to perllib/LoxBerry/testing/epoch2lox.pl.
"""

import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from loxberry import system as lb

print("tz_offset() = %d seconds" % lb.tz_offset())

now = int(time.time())
print("\nRoundtrip with current time:")
lox = lb.epoch2lox(now)
back = lb.lox2epoch(lox)
print("  now (unix)      = %d" % now)
print("  epoch2lox(now)  = %d" % lox)
print("  lox2epoch(lox)  = %d" % back)
print("  roundtrip ok    = %s" % (back == now))

print("\nFixed value (deterministic on a given host/timezone):")
print("  epoch2lox(1600000000) = %d" % lb.epoch2lox(1600000000))
print("  lox2epoch(400000000)  = %d" % lb.lox2epoch(400000000))

print("\nOK")
