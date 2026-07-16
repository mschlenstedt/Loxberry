# -*- coding: utf-8 -*-
"""
loxberry.log - Python port of the Perl master library LoxBerry::Log.

Provides the LBLog logging class (with a session registered in LoxBerry's
SQLite log database, so the log appears in the LoxBerry Log Manager) and the
notification functions (notify, get_notification_count, ...).

Usage:
    from loxberry.log import LBLog
    log = LBLog(name="mylog", package="myplugin", addtime=True)
    log.LOGSTART("Task started")
    log.INF("Doing something")
    log.ERR("Something went wrong")
    log.LOGEND("Task finished")

    from loxberry import log
    log.notify("myplugin", "mylog", "A message", error=True)
    err, ok, total = log.get_notification_count("myplugin")

Note: the SQLite schema and the logfile format match the Perl master. Not every
incidental internal attribute of the Perl object is mirrored into logs_attr -
the attributes the Log Manager uses (STATUS, PLUGINTITLE, LOGSTART/ENDMESSAGE,
LOGSTARTBYTE, ...) are. notify_send_mail (E-Mail dispatch) is not ported yet.
"""

from __future__ import annotations

import glob
import os
import sqlite3
import time as _time
from datetime import datetime

from . import system

__version__ = "3.0.0.4"

SEVERITYLIST = {
    0: "EMERGE", 1: "ALERT", 2: "CRITICAL", 3: "ERROR",
    4: "WARNING", 5: "OK", 6: "INFO", 7: "DEBUG",
}

_DEBUG = bool(os.environ.get("LOXBERRY_LOG_DEBUG"))


def _logdbfile():
    return "%s/log/system_tmpfs/logs_sqlite.dat" % system.lbhomedir


def _notifydbfile():
    return "%s/notifications_sqlite.dat" % system.lbsdatadir


def _chown_loxberry(path):
    try:
        import pwd

        st = os.stat(path)
        if pwd.getpwuid(st.st_uid).pw_name != "loxberry":
            pw = pwd.getpwnam("loxberry")
            os.chown(path, pw.pw_uid, pw.pw_gid)
    except Exception:
        pass


# ---------------------------------------------------------------------------
# Log session database (logs / logs_attr)
# ---------------------------------------------------------------------------
def _log_db_init():
    dbfile = _logdbfile()
    try:
        dbh = sqlite3.connect(dbfile, timeout=5.0)
    except sqlite3.Error as exc:
        if _DEBUG:
            print("log_db_init connect: %s" % exc)
        return None
    dbh.execute("PRAGMA journal_mode = wal;")
    dbh.execute("PRAGMA busy_timeout = 5000;")
    dbh.execute("""CREATE TABLE IF NOT EXISTS logs (
        PACKAGE VARCHAR(255) NOT NULL,
        NAME VARCHAR(255) NOT NULL,
        FILENAME VARCHAR (2048) NOT NULL,
        LOGSTART DATETIME,
        LOGEND DATETIME,
        LASTMODIFIED DATETIME NOT NULL,
        LOGKEY INTEGER PRIMARY KEY
    )""")
    dbh.execute("""CREATE TABLE IF NOT EXISTS logs_attr (
        keyref INTEGER NOT NULL,
        attrib VARCHAR(255) NOT NULL,
        value VARCHAR(255),
        PRIMARY KEY ( keyref, attrib )
    )""")
    dbh.commit()
    _chown_loxberry(dbfile)
    return dbh


