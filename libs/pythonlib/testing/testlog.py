#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
testlog.py - Test the LBLog logging class and the notification functions.
Analogous to perllib/LoxBerry/testing/testlog.pl.

Creates a temporary log session (package 'testing'), writes messages at all
levels, ends the session, reads it back via get_logs, and exercises the
notification functions. Cleans up after itself.
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from loxberry.log import LBLog
from loxberry import log as loglib
from loxberry import system

logdir = "%s/log/system" % system.lbhomedir
if not os.path.isdir(logdir):
    logdir = "/tmp"

print("=== create session and write all levels ===")
log = LBLog(name="pythonlib_testlog", package="core", logdir=logdir,
            loglevel=7, addtime=True)
log.LOGSTART("Log module self-test")
log.DEB("debug message")
log.INF("info message")
log.OK("ok message")
log.WARN("warning message")
log.ERR("error message")
log.LOGEND("finished")

print("  logfile:", log.get_filename())
print("  dbkey  :", log.get_dbkey())

print("\n=== read back via get_logs ===")
logs = loglib.get_logs("core", "pythonlib_testlog")
if logs:
    l = logs[-1]
    print("  STATUS=%s (3=error was the most severe)" % l.get("STATUS"))
    print("  LOGSTARTSTR=%s  LOGENDSTR=%s" % (l.get("LOGSTARTSTR"), l.get("LOGENDSTR")))

print("\n=== logfile content ===")
print(open(log.get_filename()).read())

print("=== notifications ===")
loglib.notify("core", "pythonlib_testlog", "info notification", error=False)
loglib.notify("core", "pythonlib_testlog", "error notification", error=True)
print("  get_notification_count:", loglib.get_notification_count("core", "pythonlib_testlog"))
n = loglib.delete_notifications("core", "pythonlib_testlog")
print("  deleted %s notification(s)" % n)

# Clean up the test logfile so it does not linger in the Log Manager
try:
    os.unlink(log.get_filename())
except OSError:
    pass

print("\nOK")
