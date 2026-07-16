# -*- coding: utf-8 -*-
"""
loxberry.system.core - Python port of the Perl master library LoxBerry::System.

This is the "Fundament" scope: path variables, plugin-context detection,
general.json, Miniserver info, language, host/version helpers, time
conversions and version comparison. It mirrors the Perl API 1:1 (same
function names, same dict keys) so a plugin author moving between Perl, PHP
and Python does not have to relearn anything, and so the existing libcompare
parity test also covers Python.

Master reference: libs/perllib/LoxBerry/System.pm (V4.0.0.14)

Supported Python versions: 3.9 (Bullseye), 3.11 (Bookworm), 3.13 (Trixie).
Only the standard library plus `requests` (already installed on LoxBerry) is
used.
"""

from __future__ import annotations

import json
import os
import re
import socket
import sys
import time
from datetime import datetime

__version__ = "4.0.0.14"

DEBUG = bool(os.environ.get("LOXBERRY_SYSTEM_DEBUG"))


def _dbg(msg: str) -> None:
    if DEBUG:
        sys.stderr.write(msg + "\n")


# ---------------------------------------------------------------------------
# LoxBerry home directory  (System.pm lines 76-97)
# ---------------------------------------------------------------------------
def _detect_lbhomedir() -> str:
    env = os.environ.get("LBHOMEDIR")
    if env:
        _dbg("lbhomedir %s detected by environment" % env)
        return env

    username = os.environ.get("LOGNAME") or os.environ.get("USER")
    if not username:
        try:
            import pwd  # POSIX only

            username = pwd.getpwuid(os.getuid()).pw_name
        except Exception:
            username = None

    if username == "loxberry":
        home = os.path.expanduser("~")
        if home and home != "~":
            _dbg("lbhomedir %s detected by loxberry HomeDir" % home)
            return home
    elif username == "root":
        try:
            import pwd

            home = pwd.getpwnam("loxberry").pw_dir
            if home:
                _dbg("lbhomedir %s detected as root via loxberry's home" % home)
                return home
        except Exception:
            pass

    _dbg("lbhomedir set to /opt/loxberry as fallback")
    return "/opt/loxberry"


lbhomedir = _detect_lbhomedir()


# ---------------------------------------------------------------------------
# Plugin context detection from the running script path
# (System.pm lines 99-148)
# ---------------------------------------------------------------------------
def _detect_plugindir(home: str) -> "str | None":
    scriptpath = os.environ.get("SCRIPT_FILENAME") or (sys.argv[0] if sys.argv else "")
    if not scriptpath:
        return None
    try:
        abspath = os.path.abspath(scriptpath)
    except Exception:
        return None

    # Work in posix-style separators so the split logic matches Perl.
    abspath = abspath.replace("\\", "/")
    home = home.replace("\\", "/")

    if not abspath.startswith(home + "/"):
        return None

    # Strip a file extension (rindex on '.'), like Perl does.
    rindex = abspath.rfind(".")
    if rindex < 0:
        rindex = len(abspath)

    part = abspath[len(home) + 1 : rindex]
    _dbg("plugin-context part is %s" % part)

    parts = part.split("/")
    parts += [None] * (6 - len(parts))  # pad to 6, like ($p1..$p6)
    p1, p2, p3, p4 = parts[0], parts[1], parts[2], parts[3]

    if p1 == "webfrontend" and p3 == "plugins" and p4:
        return p4
    if p1 == "templates" and p2 == "plugins" and p3:
        return p3
    if p1 == "log" and p2 == "plugins" and p3:
        return p3
    if p1 == "data" and p2 == "plugins" and p3:
        return p3
    if p1 == "config" and p2 == "plugins" and p3:
        return p3
    if p1 == "bin" and p2 == "plugins" and p3:
        return p3
    if p1 == "system" and p2 == "daemons" and p3 == "plugins" and p4:
        return p4
    return None


lbpplugindir = _detect_plugindir(lbhomedir)

