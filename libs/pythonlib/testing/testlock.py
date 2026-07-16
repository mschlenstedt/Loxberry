#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
testlock.py - Test lock() / unlock().
Analogous to perllib/LoxBerry/testing/testlock.pl.

Uses a dedicated test lockfile name so no real plugin lock is touched.
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from loxberry import system as lb

NAME = "pythonlib_testlock"

# Start clean
lb.unlock(lockfile=NAME)

print("=== first lock (should succeed -> None) ===")
r1 = lb.lock(lockfile=NAME, wait=0)
print("  lock ->", repr(r1))

print("\n=== second lock while held (should report the lock name) ===")
r2 = lb.lock(lockfile=NAME, wait=0)
print("  lock ->", repr(r2))

print("\n=== unlock (should succeed -> None) ===")
r3 = lb.unlock(lockfile=NAME)
print("  unlock ->", repr(r3))

print("\n=== lock again after unlock (should succeed -> None) ===")
r4 = lb.lock(lockfile=NAME, wait=0)
print("  lock ->", repr(r4))
lb.unlock(lockfile=NAME)

print("\nOK")
