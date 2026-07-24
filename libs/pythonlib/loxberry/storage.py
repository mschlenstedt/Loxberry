# -*- coding: utf-8 -*-
"""
loxberry.storage - Python port of the Perl master library LoxBerry::Storage.

Enumerate the storage locations LoxBerry knows about: network shares, their
servers, USB storage devices, and a unified list (get_storage).

    get_netshares(readwriteonly, forcereload)
    get_netservers()
    get_usbstorage(sizeunit, readwriteonly)
    get_storage(readwriteonly, localdir)

The HTML helper get_storage_html is intentionally not ported (web frontend).
"""

from __future__ import annotations

import os

from . import system

__version__ = "3.0.0.1"

_netshares_cache = None


def _storage_root():
    return "%s/system/storage" % system.lbhomedir


def _listdir(path):
    try:
        return [e for e in os.listdir(path) if e not in (".", "..")]
    except OSError:
        return None


def _rw_state(path):
    """Return 'Writable', 'Readonly' or '' for a directory (like the Perl touch test)."""
    if not os.path.isdir(path):
        return ""
    state = "Readonly"
    tmp = os.path.join(path, "check_loxberry_rw_state.tmp")
    try:
        with open(tmp, "w"):
            pass
        state = "Writable"
        os.unlink(tmp)
    except OSError:
        pass
    return state


def get_netshares(readwriteonly=False, forcereload=False):
    """Return a list of network share dicts (keys prefixed NETSHARE_)."""
    global _netshares_cache
    if _netshares_cache is not None and not forcereload:
        return _netshares_cache

    root = _storage_root()
    sharetypes = _listdir(root)
    if sharetypes is None:
        return None

    netshares = []
    count = 0
    for type_ in sharetypes:
        if type_ == "usb":
            continue
        servers = _listdir(os.path.join(root, type_))
        if servers is None:
            continue
        for server in servers:
            shares = _listdir(os.path.join(root, type_, server))
            if shares is None:
                continue
            for share in shares:
                sharepath = os.path.join(root, type_, server, share)
                state = _rw_state(sharepath)
                if (readwriteonly and state != "Writable") or not state:
                    continue
                info = system.diskspaceinfo(sharepath) or {}
                count += 1
                netshares.append({
                    "NETSHARE_NO": count,
                    "NETSHARE_SERVER": server,
                    "NETSHARE_TYPE": type_,
                    "NETSHARE_SERVERPATH": os.path.join(root, type_, server),
                    "NETSHARE_SHAREPATH": sharepath,
                    "NETSHARE_SHARENAME": share,
                    "NETSHARE_STATE": state,
                    "NETSHARE_USED": info.get("used"),
                    "NETSHARE_USED_HR": system.bytes_humanreadable(info.get("used") or 0, "k"),
                    "NETSHARE_AVAILABLE": info.get("available"),
                    "NETSHARE_AVAILABLE_HR": system.bytes_humanreadable(info.get("available") or 0, "k"),
                    "NETSHARE_SIZE": info.get("size"),
                    "NETSHARE_SIZE_HR": system.bytes_humanreadable(info.get("size") or 0, "k"),
                    "NETSHARE_USEDPERCENT": info.get("usedpercent"),
                })
    _netshares_cache = netshares
    return netshares


def _samba_username(server):
    credfile = "%s/system/samba/credentials/%s" % (system.lbhomedir, server)
    content = system.read_file(credfile)
    if content is None:
        return ""
    # Config::Simple "default.username" -> [default] username=...
    section = "default"
    for line in content.split("\n"):
        line = line.strip()
        if line.startswith("[") and line.endswith("]"):
            section = line[1:-1]
            continue
        if section == "default" and "=" in line:
            k, v = line.split("=", 1)
            if k.strip() == "username":
                return v.strip()
    return ""


def get_netservers():
    """Return a list of network share server dicts (keys prefixed NETSERVER_)."""
    root = _storage_root()
    sharetypes = _listdir(root)
    if sharetypes is None:
        return None

    netservers = []
    count = 0
    for type_ in sharetypes:
        if type_ == "usb":
            continue
        servers = _listdir(os.path.join(root, type_))
        if servers is None:
            continue
        serveruser = {}
        for server in servers:
            count += 1
            entry = {
                "NETSERVER_NO": count,
                "NETSERVER_SERVER": server,
                "NETSERVER_TYPE": type_,
                "NETSERVER_SERVERPATH": os.path.join(root, type_, server),
            }
            if type_ == "smb" and server not in serveruser:
                serveruser[server] = _samba_username(server)
            entry["NETSERVER_USERNAME"] = serveruser.get(server, "")
            netservers.append(entry)
    return netservers