# Plugin directories (None when no plugin context, like Perl's undef)
if lbpplugindir:
    lbphtmlauthdir = "%s/webfrontend/htmlauth/plugins/%s" % (lbhomedir, lbpplugindir)
    lbphtmldir = "%s/webfrontend/html/plugins/%s" % (lbhomedir, lbpplugindir)
    lbcgidir = lbphtmlauthdir
    lbptemplatedir = "%s/templates/plugins/%s" % (lbhomedir, lbpplugindir)
    lbpdatadir = "%s/data/plugins/%s" % (lbhomedir, lbpplugindir)
    lbplogdir = "%s/log/plugins/%s" % (lbhomedir, lbpplugindir)
    lbpconfigdir = "%s/config/plugins/%s" % (lbhomedir, lbpplugindir)
    lbpbindir = "%s/bin/plugins/%s" % (lbhomedir, lbpplugindir)
else:
    lbphtmlauthdir = None
    lbphtmldir = None
    lbcgidir = None
    lbptemplatedir = None
    lbpdatadir = None
    lbplogdir = None
    lbpconfigdir = None
    lbpbindir = None

# System directories (always defined)
lbshtmldir = "%s/webfrontend/html/system" % lbhomedir
lbshtmlauthdir = "%s/webfrontend/htmlauth/system" % lbhomedir
lbstemplatedir = "%s/templates/system" % lbhomedir
lbsdatadir = "%s/data/system" % lbhomedir
lbslogdir = "%s/log/system" % lbhomedir
lbstmpfslogdir = "%s/log/system_tmpfs" % lbhomedir
lbsconfigdir = "%s/config/system" % lbhomedir
lbssbindir = "%s/sbin" % lbhomedir
lbsbindir = "%s/bin" % lbhomedir

reboot_required_file = "%s/reboot.required" % lbstmpfslogdir
reboot_force_popup_file = "%s/reboot.force" % lbstmpfslogdir
PLUGINDATABASE = "%s/plugindatabase.json" % lbsdatadir


# ---------------------------------------------------------------------------
# Module-internal caches (mirror the Perl "my" state variables)
# ---------------------------------------------------------------------------
_state = {
    "cfgwasread": False,
    "lang": None,
    "country": None,
    "clouddnsaddress": None,
    "sysloglevel": None,
    "lbversion": None,
    "lbfriendlyname": None,
    "lbtimezone": None,
    "webserverport": None,
    "mqttcfg": None,
    "lbtheme": None,
    "miniservers": None,          # dict or None
    "msClouddnsFetched": False,
}

_THEME_MAP = {"classic": "classic-lb", "modern": "soft-rounded", "dark": "glass"}
_VALID_THEMES = ("soft-rounded", "clean-admin", "glass", "classic-lb")


# ---------------------------------------------------------------------------
# File helpers  (System.pm lines 1682-1706)
# ---------------------------------------------------------------------------
def read_file(filename: str) -> "str | None":
    """Read a whole file and return its content, or None on error."""
    try:
        with open(filename, "r", encoding="utf-8", errors="replace") as fh:
            return fh.read()
    except OSError:
        return None


def write_file(filename: str, content: str) -> str:
    """Write content to filename. Returns '' on success or the error string."""
    try:
        with open(filename, "w", encoding="utf-8") as fh:
            fh.write(content if content is not None else "")
        return ""
    except OSError as exc:
        return str(exc)


