# -*- coding: utf-8 -*-
"""
loxberry.system - Python port of LoxBerry::System (Fundament scope).

Public API mirrors the Perl master (libs/perllib/LoxBerry/System.pm) 1:1.

Usage:
    from loxberry import system as lb
    print(lb.lbhomedir, lb.lbpconfigdir)
    for msnr, ms in lb.get_miniservers().items():
        print(msnr, ms["Name"], ms["IPAddress"])
"""

from __future__ import annotations

from .core import (
    # Path variables (module attributes, set at import time)
    lbhomedir,
    lbpplugindir,
    lbpconfigdir,
    lbpbindir,
    lbpdatadir,
    lbplogdir,
    lbphtmldir,
    lbphtmlauthdir,
    lbcgidir,
    lbptemplatedir,
    lbsconfigdir,
    lbsdatadir,
    lbslogdir,
    lbstmpfslogdir,
    lbstemplatedir,
    lbshtmldir,
    lbshtmlauthdir,
    lbsbindir,
    lbssbindir,
    reboot_required_file,
    reboot_force_popup_file,
    PLUGINDATABASE,
    # Config / system
    read_generaljson,
    lbversion,
    systemloglevel,
    # Miniserver
    get_miniservers,
    get_miniserver_by_ip,
    get_miniserver_by_name,
    get_ftpport,
    # Network / host
    get_localip,
    lbhostname,
    lbfriendlyname,
    lbwebserverport,
    # Language
    lblanguage,
    lbcountry,
    readlanguage,
    # Boolean / string helpers
    is_enabled,
    is_disabled,
    begins_with,
    trim,
    ltrim,
    rtrim,
    # Time
    currtime,
    epoch2lox,
    lox2epoch,
    tz_offset,
    # Misc
    reboot_required,
    bytes_humanreadable,
    vers_tag,
    plugin_version_compare,
    plugin_version_has_prerelease,
    # File helpers
    read_file,
    write_file,
)

__all__ = [
    "lbhomedir", "lbpplugindir", "lbpconfigdir", "lbpbindir", "lbpdatadir",
    "lbplogdir", "lbphtmldir", "lbphtmlauthdir", "lbcgidir", "lbptemplatedir",
    "lbsconfigdir", "lbsdatadir", "lbslogdir", "lbstmpfslogdir", "lbstemplatedir",
    "lbshtmldir", "lbshtmlauthdir", "lbsbindir", "lbssbindir",
    "reboot_required_file", "reboot_force_popup_file", "PLUGINDATABASE",
    "read_generaljson", "lbversion", "systemloglevel",
    "get_miniservers", "get_miniserver_by_ip", "get_miniserver_by_name",
    "get_ftpport", "get_localip", "lbhostname", "lbfriendlyname",
    "lbwebserverport", "lblanguage", "lbcountry", "readlanguage",
    "is_enabled", "is_disabled", "begins_with", "trim", "ltrim", "rtrim",
    "currtime", "epoch2lox", "lox2epoch", "tz_offset",
    "reboot_required", "bytes_humanreadable", "vers_tag",
    "plugin_version_compare", "plugin_version_has_prerelease",
    "read_file", "write_file",
]
