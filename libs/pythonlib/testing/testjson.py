#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
testjson.py - Test the LoxBerryJSON file object.
Analogous to the Perl json_* testing scripts.
"""

import os
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from loxberry.json import LoxBerryJSON

path = os.path.join(tempfile.gettempdir(), "pythonlib_testjson.json")
if os.path.exists(path):
    os.unlink(path)

print("=== create (file missing -> empty object) ===")
obj = LoxBerryJSON()
cfg = obj.open(filename=path)
cfg["MAIN"] = {"enabled": True, "name": "Test", "list": [10, 20, 30]}
print("  write (new):", obj.write())

print("\n=== reopen and read ===")
obj2 = LoxBerryJSON()
cfg2 = obj2.open(filename=path)
print("  object:", cfg2)
print("  param('MAIN.name')   =", obj2.param("MAIN.name"))
print("  param('MAIN.list.1') =", obj2.param("MAIN.list.1"))
print("  flatten keys         =", sorted(obj2.flatten().keys()))

print("\n=== 'only write if changed' ===")
print("  write unchanged (expect None):", obj2.write())
cfg2["MAIN"]["enabled"] = False
print("  write changed   (expect 1)  :", obj2.write())

print("\n=== find (callable predicate) ===")
idx = LoxBerryJSON.find(cfg2["MAIN"]["list"], lambda v: v >= 20)
print("  indices with value >= 20:", idx)

print("\n=== file content ===")
print(open(path).read())

os.unlink(path)
print("OK")