# ---------------------------------------------------------------------------
# read_generaljson  (System.pm lines 540-605)
# ---------------------------------------------------------------------------
def read_generaljson() -> "int | None":
    """Read config/system/general.json and populate the module state."""
    if _state["cfgwasread"]:
        return 1

    raw = read_file("%s/general.json" % lbsconfigdir)
    cfg = None
    if raw is not None:
        try:
            cfg = json.loads(raw)
        except ValueError:
            cfg = None
    if not cfg:
        raise RuntimeError("Could not read general.json")

    _state["cfgwasread"] = True
    base = cfg.get("Base", {}) or {}
    _state["lang"] = base.get("Lang")
    country = base.get("Country")
    _state["country"] = None if (country is None or country == "undef") else country
    _state["clouddnsaddress"] = base.get("Clouddnsuri")
    _state["sysloglevel"] = base.get("Systemloglevel")
    _state["lbversion"] = base.get("Version")

    network = cfg.get("Network", {}) or {}
    _state["lbfriendlyname"] = network.get("Friendlyname")

    timeserver = cfg.get("Timeserver", {}) or {}
    _state["lbtimezone"] = timeserver.get("Timezone")

    webserver = cfg.get("Webserver", {}) or {}
    _state["webserverport"] = webserver.get("Port")

    _state["mqttcfg"] = cfg.get("Mqtt")

    theme = base.get("Theme") or "soft-rounded"
    theme = _THEME_MAP.get(theme, theme)
    if theme not in _VALID_THEMES:
        theme = "soft-rounded"
    _state["lbtheme"] = theme

    miniserver = cfg.get("Miniserver")
    if not miniserver or len(miniserver) < 1:
        return None

    miniservers = {}
    for msnr, ms in miniserver.items():
        ms = ms or {}
        miniservers[msnr] = {
            "Name": ms.get("Name"),
            "IPAddress": ms.get("Ipaddress"),
            "Admin": ms.get("Admin"),
            "Pass": ms.get("Pass"),
            "Credentials": ms.get("Credentials"),
            "Note": ms.get("Note"),
            "Port": ms.get("Port"),
            "PortHttps": ms.get("Porthttps"),
            "PreferHttps": ms.get("Preferhttps"),
            "UseCloudDNS": ms.get("Useclouddns"),
            "CloudURLFTPPort": ms.get("Cloudurlftpport"),
            "CloudURL": ms.get("Cloudurl"),
            "Admin_RAW": ms.get("Admin_raw"),
            "Pass_RAW": ms.get("Pass_raw"),
            "Credentials_RAW": ms.get("Credentials_raw"),
            "SecureGateway": ms.get("Securegateway"),
            "EncryptResponse": ms.get("Encryptresponse"),
            "Location": ms.get("Location", "") if ms.get("Location") is not None else "",
            "Latitude": ms.get("Latitude", "") if ms.get("Latitude") is not None else "",
            "Longitude": ms.get("Longitude", "") if ms.get("Longitude") is not None else "",
        }
    _state["miniservers"] = miniservers
    return 1


# ---------------------------------------------------------------------------
# get_miniservers  (System.pm lines 196-253)
# NOTE: CloudDNS resolution (set_clouddns) is deferred to the 2nd port step;
# for UseCloudDNS entries the configured IP is used as-is, but all derived
# fields (Transport, FullURI, IPv6Format, default ports) are still computed.
# ---------------------------------------------------------------------------
def get_miniservers() -> dict:
    if _state["msClouddnsFetched"]:
        return _state["miniservers"] or {}

    if not _state["miniservers"]:
        read_generaljson()

    miniservers = _state["miniservers"] or {}

    for msnr in list(miniservers.keys()):
        ms = miniservers[msnr]

        # CloudDNS handling is deferred (set_clouddns, step 2). IP stays as-is.

        if not ms.get("Port"):
            ms["Port"] = 80
        if not ms.get("PortHttps"):
            ms["PortHttps"] = 443

        if is_enabled(ms.get("PreferHttps")):
            transport = "https"
        else:
            transport = "http"

        ipaddress = ms.get("IPAddress") or ""
        ipv6 = "1" if ":" in ipaddress else "0"
        ms["IPv6Format"] = ipv6
        ipbracket = "[" + ipaddress + "]" if ipv6 == "1" else ipaddress
        port = ms["PortHttps"] if is_enabled(ms.get("PreferHttps")) else ms["Port"]

        ms["Transport"] = transport
        cred = ms.get("Credentials") or ""
        cred_raw = ms.get("Credentials_RAW") or ""
        ms["FullURI"] = "%s://%s@%s:%s" % (transport, cred, ipbracket, port)
        ms["FullURI_RAW"] = "%s://%s@%s:%s" % (transport, cred_raw, ipbracket, port)

        # Consistency check: drop implausible entries entirely (like Perl).
        if (not ms.get("Name") or not ms.get("IPAddress")
                or not ms.get("Admin") or not ms.get("Pass")):
            del miniservers[msnr]

    _state["msClouddnsFetched"] = True
    return miniservers


