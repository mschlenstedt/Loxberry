#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
get_plugins.py - Test get_plugins / plugindata / pluginversion / pluginloglevel.
Analogous to the Perl plugin database tests.
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from loxberry import system as lb

plugins = lb.get_plugins()
print("Found %d plugin(s):\n" % len(plugins))
print("  %-3s %-22s %-12s %-8s %s" % ("No", "Folder", "Version", "Loglvl", "Title"))
for p in plugins:
    print("  %-3s %-22s %-12s %-8s %s"
          % (p["PLUGINDB_NO"], p["PLUGINDB_FOLDER"], p["PLUGINDB_VERSION"],
             p["PLUGINDB_LOGLEVEL"], p["PLUGINDB_TITLE"]))

if plugins:
    folder = plugins[0]["PLUGINDB_FOLDER"]
    print("\n--- lookups for '%s' ---" % folder)
    print("  pluginversion(%r)  = %r" % (folder, lb.pluginversion(folder)))
    print("  pluginloglevel(%r) = %r" % (folder, lb.pluginloglevel(folder)))
    pd = lb.plugindata(folder)
    print("  plugindata(%r) title = %r" % (folder, pd["PLUGINDB_TITLE"] if pd else None))

print("\nOK")