def get_usbstorage(sizeunit="", readwriteonly=False):
    """Return a list of USB storage device dicts (keys prefixed USBSTORAGE_)."""
    sizeunit = (sizeunit or "").lower()
    root = "%s/usb" % _storage_root()
    devices = _listdir(root)
    if devices is None:
        return None

    usbstorages = []
    count = 0
    for device in devices:
        devpath = os.path.join(root, device)
        disk = system.diskspaceinfo(devpath) or {}

        def _num(v):
            try:
                return float(v)
            except (TypeError, ValueError):
                return 0.0

        if sizeunit == "h":
            used = system.bytes_humanreadable(disk.get("used") or 0, "k")
            size = system.bytes_humanreadable(disk.get("size") or 0, "k")
            available = system.bytes_humanreadable(disk.get("available") or 0, "k")
        elif sizeunit == "mb":
            used = "%.1f" % (_num(disk.get("used")) / 1024)
            available = "%.1f" % (_num(disk.get("available")) / 1024)
            size = "%.1f" % (_num(disk.get("size")) / 1024)
        elif sizeunit == "gb":
            used = "%.1f" % (_num(disk.get("used")) / 1024 / 1024)
            available = "%.1f" % (_num(disk.get("available")) / 1024 / 1024)
            size = "%.1f" % (_num(disk.get("size")) / 1024 / 1024)
        else:
            used = disk.get("used")
            available = disk.get("available")
            size = disk.get("size")

        fstype = _blkid_fstype(disk.get("filesystem"))
        state = _rw_state(devpath)
        if (readwriteonly and state != "Writable") or not state:
            continue
        count += 1
        usbstorages.append({
            "USBSTORAGE_NO": count,
            "USBSTORAGE_DEVICE": device,
            "USBSTORAGE_BLOCKDEVICE": disk.get("filesystem"),
            "USBSTORAGE_TYPE": fstype,
            "USBSTORAGE_STATE": state,
            "USBSTORAGE_USED": used,
            "USBSTORAGE_SIZE": size,
            "USBSTORAGE_AVAILABLE": available,
            "USBSTORAGE_CAPACITY": disk.get("usedpercent"),
            "USBSTORAGE_USEDPERCENT": disk.get("usedpercent"),
            "USBSTORAGE_DEVICEPATH": devpath,
        })
    return usbstorages


def _blkid_fstype(blockdevice):
    if not blockdevice:
        return ""
    from .proc import execute
    rc, out, err = execute("blkid -o udev %s" % blockdevice)
    if rc != 0:
        return ""
    for line in out.split("\n"):
        if line.startswith("ID_FS_TYPE="):
            return line.split("=", 1)[1].strip()
    return ""


def _size_gb(size_kb):
    try:
        return int(float(size_kb) / 1024 / 1024 + 0.5)
    except (TypeError, ValueError):
        return 0


def get_storage(readwriteonly=False, localdir=None):
    """Return a unified list of all storage locations (network, usb, local)."""
    storages = []

    for netshare in (get_netshares(readwriteonly) or []):
        size_gb = _size_gb(netshare.get("NETSHARE_SIZE"))
        storages.append({
            "GROUP": "net",
            "TYPE": netshare.get("NETSHARE_TYPE"),
            "PATH": netshare.get("NETSHARE_SHAREPATH"),
            "WRITABLE": 1 if netshare.get("NETSHARE_STATE") == "Writable" else 0,
            "AVAILABLE": netshare.get("NETSHARE_AVAILABLE"),
            "USED": netshare.get("NETSHARE_USED"),
            "SIZE": netshare.get("NETSHARE_SIZE"),
            "SIZE_GB": size_gb,
            "NAME": "%s::%s (%s GB)" % (netshare.get("NETSHARE_SERVER"),
                                       netshare.get("NETSHARE_SHARENAME"), size_gb),
            "NETSHARE_SERVER": netshare.get("NETSHARE_SERVER"),
            "NETSHARE_SHARENAME": netshare.get("NETSHARE_SHARENAME"),
        })

    for usb in (get_usbstorage("", readwriteonly) or []):
        size_gb = _size_gb(usb.get("USBSTORAGE_SIZE"))
        storages.append({
            "GROUP": "usb",
            "TYPE": usb.get("USBSTORAGE_TYPE"),
            "PATH": usb.get("USBSTORAGE_DEVICEPATH"),
            "WRITABLE": 1 if usb.get("USBSTORAGE_STATE") == "Writable" else 0,
            "AVAILABLE": usb.get("USBSTORAGE_AVAILABLE"),
            "USED": usb.get("USBSTORAGE_USED"),
            "SIZE": usb.get("USBSTORAGE_SIZE"),
            "SIZE_GB": size_gb,
            "NAME": "USB::%s (%s GB)" % (usb.get("USBSTORAGE_DEVICE"), size_gb),
            "USBSTORAGE_DEVICE": usb.get("USBSTORAGE_DEVICE"),
            "USBSTORAGE_BLOCKDEVICE": usb.get("USBSTORAGE_BLOCKDEVICE"),
        })

    path = localdir if localdir else system.lbpdatadir
    if path:
        disk = system.diskspaceinfo(path) or {}
        size_gb = _size_gb(disk.get("size"))
        storages.append({
            "GROUP": "local",
            "TYPE": "local",
            "PATH": path,
            "WRITABLE": 1,
            "AVAILABLE": disk.get("available"),
            "USED": disk.get("used"),
            "SIZE": disk.get("size"),
            "SIZE_GB": size_gb,
            "NAME": "Local Datadir (%s GB)" % size_gb,
        })
    return storages
