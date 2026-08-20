# -*- coding: utf-8 -*-
"""
loxberry.json - Python port of the Perl master library LoxBerry::JSON.

A JSON file object: open a file, work with the returned dict/list (by
reference), then write it back. write() only writes if the content actually
changed (important to spare the SD card). Optional file locking.

Usage:
    from loxberry.json import LoxBerryJSON

    jsonobj = LoxBerryJSON()
    cfg = jsonobj.open(filename="/opt/loxberry/config/plugins/x/cfg.json")
    cfg["MAIN"]["enabled"] = True     # mutate the returned object
    jsonobj.write()

    # or write automatically on garbage collection / context exit:
    with LoxBerryJSON() as jsonobj:
        cfg = jsonobj.open(filename=..., writeonclose=True)
        cfg["x"] = 1

Note: inside the loxberry package "import json" resolves to the Python standard
library (absolute imports), so this module name does not shadow it.
"""

from __future__ import annotations

import errno
import json as _json
import os
import sys
import time

__version__ = "2.2.1.4"

try:
    import fcntl  # POSIX file locking
    _HAVE_FCNTL = True
except ImportError:
    _HAVE_FCNTL = False


def _encode(obj, pretty=True):
    if pretty:
        return _json.dumps(obj, indent=3, sort_keys=True, ensure_ascii=False) + "\n"
    return _json.dumps(obj, sort_keys=True, ensure_ascii=False)