def get_miniserver_by_ip(ip: str) -> "str | None":
    ip = trim(str(ip)).lower()
    if not _state["msClouddnsFetched"]:
        get_miniservers()
    for msnr, ms in (_state["miniservers"] or {}).items():
        if str(ms.get("IPAddress") or "").lower() == ip:
            return msnr
    return None


def get_miniserver_by_name(myname: str) -> "str | None":
    myname = trim(str(myname)).lower()
    if not _state["msClouddnsFetched"]:
        get_miniservers()
    for msnr, ms in (_state["miniservers"] or {}).items():
        if str(ms.get("Name") or "").lower() == myname:
            return msnr
    return None


# ---------------------------------------------------------------------------
# get_ftpport  (System.pm lines 710-739)
# The live-query path uses requests instead of LoxBerry::IO (ported later).
# ---------------------------------------------------------------------------
def get_ftpport(msnr=1) -> "str | int | None":
    if msnr is None:
        msnr = 1
    if not _state["msClouddnsFetched"]:
        get_miniservers()
    miniservers = _state["miniservers"] or {}
    # Miniserver keys are strings ("1", "2"); accept int input transparently.
    ms = miniservers.get(msnr) or miniservers.get(str(msnr))
    if ms is None:
        return None

    if is_enabled(ms.get("UseCloudDNS")) and ms.get("CloudURLFTPPort"):
        return ms["CloudURLFTPPort"]

    if not ms.get("FTPPort"):
        value = _query_miniserver_ftpport(ms)
        if value is None:
            return None
        ms["FTPPort"] = value
    return ms["FTPPort"]


def _query_miniserver_ftpport(ms: dict) -> "str | None":
    """Ask the Miniserver for its FTP port via /dev/cfg/ftp."""
    try:
        import requests
    except Exception:
        return None
    uri = ms.get("FullURI_RAW") or ms.get("FullURI")
    if not uri:
        return None
    url = uri.rstrip("/") + "/dev/cfg/ftp"
    try:
        resp = requests.get(url, timeout=5)
        if resp.status_code < 200 or resp.status_code >= 300:
            return None
        m = re.search(r'value="([^"]*)"', resp.text)
        if m:
            return m.group(1)
    except Exception:
        return None
    return None


# ---------------------------------------------------------------------------
# get_localip  (System.pm lines 744-755)
# ---------------------------------------------------------------------------
def get_localip() -> "str | None":
    sock = None
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        sock.connect(("8.8.8.8", 53))
        return sock.getsockname()[0]
    except OSError:
        return None
    finally:
        if sock is not None:
            sock.close()


# ---------------------------------------------------------------------------
# Language  (System.pm lines 760-940)
# ---------------------------------------------------------------------------
def lblanguage() -> "str | None":
    if _state["lang"]:
        return _state["lang"]

    # Query-string 'lang' parameter (CGI context)
    qs = os.environ.get("QUERY_STRING", "")
    if qs:
        for pair in qs.split("&"):
            if pair.startswith("lang="):
                querylang = pair[5:]
                if querylang:
                    _state["lang"] = querylang[:2]
                    return _state["lang"]

    read_generaljson()
    return _state["lang"]


def lbcountry() -> "str | None":
    if _state["cfgwasread"]:
        return _state["country"]
    read_generaljson()
    return _state["country"]