class LBLog(object):
    def __init__(self, name=None, filename=None, logdir=None, append=False,
                 package=None, loglevel=None, stderr=False, stdout=False,
                 nofile=False, addtime=False, dbkey=None, nosession=False):
        self.name = name
        self.filename = filename
        self.logdir = logdir
        self.append = append
        self.package = package
        self.loglevel = loglevel
        self.stderr = stderr
        self.stdout = stdout
        self.nofile = nofile
        self.autoraise = 1
        self.addtime = addtime
        self.dbkey = dbkey
        self.nosession = nosession
        self.loglevel_is_static = False

        self._fh = None
        self._dbh = None
        self._next_db_check = 0
        self._plugindb_timestamp = 0
        self.STATUS = None
        self.ATTENTIONMESSAGES = ""
        self.LOGSTARTMESSAGE = None
        self.LOGENDMESSAGE = None
        self.LOGSTARTBYTE = 0
        self.PLUGINTITLE = None
        self._isplugin = 0
        self._logend_called = False

        if system.is_enabled(self.nosession):
            self.append = True

        if not self.nofile:
            if not self.package:
                if system.lbpplugindir:
                    self.package = system.lbpplugindir
                if not self.package:
                    raise ValueError("A 'package' must be defined if this log is not from a plugin")

            if not self.logdir and not self.filename and system.lbplogdir \
                    and os.path.exists(system.lbplogdir):
                self.logdir = system.lbplogdir

            if self.logdir and not self.filename:
                self.filename = "%s/%s_%s.log" % (
                    self.logdir, system.currtime("filehires"), self.name)
            elif not self.filename:
                if system.lbplogdir and os.path.exists(system.lbplogdir):
                    self.filename = "%s/%s_%s.log" % (
                        system.lbplogdir, system.currtime("filehires"), self.name)
                else:
                    raise ValueError("Cannot determine plugin log directory")

        # Loglevel
        if self.loglevel is None:
            pd = system.plugindata(self.package)
            if pd and pd.get("PLUGINDB_LOGLEVEL") is not None:
                self.loglevel = int(_numify(pd.get("PLUGINDB_LOGLEVEL")))
            else:
                self.loglevel = 7
                self.loglevel_is_static = True
        else:
            self.loglevel = int(self.loglevel)
            self.loglevel_is_static = True

        if not self.append and not self.nofile:
            try:
                os.unlink(self.filename)
            except OSError:
                pass
            d = os.path.dirname(self.filename)
            if d and not os.path.isdir(d):
                try:
                    os.makedirs(d, exist_ok=True)
                    _chown_loxberry(d)
                except OSError:
                    pass

        if not self.nofile and (system.is_enabled(self.nosession) or self.append):
            self._dbh = _log_db_init()

    # ------------------------------------------------------------------
    def loglevel_get(self):
        return self.loglevel

    def get_filename(self):
        return self.filename

    def get_dbkey(self):
        return self.dbkey

    # ------------------------------------------------------------------
    def _open(self):
        if self._fh is None and not self.nofile:
            self._fh = open(self.filename, "a", encoding="utf-8")

    def close(self):
        if self._fh is not None:
            try:
                self._fh.close()
            except Exception:
                pass
            self._fh = None

    # ------------------------------------------------------------------
    def write(self, severity, s):
        # Periodic session existence check (re-create if the row is gone)
        if not self.nofile and (not self._next_db_check or _time.time() > self._next_db_check):
            if self._dbh is None:
                self._dbh = _log_db_init()
            self._recreate_session()
            self._next_db_check = _time.time() + 120

        # Dynamic loglevel change from the plugin database
        if not self.loglevel_is_static:
            changed = system.plugindb_changed_time()
            if changed != self._plugindb_timestamp:
                self._plugindb_timestamp = changed
                newlevel = system.pluginloglevel(self.package)
                newlevel = int(_numify(newlevel))
                if 0 <= newlevel <= 7 and newlevel != self.loglevel:
                    old = self.loglevel
                    self.loglevel = newlevel
                    self.write(-1, "<INFO> User changed loglevel from %s to %s" % (old, newlevel))

        # Autoraise
        if 0 <= severity <= 2 and self.loglevel < 6 and self.autoraise == 1:
            self.loglevel = 6
            self.loglevel_is_static = True

        # Track highest severity (lowest number)
        if severity >= 0 and (self.STATUS is None or severity < int(self.STATUS)):
            self.STATUS = str(severity)

        # Collect attention messages (warnings and worse)
        if 0 <= severity <= 4:
            if self.ATTENTIONMESSAGES:
                self.ATTENTIONMESSAGES += "\n"
            self.ATTENTIONMESSAGES += "<%s> %s" % (SEVERITYLIST[severity], s)
            if len(self.ATTENTIONMESSAGES) > 6000:
                self.ATTENTIONMESSAGES = self.ATTENTIONMESSAGES[-5800:]
                nl = self.ATTENTIONMESSAGES.find("\n")
                if nl != -1:
                    self.ATTENTIONMESSAGES = self.ATTENTIONMESSAGES[nl + 1:]

        # Filter by loglevel
        if (self.loglevel != 0 and severity <= self.loglevel) or severity < 0:
            currtime = ""
            if self.addtime and severity > -2:
                currtime = system.currtime("hrtimehires") + " "
            if severity == 7 or severity < 0:
                string = currtime + s + "\n"
            else:
                string = currtime + "<%s> %s\n" % (SEVERITYLIST[severity], s)

            if not self.nofile and self.loglevel != 0:
                self._open()
                if self._fh:
                    self._fh.write(string)
            if self.stderr:
                import sys
                sys.stderr.write(string)
            if self.stdout:
                import sys
                sys.stdout.write(string)

    # ------------------------------------------------------------------
    # Severity methods
    def DEB(self, s):
        self.write(7, s); self.close()

    def INF(self, s):
        self.write(6, s); self.close()

    def OK(self, s):
        self.write(5, s); self.close()

    def WARN(self, s):
        self.write(4, s); self.close()

    def ERR(self, s):
        self.write(3, s); self.close()

    def CRIT(self, s):
        self.write(2, s); self.close()

    def ALERT(self, s):
        self.write(1, s); self.close()

    def EMERGE(self, s):
        self.write(0, s); self.close()

    # ------------------------------------------------------------------
    def LOGSTART(self, s=""):
        if not system.is_enabled(self.nosession):
            try:
                self.LOGSTARTBYTE = os.path.getsize(self.filename) if os.path.exists(self.filename) else 0
            except OSError:
                self.LOGSTARTBYTE = 0
            self.write(-2, "=" * 80)
            self.write(-2, "<LOGSTART> " + system.currtime() + " TASK STARTED")
            self.write(-2, "<LOGSTART> " + s)
        if s:
            self.LOGSTARTMESSAGE = s

        is_files = [os.path.basename(f) for f in
                    glob.glob("%s/is_*.cfg" % system.lbsconfigdir)]
        is_file_str = " ".join(is_files)
        if is_file_str:
            is_file_str = "( " + is_file_str + " )"

        plugin = system.plugindata(self.package)
        if plugin and plugin.get("PLUGINDB_TITLE"):
            self.PLUGINTITLE = plugin.get("PLUGINDB_TITLE")
            self._isplugin = 1

        if not system.is_enabled(self.nosession) or not os.path.exists(self.filename):
            self.write(-1, "<INFO> LoxBerry Version %s %s" % (system.lbversion(), is_file_str))
            if plugin:
                self.write(-1, "<INFO> %s Version %s" % (
                    plugin.get("PLUGINDB_TITLE"), plugin.get("PLUGINDB_VERSION")))
            self.write(-1, "<INFO> Loglevel: %s" % self.loglevel)

        if system.is_enabled(self.nosession):
            self.OK(s)

        if not self.nofile:
            if self._dbh is None:
                self._dbh = _log_db_init()
            if not system.is_enabled(self.nosession):
                self.dbkey = self._log_db_logstart()
        self.close()

    def LOGEND(self, s=""):
        if not system.is_enabled(self.nosession):
            if s:
                self.write(-2, "<LOGEND> " + s)
            self.write(-2, "<LOGEND> " + system.currtime() + " TASK FINISHED")
        if s:
            self.LOGENDMESSAGE = s
        if self.STATUS is None:
            self.STATUS = 5
        if not self.nofile:
            if self._dbh is None:
                self._dbh = _log_db_init()
            if not self.dbkey:
                self.dbkey = self._log_db_query_id()
            self._log_db_logend()
        self._logend_called = True
        self.close()

    # ------------------------------------------------------------------
    # DB helpers
    def _log_db_query_id(self):
        if not self.filename or self._dbh is None:
            return None
        row = self._dbh.execute(
            "SELECT LOGKEY FROM logs WHERE FILENAME LIKE ? ORDER BY LOGSTART DESC LIMIT 1;",
            (self.filename,)).fetchone()
        return row[0] if row else None

    def _log_db_logstart(self):
        if self._dbh is None or not self.package or not self.name or not self.filename:
            return None
        now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        cur = self._dbh.execute(
            "INSERT INTO logs (PACKAGE, NAME, FILENAME, LOGSTART, LASTMODIFIED) VALUES (?, ?, ?, ?, ?);",
            (self.package, self.name, self.filename, now, now))
        key = cur.lastrowid
        self._store_attrs(key)
        self._dbh.commit()
        return key

    def _log_db_logend(self):
        if self._dbh is None or not self.dbkey:
            return None
        now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        self._dbh.execute("UPDATE logs SET LOGEND = ?, LASTMODIFIED = ? WHERE LOGKEY = ?;",
                          (now, now, self.dbkey))
        self._store_attrs(self.dbkey)
        self._dbh.commit()
        return "Success"

    def _store_attrs(self, key):
        attrs = {
            "STATUS": self.STATUS,
            "PLUGINTITLE": self.PLUGINTITLE,
            "LOGSTARTMESSAGE": self.LOGSTARTMESSAGE,
            "LOGENDMESSAGE": self.LOGENDMESSAGE,
            "LOGSTARTBYTE": self.LOGSTARTBYTE,
            "ATTENTIONMESSAGES": self.ATTENTIONMESSAGES,
            "loglevel": self.loglevel,
            "_ISPLUGIN": self._isplugin if self._isplugin else None,
        }
        for attrib, value in attrs.items():
            if value is None or value == "":
                continue
            self._dbh.execute(
                "INSERT OR REPLACE INTO logs_attr (keyref, attrib, value) VALUES (?, ?, ?);",
                (key, attrib, str(value)))

    def _recreate_session(self):
        """Re-insert the session row if it disappeared (tmpfs was cleared)."""
        if self._dbh is None or not self.dbkey:
            return
        row = self._dbh.execute("SELECT LOGKEY FROM logs WHERE LOGKEY = ?;",
                                (self.dbkey,)).fetchone()
        if row:
            return
        now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        try:
            self._dbh.execute(
                "INSERT INTO logs (PACKAGE, NAME, FILENAME, LOGSTART, LASTMODIFIED, LOGKEY) "
                "VALUES (?, ?, ?, ?, ?, ?);",
                (self.package, self.name, self.filename, now, now, self.dbkey))
            self._store_attrs(self.dbkey)
            self._dbh.commit()
        except sqlite3.Error:
            pass