class LoxBerryJSON(object):
    def __init__(self):
        self.filename = None
        self.writeonclose = False
        self.readonly = False
        self.lockexclusive = False
        self.locktimeout = None
        self._jsonobj = None
        self._baseline = None
        self._createfile = False

    # ------------------------------------------------------------------
    def parse(self, jsonstring):
        if not jsonstring:
            jsonstring = "{}"
        self._jsonobj = _json.loads(jsonstring)
        return self._jsonobj

    def open(self, filename=None, writeonclose=False, readonly=False,
             lockexclusive=False, locktimeout=None):
        if filename is None:
            raise ValueError("LoxBerryJSON.open: Parameter filename is empty.")
        self.filename = filename
        self.writeonclose = writeonclose
        self.readonly = readonly
        self.lockexclusive = lockexclusive
        self.locktimeout = locktimeout

        content = ""
        if not os.path.exists(filename):
            self._createfile = True
            self._jsonobj = {}
        else:
            try:
                with open(filename, "r", encoding="utf-8") as fh:
                    if _HAVE_FCNTL and not readonly:
                        try:
                            fcntl.flock(fh, fcntl.LOCK_SH)
                        except OSError:
                            pass
                    content = fh.read()
            except OSError:
                return None
            self._jsonobj = self.parse(content)

        # Baseline for the "only write if changed" comparison
        self._baseline = _encode(self._jsonobj)
        return self._jsonobj

    def write(self):
        if self.readonly:
            return None
        if self._jsonobj is None or self.filename is None:
            return None

        new_content = _encode(self._jsonobj)
        if new_content == self._baseline and os.path.exists(self.filename):
            # Nothing changed - do not touch the file (spare the SD card)
            return None

        # Open read-write without truncating (O_RDWR|O_CREAT), NOT mode "w":
        # "w" empties the file the moment it is opened - before the lock is
        # held. While a competing writer holds the lock the file therefore
        # sits at 0 bytes, and it stays empty for good if this process dies
        # in that window. Truncate after writing instead. Mode 0o666 lets the
        # umask decide, exactly as open(..., "w") did.
        try:
            fd = os.open(self.filename, os.O_RDWR | os.O_CREAT, 0o666)
        except OSError:
            return None
        try:
            fh = os.fdopen(fd, "r+", encoding="utf-8")
        except OSError:
            os.close(fd)
            return None

        try:
            with fh:
                if not self._lock_exclusive(fh):
                    return None
                fh.seek(0)
                fh.write(new_content)
                fh.truncate()
        except OSError:
            return None

        self._chown_loxberry()
        self._baseline = new_content
        return 1

    # ------------------------------------------------------------------
    def get_filename(self, newfilename=None):
        if newfilename:
            self.filename = newfilename
        return self.filename

    def param(self, query=None):
        """Dotted access. Without query returns the flattened keys; with a
        dotted query (e.g. 'Base.Lang' or 'list.0.name') returns the scalar."""
        if not query:
            return list(self.flatten().keys())
        ref = self._jsonobj
        for part in query.split("."):
            if isinstance(ref, list):
                try:
                    ref = ref[int(part)]
                except (ValueError, IndexError):
                    return None
            elif isinstance(ref, dict):
                ref = ref.get(part)
            else:
                break
        if isinstance(ref, (dict, list)):
            return None
        return ref

    def flatten(self, prefix=None):
        """Return a flat dict with dotted keys (HashDelimiter/ArrayDelimiter '.')."""
        obj = self._jsonobj
        if prefix:
            obj = {prefix: obj}
        elif isinstance(obj, list):
            obj = {"data": obj}
        result = {}

        def _walk(node, path):
            if isinstance(node, dict):
                if not node:
                    result[path] = {}
                for k, v in node.items():
                    _walk(v, "%s.%s" % (path, k) if path else str(k))
            elif isinstance(node, list):
                if not node:
                    result[path] = []
                for i, v in enumerate(node):
                    _walk(v, "%s.%s" % (path, i) if path else str(i))
            else:
                result[path] = node

        _walk(obj, "")
        return result

    def encode(self, pretty=False):
        return _encode(self._jsonobj, pretty=bool(pretty))

    @staticmethod
    def find(obj, predicate):
        """Return the keys/indices of obj whose value satisfies predicate.

        In contrast to the Perl version (which evals a string expression),
        pass a Python callable, e.g. find(mylist, lambda v: v['x'] == 1).
        """
        result = []
        if isinstance(obj, list):
            for i, v in enumerate(obj):
                if predicate(v):
                    result.append(i)
        elif isinstance(obj, dict):
            for k, v in obj.items():
                if predicate(v):
                    result.append(k)
        return result

    @staticmethod
    def escape(s):
        """Escape a string for inclusion in a single-quoted JS string."""
        if not s:
            return s
        return (s.replace("\\", "\\\\").replace("\r", "\\r")
                 .replace("\n", "\\n").replace("'", "\\'"))

    def jsblock(self, varname="jsondata"):
        """Return a JS statement 'varname = JSON.parse('...');'."""
        js = self.encode()
        if js:
            return "%s = JSON.parse('%s');\n" % (varname, LoxBerryJSON.escape(js))
        return "// LoxBerryJSON.jsblock: JSON Encoder failed.\n"

    # ------------------------------------------------------------------
    def _lock_exclusive(self, fh):
        """Take LOCK_EX with a timeout, mirroring LoxBerry::JSON->write().

        Retries non-blocking every 50ms until self.locktimeout (default 30s)
        expires, instead of blocking forever on a stuck lock holder. Returns
        True if the lock is held (or if the filesystem cannot lock at all -
        writing unlocked is what this library did before).
        """
        if not _HAVE_FCNTL:
            return True
        timeout = self.locktimeout if self.locktimeout is not None else 30
        deadline = time.monotonic() + timeout
        while True:
            try:
                fcntl.flock(fh, fcntl.LOCK_EX | fcntl.LOCK_NB)
                return True
            except OSError as e:
                if e.errno not in (errno.EACCES, errno.EAGAIN):
                    # Locking unsupported on this filesystem - carry on unlocked.
                    return True
            if time.monotonic() >= deadline:
                sys.stderr.write(
                    "LoxBerryJSON.write: ERROR Could not get exclusive lock "
                    "after %s seconds: %s\n" % (timeout, self.filename)
                )
                return False
            time.sleep(0.05)

    def _chown_loxberry(self):
        try:
            import pwd

            pw = pwd.getpwnam("loxberry")
            os.chown(self.filename, pw.pw_uid, pw.pw_gid)
        except Exception:
            pass

    # writeonclose support
    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        if self.writeonclose:
            self.write()
        return False

    def __del__(self):
        try:
            if self.writeonclose:
                self.write()
        except Exception:
            pass
