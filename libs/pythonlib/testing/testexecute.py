#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
testexecute.py - Test execute().
Analogous to perllib/LoxBerry/testing/testexecute.pl.

Demonstrates that a command WITHOUT shell metacharacters is run directly (no
shell wrapper) - important so that "pgrep -f <pattern>" does not match its own
wrapper.
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from loxberry import system as lb

print("=== simple command ===")
rc, out, err = lb.execute("echo hello world")
print("  echo -> rc=%r out=%r" % (rc, out.strip()))

print("\n=== command with stderr ===")
rc, out, err = lb.execute("ls /this/does/not/exist")
print("  ls missing -> rc=%r err=%r" % (rc, err.strip()))

print("\n=== shell pipeline (metacharacters -> shell) ===")
rc, out, err = lb.execute("echo one two three | wc -w")
print("  wc -w -> rc=%r out=%r" % (rc, out.strip()))

print("\n=== pgrep -f (no shell wrapper -> no false positive) ===")
rc, out, err = lb.execute("pgrep -f /usr/bin/unattended-upgrade")
print("  pgrep -f unattended-upgrade -> rc=%r (1 = not running)" % rc)

print("\nOK")
