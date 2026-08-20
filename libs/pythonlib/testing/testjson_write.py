#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
testjson_write.py - Regression test for LoxBerryJSON.write() lock handling.

Python counterpart of libs/perllib/t/json_write.t. Unlike the other scripts in
this directory this one asserts instead of just printing, so it can be used as
a check: it exits non-zero when something breaks.

Run with:
    python3 libs/pythonlib/testing/testjson_write.py

Covers the normal round-trips (create, read back, update, shrink without
trailing garbage) and, as the core regression, a competing process holding the
exclusive lock: write() must give up after locktimeout and must NOT leave the
file truncated to 0 bytes. A watchdog turns a reintroduced hang into a failure
instead of a stuck test run.
"""

import os
import subprocess
import sys
import tempfile
import textwrap
import threading
import time

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from loxberry.json import LoxBerryJSON

FAILED = []


def check(ok, what):
    print("  %-4s %s" % ("ok" if ok else "FAIL", what))
    if not ok:
        FAILED.append(what)


def watchdog(seconds, message):
    """Kill the process if we are still running after `seconds` - a hanging
    write() must fail the test, not block the run forever."""
    def boom():
        sys.stderr.write("TIMEOUT: %s\n" % message)
        os._exit(3)
    t = threading.Timer(seconds, boom)
    t.daemon = True
    t.start()
    return t


tmpdir = tempfile.mkdtemp(prefix="lbjsonwrite_")

print("=== round-trip: create, read back, update, shrink ===")
path = os.path.join(tmpdir, "roundtrip.json")

obj = LoxBerryJSON()
cfg = obj.open(filename=path)
cfg["hello"] = "welt"
cfg["zahl"] = 42
check(obj.write() == 1, "write() creates and writes a new file")

cfg2 = LoxBerryJSON().open(filename=path, readonly=True)
check(cfg2.get("hello") == "welt", "value read back after create")
check(cfg2.get("zahl") == 42, "second value read back")

obj3 = LoxBerryJSON()
cfg3 = obj3.open(filename=path)
cfg3["zahl"] = 99
obj3.write()
check(LoxBerryJSON().open(filename=path, readonly=True).get("zahl") == 99,
      "existing value updated")

# Write strictly less content than before -> no stale bytes may survive.
obj4 = LoxBerryJSON()
cfg4 = obj4.open(filename=path)
cfg4.clear()
cfg4["x"] = 1
obj4.write()
cfg5 = LoxBerryJSON().open(filename=path, readonly=True)
check("hello" not in cfg5, "shrunk file: stale key gone (truncated correctly)")
check(cfg5.get("x") == 1, "shrunk file: new content intact")

print("\n=== unchanged content is not rewritten (spare the SD card) ===")
obj6 = LoxBerryJSON()
obj6.open(filename=path)
check(obj6.write() is None, "write() without changes returns None")

print("\n=== a competing process holds the exclusive lock ===")
locked = os.path.join(tmpdir, "locked.json")
init = LoxBerryJSON()
initcfg = init.open(filename=locked)
initcfg["keep"] = "MUST SURVIVE"
init.write()
before = open(locked, "r", encoding="utf-8").read()

holder_src = textwrap.dedent("""
    import fcntl, sys, time
    fh = open(sys.argv[1], "r+")
    fcntl.flock(fh, fcntl.LOCK_EX)
    print("locked", flush=True)
    time.sleep(float(sys.argv[2]))
""")
# Open BEFORE the competing process takes the lock. open() reads under a
# blocking LOCK_SH, so opening afterwards would sit out the whole contention
# window and write() would then find the file free - the test would pass
# against a broken write(). This order also mirrors real usage: read the
# config, then someone else grabs the lock, then write it back.
writer = LoxBerryJSON()
wcfg = writer.open(filename=locked)
writer.locktimeout = 1

holder = subprocess.Popen([sys.executable, "-c", holder_src, locked, "5"],
                          stdout=subprocess.PIPE)
check(holder.stdout.readline().strip() == b"locked", "helper process holds LOCK_EX")

# Watch the file size WHILE write() is running. This is the actual regression:
# opening with mode "w" empties the file before the lock is held, so the size
# drops to 0 for as long as the other process holds it. Checking only after
# write() returned would miss that window entirely.
sizes = []
sampling = threading.Event()


def sampler():
    while not sampling.is_set():
        try:
            sizes.append(os.path.getsize(locked))
        except OSError:
            pass
        time.sleep(0.01)


sampler_thread = threading.Thread(target=sampler)
sampler_thread.daemon = True
sampler_thread.start()

# 20s watchdog: without the fix write() blocks until the holder is gone
# (in the Perl original it spun forever).
wd = watchdog(20, "write() did not return while the lock was held")
wcfg["keep"] = "OVERWRITTEN"
started = time.monotonic()
result = writer.write()
elapsed = time.monotonic() - started
wd.cancel()
sampling.set()
sampler_thread.join()

check(result is None, "write() gives up and returns None (%.2fs)" % elapsed)
check(elapsed < 4, "write() returned before the holder released (no blocking)")
check(sizes and min(sizes) > 0,
      "file never drops to 0 bytes during the attempt (min observed: %s)"
      % (min(sizes) if sizes else "n/a"))
check(os.path.getsize(locked) > 0, "file is NOT truncated to 0 bytes on lock failure")
check(open(locked, "r", encoding="utf-8").read() == before,
      "file content is left completely intact")

holder.wait()

print("\n=== the same write succeeds once the lock is free ===")
writer2 = LoxBerryJSON()
wcfg2 = writer2.open(filename=locked)
wcfg2["keep"] = "OVERWRITTEN"
check(writer2.write() == 1, "write() succeeds without contention")
check(LoxBerryJSON().open(filename=locked, readonly=True).get("keep") == "OVERWRITTEN",
      "new content is on disk")

for f in os.listdir(tmpdir):
    os.unlink(os.path.join(tmpdir, f))
os.rmdir(tmpdir)

print("")
if FAILED:
    print("FAILED %d test(s):" % len(FAILED))
    for f in FAILED:
        print("  - %s" % f)
    sys.exit(1)
print("All tests passed.")