def _numify(value):
    if value is None:
        return 0
    if isinstance(value, bool):
        return 1 if value else 0
    if isinstance(value, (int, float)):
        return value
    import re
    m = re.match(r"\s*(-?\d+(?:\.\d+)?)", str(value))
    if not m:
        return 0
    num = m.group(1)
    return float(num) if "." in num else int(num)


# ---------------------------------------------------------------------------
# Notifications
# ---------------------------------------------------------------------------
def _notify_db_init():
    dbfile = _notifydbfile()
    try:
        dbh = sqlite3.connect(dbfile, timeout=5.0)
    except sqlite3.Error:
        return None
    dbh.execute("""CREATE TABLE IF NOT EXISTS notifications (
        PACKAGE VARCHAR(255) NOT NULL,
        NAME VARCHAR(255) NOT NULL,
        MESSAGE TEXT,
        SEVERITY INT,
        timestamp DATETIME DEFAULT (datetime('now','localtime')) NOT NULL,
        notifykey INTEGER PRIMARY KEY
    )""")
    dbh.execute("""CREATE TABLE IF NOT EXISTS notifications_attr (
        keyref INTEGER NOT NULL,
        attrib VARCHAR(255) NOT NULL,
        value VARCHAR(255),
        PRIMARY KEY ( keyref, attrib )
    )""")
    dbh.commit()
    return dbh