def _parse_lang_file(content: str, langhash: dict) -> None:
    """Parse a LoxBerry INI-style language file into 'Section.Key' entries.

    Mirrors System.pm::_parse_lang_file exactly, including: keep the FIRST
    value seen for a key (foreign is read before English so it wins), strip
    surrounding double quotes, and skip #, /, ; and empty lines.
    """
    section = "default"
    for line in content.split("\n"):
        line = line.strip()
        first = line[:1]
        if first in ("", "#", "/", ";"):
            continue
        if first == "[":
            close = line.find("]", 1)
            if close == -1:
                continue
            section = line[1:close]
            continue
        if "=" not in line:
            continue
        param, value = line.split("=", 1)
        param = param.strip()
        key = "%s.%s" % (section, param)
        if langhash.get(key):
            continue
        value = value.strip()
        if len(value) >= 2 and value[0] == '"' and value[-1] == '"':
            value = value[1:-1]
        langhash[key] = value


def readlanguage(langfile: str = "language.ini", syslang: bool = False) -> dict:
    """Read plugin (or system) language phrases as a 'Section.Key' -> value dict.

    Unlike the Perl version there is no HTML::Template parameter (that is
    Perl/Web-specific). Foreign language is read first, English fills the gaps.
    """
    lang = lblanguage() or "en"
    issystem = bool(syslang) or not lbpplugindir

    result: dict = {}

    if issystem:
        base = "%s/lang/language" % lbstemplatedir
        langfile_en = base + "_en.ini"
        langfile_foreign = base + "_" + lang + ".ini"
        if lang != "en" and os.path.exists(langfile_foreign):
            cont = read_file(langfile_foreign)
            if cont is not None:
                _parse_lang_file(cont, result)
        cont_en = read_file(langfile_en)
        if cont_en is not None:
            _parse_lang_file(cont_en, result)
        return result

    # Plugin language: strip extension from the given langfile name
    name = re.sub(r"\.[^.]*$", "", langfile)
    base = "%s/lang/%s" % (lbptemplatedir, name)
    langfile_en = base + "_en.ini"
    langfile_foreign = base + "_" + lang + ".ini"
    if lang != "en" and os.path.exists(langfile_foreign):
        cont = read_file(langfile_foreign)
        if cont is not None:
            _parse_lang_file(cont, result)
    if os.path.exists(langfile_en):
        cont_en = read_file(langfile_en)
        if cont_en is not None:
            _parse_lang_file(cont_en, result)
    return result


# ---------------------------------------------------------------------------
# Host / version / config accessors
# ---------------------------------------------------------------------------
def lbhostname() -> str:
    return socket.gethostname()


def lbfriendlyname() -> "str | None":
    if not _state["cfgwasread"]:
        read_generaljson()
    return _state["lbfriendlyname"]


def lbwebserverport() -> int:
    if not _state["cfgwasread"]:
        read_generaljson()
    if not _state["webserverport"]:
        _state["webserverport"] = 80
    return _state["webserverport"]


def lbversion() -> "str | None":
    if _state["lbversion"]:
        return _state["lbversion"]
    read_generaljson()
    return _state["lbversion"]


def systemloglevel() -> int:
    if _state["sysloglevel"]:
        return _state["sysloglevel"]
    read_generaljson()
    if _state["sysloglevel"]:
        return _state["sysloglevel"]
    return 6


# ---------------------------------------------------------------------------
# Boolean / string helpers  (System.pm lines 982-1036)
# ---------------------------------------------------------------------------
_ENABLED = {"true", "yes", "on", "enabled", "enable", "1", "check",
            "checked", "select", "selected"}
_DISABLED = {"false", "no", "off", "disabled", "disable", "0"}


def is_enabled(text) -> bool:
    """True if text represents an 'on/true/enabled' value."""
    if not text:
        return False
    return str(text).strip().lower() in _ENABLED


def is_disabled(text) -> bool:
    """True if text is empty or represents an 'off/false/disabled' value."""
    if not text:
        return True
    return str(text).strip().lower() in _DISABLED


def begins_with(string, prefix) -> bool:
    string = "" if string is None else str(string)
    prefix = "" if prefix is None else str(prefix)
    return string[:len(prefix)] == prefix


def trim(s) -> str:
    if s is None:
        return ""
    return re.sub(r"^\s+|\s+$", "", str(s))


