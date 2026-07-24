#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
testio.py - Test the LoxBerry::IO port (HTTP to the Miniserver + MQTT).
Analogous to the Perl testio_* scripts.

Runs on a live LoxBerry: needs a reachable Miniserver for the HTTP part and a
running MQTT broker for the MQTT part.
"""

import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from loxberry import io
from loxberry import system

print("=== mqtt_connectiondetails ===")
cred = io.mqtt_connectiondetails()
print("  brokeraddress:", cred.get("brokeraddress"))
print("  brokeruser   :", cred.get("brokeruser"))
print("  tls          :", cred.get("tls"))

print("\n=== MQTT publish / retain / get round-trip ===")
topic = "pythonlib/testio"
print("  mqtt_retain ->", io.mqtt_retain(topic, "test-value-123"))
time.sleep(0.3)
print("  mqtt_get    ->", repr(io.mqtt_get(topic, 1000)))
io.mqtt_set(topic, "", retain=True)   # clear retained value

print("\n=== mshttp_call (Miniserver 1) ===")
ms = system.get_miniservers()
if ms:
    val, code, raw = io.mshttp_call(1, "/dev/cfg/mac")
    print("  /dev/cfg/mac -> code=%r value=%r" % (code, val))
    content, info = io.mshttp_call2(1, "/jdev/cfg/version")
    print("  mshttp_call2 /jdev/cfg/version -> code=%s error=%s message=%s"
          % (info.get("code"), info.get("error"), info.get("message")))
else:
    print("  (no miniserver configured)")

print("\nOK")