def _strip_html(message):
    import re
    message = message.replace("<br>", "\\n").replace("<p>", "\\n")
    return re.sub(r"<.+?>", "", message)


def notify(package, name, message, error=False):
    """Insert a notification. error=True -> severity 3 (error), else 6 (info)."""
    severity = 3 if error else 6
    dbh = _notify_db_init()
    if dbh is None:
        return None
    data = {"PACKAGE": package, "NAME": name, "MESSAGE": message, "SEVERITY": severity}
    if system.lbpplugindir:
        data["_ISPLUGIN"] = 1
    else:
        data["_ISSYSTEM"] = 1
    _notify_insert(dbh, data)
    dbh.close()
    _chown_loxberry(_notifydbfile())
    # notify_send_mail is not ported yet.


def notify_ext(data):
    """Insert a notification from a data dict (keys PACKAGE, NAME, MESSAGE, SEVERITY, ...)."""
    dbh = _notify_db_init()
    if dbh is None:
        return None
    data = dict(data)
    if not data.get("_ISPLUGIN") and not data.get("_ISSYSTEM"):
        plugin = system.plugindata(data.get("PACKAGE"))
        if system.lbpplugindir or plugin:
            data["_ISPLUGIN"] = 1
        else:
            data["_ISSYSTEM"] = 1
    _notify_insert(dbh, data)
    dbh.close()
    _chown_loxberry(_notifydbfile())