def ltrim(s) -> str:
    if s is None:
        return ""
    return re.sub(r"^\s+", "", str(s))


def rtrim(s) -> str:
    if s is None:
        return ""
    return re.sub(r"\s+$", "", str(s))


# ---------------------------------------------------------------------------
# Time  (System.pm lines 1045-1130)
# ---------------------------------------------------------------------------
def currtime(fmt: str = "hr") -> "str | None":
    now = datetime.now()
    sec, minute, hour = now.second, now.minute, now.hour
    mday, mon, year = now.day, now.month, now.year
    ms = int(now.microsecond / 1000)

    if not fmt or fmt == "hr":
        return "%02d.%02d.%04d %02d:%02d:%02d" % (mday, mon, year, hour, minute, sec)
    if fmt == "hrtime":
        return "%02d:%02d:%02d" % (hour, minute, sec)
    if fmt == "hrtimehires":
        return "%02d:%02d:%02d.%03d" % (hour, minute, sec, ms)
    if fmt == "file":
        return "%04d%02d%02d_%02d%02d%02d" % (year, mon, mday, hour, minute, sec)
    if fmt == "filehires":
        return "%04d%02d%02d_%02d%02d%02d_%03d" % (
            year, mon, mday, hour, minute, sec, ms)
    if fmt == "iso":
        # Note: not real ISO (local time labelled with Z), matching Perl.
        return "%04d-%02d-%02dT%02d:%02d:%02dZ" % (
            year, mon, mday, hour, minute, sec)
    return None


def tz_offset() -> int:
    """Current local timezone offset from UTC in seconds (incl. DST)."""
    off = datetime.now().astimezone().utcoffset()
    return int(off.total_seconds()) if off is not None else 0


_LOX_OFFSET = 1230764400  # 1.1.2009 00:00:00


def epoch2lox(epoche=None) -> int:
    if not epoche:
        epoche = int(time.time())
    return int(epoche) - _LOX_OFFSET + tz_offset() - 3600


def lox2epoch(loxepoche=None) -> int:
    if not loxepoche:
        return int(time.time())
    return int(loxepoche) + _LOX_OFFSET - tz_offset() + 3600


# ---------------------------------------------------------------------------
# reboot_required  (System.pm lines 1226-1242)
# ---------------------------------------------------------------------------
def reboot_required(message: str = None) -> None:
    try:
        with open(reboot_required_file, "a", encoding="utf-8") as fh:
            if not message:
                fh.write("A reboot was requested by %s\n" % (sys.argv[0] if sys.argv else "python"))
            else:
                fh.write("%s\n" % message)
    except OSError:
        return
    try:
        import pwd

        pw = pwd.getpwnam("loxberry")
        os.chown(reboot_required_file, pw.pw_uid, pw.pw_gid)
    except Exception:
        pass


# ---------------------------------------------------------------------------
# bytes_humanreadable  (System.pm lines 1647-1680)
# ---------------------------------------------------------------------------
def bytes_humanreadable(size, inputfactor: str = "") -> str:
    inputfactor = (inputfactor or "").upper()
    size = float(size)
    if inputfactor == "K":
        size *= 1024
    elif inputfactor == "M":
        size *= 1024 ** 2
    elif inputfactor == "G":
        size *= 1024 ** 3
    elif inputfactor == "T":
        size *= 1024 ** 4

    if size > 1024 ** 4:
        outputfactor = "T"
        size /= 1024 ** 4
    elif size > 1024 ** 3:
        outputfactor = "G"
        size /= 1024 ** 3
    elif size > 1024 ** 2:
        outputfactor = "M"
        size /= 1024 ** 2
    elif size > 1024:
        outputfactor = "K"
        size /= 1024
    else:
        outputfactor = ""

    return "%.1f%sB" % (size, outputfactor)


