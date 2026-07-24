# -*- coding: utf-8 -*-
"""
loxberry.system.plugindb - plugin database accessors.

Python port of the get_plugins / plugindata / pluginversion / pluginloglevel
functions of the Perl master LoxBerry::System (System.pm) and its PluginDB
handling. Reads data/system/plugindatabase.json.
"""

from __future__ import annotations

import json
import os
import re
import time

from . import core


def _numify(value):
    """Perl-style numeric coercion of a scalar (undef/''/text -> 0)."""
    if value is None:
        return 0
    if isinstance(value, bool):
        return 1 if value else 0
    if isinstance(value, (int, float)):
        return value
    m = re.match(r"\s*(-?\d+(?:\.\d+)?)", str(value))
    if not m:
        return 0
    num = m.group(1)
    return float(num) if "." in num else int(num)

# Module-internal caches (mirror the Perl "my" state variables)
_state = {
    "plugins": None,               # list or None
    "pluginversion": None,
    "plugindb_timestamp": 0,
    "plugindb_timestamp_last": 0,
    "plugindb_lastchecked": 0,
}


def plugindb_changed_time() -> int:
    """Return the mtime of the plugin database. Only really checks every minute."""
    if _state["plugindb_timestamp"] == 0 or _state["plugindb_lastchecked"] + 60 < time.time():
        try:
            _state["plugindb_timestamp"] = int(os.stat(core.PLUGINDATABASE).st_mtime)
        except OSError:
            _state["plugindb_timestamp"] = 0
        _state["plugindb_lastchecked"] = int(time.time())
    return _state["plugindb_timestamp"]


def get_plugins(force: bool = False) -> list:
    """Return all plugins as a list of dicts (keys prefixed PLUGINDB_)."""
    # When the plugindb has changed, always force a reload
    changed = plugindb_changed_time()
    if _state["plugindb_timestamp_last"] != changed:
        force = True
        _state["plugindb_timestamp_last"] = changed

    if _state["plugins"] is not None and not force:
        return _state["plugins"]

    raw = core.read_file(core.PLUGINDATABASE)
    if raw is None:
        return []
    try:
        data = json.loads(raw)
    except ValueError:
        return []
    if not data:
        return []

    plugindict = data.get("plugins", {}) or {}

    def _title(key):
        return str((plugindict.get(key) or {}).get("title") or "").lower()

    plugins = []
    count = 0
    for key in sorted(plugindict.keys(), key=_title):
        pd = plugindict.get(key) or {}
        count += 1
        folder = pd.get("folder")
        loglevel = pd.get("loglevel")

        plugin = {
            "PLUGINDB_NO": count,
            "PLUGINDB_MD5_CHECKSUM": pd.get("md5"),
            "PLUGINDB_AUTHOR_NAME": pd.get("author_name"),
            "PLUGINDB_AUTHOR_EMAIL": pd.get("author_email"),
            "PLUGINDB_PLUGIN_WEBSITE": pd.get("plugin_website") or "",
            "PLUGINDB_VERSION": pd.get("version"),
            "PLUGINDB_NAME": pd.get("name"),
            "PLUGINDB_FOLDER": folder,
            "PLUGINDB_TITLE": pd.get("title"),
            "PLUGINDB_INTERFACE": pd.get("interface"),
            "PLUGINDB_AUTOUPDATE": pd.get("autoupdate"),
            "PLUGINDB_RELEASECFG": pd.get("releasecfg"),
            "PLUGINDB_PRERELEASECFG": pd.get("prereleasecfg"),
            "PLUGINDB_LOGLEVEL": loglevel,
            "PLUGINDB_LOGLEVELS_ENABLED": 1 if _numify(loglevel) >= 0 else 0,
        }
        iconbase = "%s/images/icons/%s" % (core.lbshtmldir, folder)
        if os.path.exists("%s/icon.svg" % iconbase):
            plugin["PLUGINDB_ICONURI"] = "/system/images/icons/%s/icon.svg" % folder
            plugin["PLUGINDB_ICONURI_LARGE"] = "/system/images/icons/%s/icon.svg" % folder
        else:
            plugin["PLUGINDB_ICONURI"] = "/system/images/icons/%s/icon_64.png" % folder
            plugin["PLUGINDB_ICONURI_LARGE"] = "/system/images/icons/%s/icon_128.png" % folder
        plugins.append(plugin)

    _state["plugins"] = plugins
    return plugins


def plugindata(queryname=None):
    """Return the plugindata dict of the current (or named) plugin, or None."""
    query = queryname if queryname is not None else core.lbpplugindir
    for plugin in get_plugins():
        if queryname and (plugin.get("PLUGINDB_NAME") == query
                          or plugin.get("PLUGINDB_FOLDER") == query):
            return plugin
        if not queryname and plugin.get("PLUGINDB_FOLDER") == query:
            _state["pluginversion"] = plugin.get("PLUGINDB_VERSION")
            return plugin
    return None


def pluginversion(queryname=""):
    """Return the plugin version from the plugin database."""
    if _state["pluginversion"] and not queryname:
        return _state["pluginversion"]
    query = queryname if queryname else core.lbpplugindir
    plugin = plugindata(query)
    return plugin.get("PLUGINDB_VERSION") if plugin else None


def pluginloglevel(queryname=""):
    """Return the plugin loglevel from the plugin database (0 if unset)."""
    query = queryname if queryname else core.lbpplugindir
    plugin = plugindata(query)
    # Perl treats the loglevel numerically, so a "0" string is falsy too.
    if plugin and _numify(plugin.get("PLUGINDB_LOGLEVEL")):
        return plugin.get("PLUGINDB_LOGLEVEL")
    return 0