def _notify_insert(dbh, p):
    for field in ("PACKAGE", "NAME", "MESSAGE", "SEVERITY"):
        if not p.get(field):
            raise ValueError("Create notification: No %s defined" % field)
    message = _strip_html(str(p["MESSAGE"]))
    cur = dbh.execute(
        "INSERT INTO notifications (PACKAGE, NAME, MESSAGE, SEVERITY) VALUES (?, ?, ?, ?);",
        (p["PACKAGE"], p["NAME"], message, p["SEVERITY"]))
    key = cur.lastrowid
    for attrib, value in p.items():
        if attrib in ("PACKAGE", "NAME", "MESSAGE", "SEVERITY"):
            continue
        dbh.execute(
            "INSERT INTO notifications_attr (keyref, attrib, value) VALUES (?, ?, ?);",
            (key, attrib, str(value)))
    dbh.commit()
    return "Success"


def get_notification_count(package=None, name=None, latest=None):
    """Return (error_count, ok_count, total) of notifications."""
    dbh = _notify_db_init()
    if dbh is None:
        return None
    where = ""
    params = []
    if package:
        where += "PACKAGE = ? AND "
        params.append(package)
    if name:
        where += "NAME = ? AND "
        params.append(name)
    q = "SELECT count(*) FROM notifications WHERE " + where
    err = dbh.execute(q + "SEVERITY = 3;", params).fetchone()[0]
    ok = dbh.execute(q + "SEVERITY = 6;", params).fetchone()[0]
    dbh.close()
    return err, ok, err + ok