# ---------------------------------------------------------------------------
# Version handling  (System.pm lines 1526-1645)
# ---------------------------------------------------------------------------
def vers_tag(vers, reverse: bool = False) -> str:
    vers = trim(str(vers)).lower()
    if vers[:1] != "v" and not reverse:
        vers = "v" + vers
    if vers[:1] == "v" and reverse:
        vers = vers[1:]
    return vers


_SEMVER_RE = re.compile(r"^(\d+)\.(\d+)\.(\d+)(?:-([0-9A-Za-z.-]+))?$")
_LAX_RE = re.compile(r"^v?\d+(?:\.\d+)*$")


def _plugin_semver_parts(tag):
    """Return (major, minor, patch, prerelease, ok) for a classic 3-part SemVer."""
    if tag is None or tag == "":
        return (None, None, None, None, False)
    s = tag[1:] if tag[:1] == "v" else tag
    s = re.sub(r"\+.*\Z", "", s)
    m = _SEMVER_RE.match(s)
    if m:
        pre = m.group(4) if m.group(4) is not None else ""
        return (int(m.group(1)), int(m.group(2)), int(m.group(3)), pre, True)
    return (None, None, None, None, False)


def _cmp(a, b) -> int:
    return (a > b) - (a < b)


def _plugin_semver_prerelease_cmp(a: str, b: str) -> int:
    pa = a.split(".")
    pb = b.split(".")
    i = 0
    while True:
        ida = pa[i] if i < len(pa) else None
        idb = pb[i] if i < len(pb) else None
        if ida is None and idb is None:
            return 0
        if ida is None:
            return -1
        if idb is None:
            return 1
        na = bool(re.match(r"^\d+$", ida))
        nb = bool(re.match(r"^\d+$", idb))
        if na and nb:
            wc = _cmp(int(ida), int(idb))
            if wc != 0:
                return wc
        elif na and not nb:
            return -1
        elif not na and nb:
            return 1
        else:
            ws = _cmp(ida, idb)
            if ws != 0:
                return ws
        i += 1


def _lax_parts(tag):
    """Numeric tuple for a lax dotted-numeric version (LoxBerry 4-part etc.)."""
    s = tag[1:] if tag[:1] == "v" else tag
    return tuple(int(x) for x in s.split("."))


def plugin_version_compare(a_in=None, b_in=None):
    """Compare two plugin versions. Returns -1/0/1, or None if not comparable."""
    if a_in is None and b_in is None:
        return 0
    if a_in is None or b_in is None:
        return None
    tag_a = vers_tag(trim(str(a_in)).lower())
    tag_b = vers_tag(trim(str(b_in)).lower())

    maj_a, min_a, pat_a, pre_a, ok_a = _plugin_semver_parts(tag_a)
    maj_b, min_b, pat_b, pre_b, ok_b = _plugin_semver_parts(tag_b)

    if ok_a and ok_b:
        c = _cmp(maj_a, maj_b)
        if c != 0:
            return c
        c = _cmp(min_a, min_b)
        if c != 0:
            return c
        c = _cmp(pat_a, pat_b)
        if c != 0:
            return c
        pempty_a = (pre_a == "")
        pempty_b = (pre_b == "")
        if not pempty_a and pempty_b:
            return -1
        if pempty_a and not pempty_b:
            return 1
        if pempty_a and pempty_b:
            return 0
        return _plugin_semver_prerelease_cmp(pre_a, pre_b)

    # Lax fallback (dotted numeric; the common LoxBerry 4-part case).
    if not _LAX_RE.match(tag_a) or not _LAX_RE.match(tag_b):
        return None
    pa = _lax_parts(tag_a)
    pb = _lax_parts(tag_b)
    length = max(len(pa), len(pb))
    pa = pa + (0,) * (length - len(pa))
    pb = pb + (0,) * (length - len(pb))
    return _cmp(pa, pb)


def plugin_version_has_prerelease(v_in=None) -> int:
    if v_in is None or v_in == "":
        return 0
    tag = vers_tag(trim(str(v_in)).lower())
    _, _, _, pre, ok = _plugin_semver_parts(tag)
    return 1 if (ok and pre != "") else 0
