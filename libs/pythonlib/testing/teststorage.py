#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
teststorage.py - Test the LoxBerry::Storage port.
Analogous to the Perl storage tests.
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from loxberry import storage

print("=== get_netservers ===")
for s in (storage.get_netservers() or []):
    print("  #%s %s (%s) user=%r"
          % (s["NETSERVER_NO"], s["NETSERVER_SERVER"], s["NETSERVER_TYPE"],
             s.get("NETSERVER_USERNAME")))

print("\n=== get_netshares ===")
for s in (storage.get_netshares() or []):
    print("  #%s %s::%s state=%s size=%s"
          % (s["NETSHARE_NO"], s["NETSHARE_SERVER"], s["NETSHARE_SHARENAME"],
             s["NETSHARE_STATE"], s.get("NETSHARE_SIZE_HR")))

print("\n=== get_usbstorage ===")
usb = storage.get_usbstorage("h") or []
print("  %d USB device(s)" % len(usb))
for s in usb:
    print("  #%s %s (%s) %s" % (s["USBSTORAGE_NO"], s["USBSTORAGE_DEVICE"],
                                s["USBSTORAGE_TYPE"], s["USBSTORAGE_SIZE"]))

print("\n=== get_storage (unified, with local datadir) ===")
for s in storage.get_storage(localdir="%s/data" % storage.system.lbhomedir):
    print("  [%-5s] %-40s writable=%s size=%sGB"
          % (s["GROUP"], s["NAME"], s["WRITABLE"], s["SIZE_GB"]))

print("\nOK")