def get_notifications(package=None, name=None, latest=None, count=None):
    """Return a list of notification dicts (newest first)."""
    dbh = _notify_db_init()
    if dbh is None:
        return None
    where = ""
    params = []
    if package:
        where += "PACKAGE = ? AND "
        params.append(package)
    if name:
        where += "NAME = ? AND "
        params.append(name)
    if where:
        where = "WHERE " + where[:-5] + " "
    q = ("SELECT PACKAGE, NAME, MESSAGE, SEVERITY, timestamp, notifykey "
         "FROM notifications %sORDER BY timestamp DESC" % where)
    if latest:
        q += " LIMIT 1"
    rows = dbh.execute(q, params).fetchall()
    cols = ("PACKAGE", "NAME", "MESSAGE", "SEVERITY", "DATETIME", "KEYREF")
    result = []
    for row in rows:
        entry = dict(zip(cols, row))
        for aref, attrib, value in dbh.execute(
                "SELECT keyref, attrib, value FROM notifications_attr WHERE keyref = ?;",
                (entry["KEYREF"],)).fetchall():
            entry[attrib] = value
        result.append(entry)
    dbh.close()
    return result


def delete_notifications(package=None, name=None):
    """Delete notifications matching package (and optionally name)."""
    dbh = _notify_db_init()
    if dbh is None:
        return None
    where = ""
    params = []
    if package:
        where += "PACKAGE = ? AND "
        params.append(package)
    if name:
        where += "NAME = ? AND "
        params.append(name)
    if not where:
        dbh.close()
        return None
    where = where[:-5]
    keys = [r[0] for r in dbh.execute(
        "SELECT notifykey FROM notifications WHERE " + where, params).fetchall()]
    dbh.execute("DELETE FROM notifications WHERE " + where, params)
    for k in keys:
        dbh.execute("DELETE FROM notifications_attr WHERE keyref = ?;", (k,))
    dbh.commit()
    dbh.close()
    return len(keys)


# ---------------------------------------------------------------------------
# get_logs
# ---------------------------------------------------------------------------
def get_logs(package=None, name=None, nofilter=False):
    """Return a list of log-session dicts from the log database."""
    dbh = _log_db_init()
    if dbh is None:
        return None
    q = "SELECT PACKAGE, NAME, FILENAME, LOGSTART, LOGEND, LASTMODIFIED, LOGKEY FROM logs "
    params = []
    if package and name:
        q += "WHERE PACKAGE = ? AND NAME = ? "
        params = [package, name]
    elif package:
        q += "WHERE PACKAGE = ? "
        params = [package]
    q += "ORDER BY PACKAGE, NAME, LASTMODIFIED DESC"

    logs = []
    for row in dbh.execute(q, params).fetchall():
        pkg, nm, filename, logstart, logend, lastmod, logkey = row
        if not nofilter and logstart and not os.path.exists(filename):
            continue
        entry = {"PACKAGE": pkg, "NAME": nm, "FILENAME": filename, "KEY": logkey}

        def _fmt(v):
            try:
                return datetime.strptime(v, "%Y-%m-%d %H:%M:%S")
            except (ValueError, TypeError):
                return None
        so = _fmt(logstart)
        eo = _fmt(logend)
        mo = _fmt(lastmod)
        if so:
            entry["LOGSTARTISO"] = so.strftime("%Y-%m-%dT%H:%M:%S")
            entry["LOGSTARTSTR"] = so.strftime("%d.%m.%Y %H:%M")
        if eo:
            entry["LOGENDISO"] = eo.strftime("%Y-%m-%dT%H:%M:%S")
            entry["LOGENDSTR"] = eo.strftime("%d.%m.%Y %H:%M")
        if mo:
            entry["LASTMODIFIEDISO"] = mo.strftime("%Y-%m-%dT%H:%M:%S")
            entry["LASTMODIFIEDSTR"] = mo.strftime("%d.%m.%Y %H:%M")

        for _kr, attrib, value in dbh.execute(
                "SELECT keyref, attrib, value FROM logs_attr WHERE keyref = ?;",
                (logkey,)).fetchall():
            entry[attrib] = value
        logs.append(entry)
    dbh.close()
    return logs


# Convenience factory (mirrors PHP LBLog::newLog)
def newLog(**params):
    return LBLog(**params)
