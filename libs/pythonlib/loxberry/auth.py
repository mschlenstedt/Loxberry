# -*- coding: utf-8 -*-
"""
loxberry.auth - Python port of LoxBerry::Auth.

Token authentication at the Loxone Miniserver. Mirrors the Perl master
(libs/perllib/LoxBerry/Auth.pm) 1:1 - same function names, same dict keys.

Standard library only: hashlib, hmac, urllib, json, fcntl, base64.
"""

from __future__ import annotations

import hashlib
import hmac
import json as _json
import os
import re
import ssl
import sys
import urllib.error
import urllib.parse
import urllib.request

try:
    import fcntl  # POSIX only - Windows dev machines run without the lock
    _HAVE_FCNTL = True
except ImportError:
    _HAVE_FCNTL = False

from . import system as _lb

DEBUG = 0

# Permission bits of the Miniserver token API
PERM_ADMIN = 0x01
PERM_WEB = 0x02
PERM_APP = 0x04
PERM_SYSWS = 0x100

# App + Sys-WS: ~3 months lifetime, includes the right to reboot
DEFAULT_PERM = 0x104
# Renew as soon as less than this many seconds are left
REFRESH_THRESHOLD = 7 * 86400
TIMEOUT = 10
# Below this firmware the token endpoints need application layer encryption
MIN_FIRMWARE = "11.2.10.22"

# Test hooks - the unit tests replace these module attributes
store_file = None
transport = None


def _dbg(msg: str) -> None:
    if DEBUG:
        sys.stderr.write("loxberry.auth: %s\n" % msg)


# ---------------------------------------------------------------------------
# Pure helpers - no I/O, no state
# ---------------------------------------------------------------------------
def _norm_alg(alg):
    """An empty hashAlg means SHA1 (Miniservers from before the field existed)."""
    alg = "" if alg is None else str(alg).upper()
    alg = re.sub(r"[^A-Z0-9]", "", alg)
    if alg in ("", "SHA1"):
        return "SHA1"
    if alg == "SHA256":
        return "SHA256"
    return None


def _digest(alg):
    return hashlib.sha256 if alg == "SHA256" else hashlib.sha1


def _hash_hex(alg, data) -> str:
    return _digest(alg)(data.encode("utf-8")).hexdigest()


def _hmac_hex(alg, data, keyhex) -> str:
    """The key from getkey2 is hex encoded and used as raw bytes."""
    return hmac.new(bytes.fromhex(keyhex), data.encode("utf-8"), _digest(alg)).hexdigest()


def _pw_hash(password, salt, alg) -> str:
    """The Miniserver expects the password hash in uppercase."""
    return _hash_hex(alg, "%s:%s" % (password, salt)).upper()


def _auth_hash(user, pwhash, keyhex, alg) -> str:
    return _hmac_hex(alg, "%s:%s" % (user, pwhash), keyhex)


def _token_hash(token, keyhex, alg) -> str:
    return _hmac_hex(alg, token, keyhex)


def _parse_api_value(value):
    """jdev/cfg/api returns its value as a STRING using single quotes - that is
    not valid JSON and must not be fed to json.loads()."""
    if not value:
        return None
    out = {}
    for m in re.finditer(r"'([^']+)'\s*:\s*(?:'([^']*)'|([^,}\s]+))", value):
        out[m.group(1)] = m.group(2) if m.group(2) is not None else m.group(3)
    return out or None


def _fw_supported(fw) -> int:
    if not fw:
        return 0
    is_ = str(fw).split(".")
    mn = MIN_FIRMWARE.split(".")
    for i in range(4):
        a = int(is_[i]) if i < len(is_) and is_[i].isdigit() else 0
        b = int(mn[i]) if i < len(mn) else 0
        if a > b:
            return 1
        if a < b:
            return 0
    return 1


def _rights_granted(rights, bit) -> int:
    """tokenRights is a bitmask; perm 0x104 was measured to return 1924."""
    if rights is None or bit is None:
        return 0
    return 1 if (int(rights) & int(bit)) == int(bit) else 0


# ---------------------------------------------------------------------------
# Token store - data/system/tokens.json, 0600, owner loxberry
# ---------------------------------------------------------------------------
def _store_file():
    if store_file:
        return store_file
    if getattr(_lb, "lbsdatadir", None):
        return "%s/tokens.json" % _lb.lbsdatadir
    return None


def _store_decode(content):
    if not content or not content.strip():
        return {}
    try:
        data = _json.loads(content)
    except ValueError:
        _dbg("tokens.json is not readable JSON - starting empty")
        return {}
    return data if isinstance(data, dict) else {}


def _store_encode(data) -> str:
    return _json.dumps(data, indent=3, sort_keys=True, ensure_ascii=False)


def _store_read():
    """Read the full store under a shared lock. A missing file is an empty
    store and is NOT created here."""
    path = _store_file()
    if not path or not os.path.exists(path):
        return {}
    try:
        with open(path, "r", encoding="utf-8") as fh:
            if _HAVE_FCNTL:
                try:
                    fcntl.flock(fh, fcntl.LOCK_SH)
                except OSError:
                    pass
            content = fh.read()
    except OSError as exc:
        _dbg("cannot open %s: %s" % (path, exc))
        return {}
    return _store_decode(content)


def _store_update(cb):
    """Read-modify-write under ONE exclusive lock. cb(data) mutates the dict in
    place. Returns 1 = written, 0 = unchanged, None = error."""
    path = _store_file()
    if not path:
        _dbg("no token store path available")
        return None
    try:
        fd = os.open(path, os.O_RDWR | os.O_CREAT, 0o600)
    except OSError as exc:
        _dbg("cannot open %s: %s" % (path, exc))
        return None

    try:
        with os.fdopen(fd, "r+", encoding="utf-8") as fh:
            if _HAVE_FCNTL:
                try:
                    fcntl.flock(fh, fcntl.LOCK_EX)
                except OSError:
                    pass
            content = fh.read()
            data = _store_decode(content)
            before = _store_encode(data)

            cb(data)

            after = _store_encode(data)
            if after == before and content.strip():
                return 0

            fh.seek(0)
            fh.write(after)
            fh.truncate()
    except OSError as exc:
        _dbg("cannot write %s: %s" % (path, exc))
        return None

    try:
        os.chmod(path, 0o600)
    except OSError:
        pass
    try:
        import pwd

        entry = pwd.getpwnam("loxberry")
        os.chown(path, entry.pw_uid, entry.pw_gid)
    except Exception:
        pass
    return 1


# Process cache: the token lives in the process, the file is pure persistence
# across restarts. Another process may change the file behind our back - the
# single 401 retry in request() is the safety net for that.
_tokencache = {}


def _cache_clear():
    _tokencache.clear()
    return 1


def _store_get_token(serial, user):
    if not serial or not user:
        return None
    ck = "%s|%s" % (serial, user)
    if ck in _tokencache:
        return _tokencache[ck]

    data = _store_read()
    tok = data.get(serial, {}).get("users", {}).get(user)
    if tok:
        _tokencache[ck] = tok
    return tok


def _store_put_token(serial, user, msmeta, tokendata):
    if not serial or not user:
        return None
    _tokencache["%s|%s" % (serial, user)] = dict(tokendata)

    def _cb(data):
        entry = data.setdefault(serial, {})
        entry.update(msmeta)
        entry.setdefault("users", {})[user] = dict(tokendata)

    return _store_update(_cb)


def _store_del_token(serial, user):
    if not serial or not user:
        return None
    _tokencache.pop("%s|%s" % (serial, user), None)

    def _cb(data):
        data.get(serial, {}).get("users", {}).pop(user, None)

    return _store_update(_cb)


# ---------------------------------------------------------------------------
# Result objects
# ---------------------------------------------------------------------------
def _err(code, message):
    _dbg("%s - %s" % (code, message))
    return {"ok": 0, "error": code, "message": message}


# ---------------------------------------------------------------------------
# Miniserver resolution
# ---------------------------------------------------------------------------
def _ms_baseurl(msc):
    if not msc:
        return None
    transport_ = msc.get("Transport") or "http"
    port = msc.get("PortHttps") if transport_ == "https" else msc.get("Port")
    if not port:
        port = 443 if transport_ == "https" else 80
    ip = msc.get("IPAddress") or ""
    if ":" in ip:
        ip = "[%s]" % ip
    return "%s://%s:%s" % (transport_, ip, port)


def _resolve_ms(ms, **opts):
    """Accepts a Miniserver number or a serial. A serial is resolved through the
    token store. With a user but without a password the password stays None on
    purpose - the password from general.json belongs to that user only."""
    if ms is None or ms == "":
        return _err("msnotfound", "No Miniserver given")

    serial = None
    msnr = None
    if re.match(r"^\d+$", str(ms)):
        msnr = str(ms)
    else:
        serial = str(ms).upper()
        data = _store_read()
        msnr = data.get(serial, {}).get("msnr")
        if msnr is None:
            return _err("msnotfound",
                        "Serial %s is unknown - fetch a token for this Miniserver first" % ms)
        msnr = str(msnr)

    miniservers = _lb.get_miniservers() or {}
    msc = miniservers.get(msnr)
    if not msc:
        return _err("msnotfound", "Miniserver %s is not configured" % ms)

    user = opts["user"] if opts.get("user") is not None else msc.get("Admin_RAW")
    if opts.get("password") is not None:
        password = opts["password"]
    else:
        password = None if opts.get("user") is not None else msc.get("Pass_RAW")

    return {
        "ok": 1,
        "msnr": msnr,
        "name": msc.get("Name"),
        "baseurl": _ms_baseurl(msc),
        "user": user,
        "password": password,
        "serial": serial,
        "is_lbsystem": 1,
        "lbsystem_user": msc.get("Admin_RAW"),
    }


# ---------------------------------------------------------------------------
# general.json: Authmethod (read only - never written by this lib)
# ---------------------------------------------------------------------------
def auth_method(ms) -> str:
    if ms is None or ms == "":
        return "basicauth"

    msnr = str(ms)
    if not re.match(r"^\d+$", msnr):
        data = _store_read()
        entry = data.get(str(ms).upper())
        if not entry or entry.get("msnr") is None:
            return "basicauth"
        msnr = str(entry["msnr"])

    try:
        with open("%s/general.json" % _lb.lbsconfigdir, "r", encoding="utf-8") as fh:
            cfg = _json.load(fh)
    except (OSError, ValueError):
        return "basicauth"
    if not isinstance(cfg, dict):
        return "basicauth"

    val = cfg.get("Miniserver", {}).get(msnr, {}).get("Authmethod")
    if val is not None and str(val).lower() == "token":
        return "token"
    return "basicauth"


# ---------------------------------------------------------------------------
# HTTP transport
# Verified on Miniserver 17.1.7.3: jdev/cfg/api and jdev/sys/getkey2 answer
# without any authentication. Only killtoken needs Basic Auth.
# ---------------------------------------------------------------------------
def _http_get(url, **opts):
    """Returns (code, body, status). code is None when no connection happened."""
    req = urllib.request.Request(url)
    if opts.get("basicauth_user") is not None:
        import base64

        raw = "%s:%s" % (opts["basicauth_user"], opts.get("basicauth_password") or "")
        req.add_header("Authorization",
                       "Basic " + base64.b64encode(raw.encode("utf-8")).decode("ascii"))

    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE

    try:
        with urllib.request.urlopen(req, timeout=opts.get("timeout") or TIMEOUT,
                                    context=ctx) as resp:
            body = resp.read().decode("utf-8", "replace")
            return (resp.status, body, "%s" % resp.status)
    except urllib.error.HTTPError as exc:
        # an HTTP status - not a connection problem
        try:
            body = exc.read().decode("utf-8", "replace")
        except Exception:
            body = ""
        return (exc.code, body, "%s %s" % (exc.code, exc.reason))
    except Exception as exc:
        return (None, None, str(exc))


# Only these options concern the transport. get_token() and friends also carry
# user/password/perm/force in opts - passing those through would collide with
# the positional "user" parameter of _getkey2() and would leak credentials into
# the transport hook.
_CALL_KEYS = ("timeout", "basicauth_user", "basicauth_password")


def _call_opts(opts):
    return dict((k, v) for k, v in opts.items() if k in _CALL_KEYS)


def _call(url, **opts):
    _dbg("GET %s" % url)
    t = transport if transport else _http_get
    return t(url, **_call_opts(opts))


def _ll_value(body):
    """The LL envelope. value is a dict for most endpoints and a string for
    jdev/cfg/api. A non-JSON body (401 comes back as HTML) is None."""
    if not body or not body.strip():
        return None
    try:
        j = _json.loads(body)
    except ValueError:
        return None
    if not isinstance(j, dict) or not isinstance(j.get("LL"), dict):
        return None
    return j["LL"].get("value")


def _ll_code(body):
    """The LL envelope carries its OWN status code, and the Miniserver does not
    always mirror it into the HTTP status: refreshjwt answers HTTP 200 with
    LL.code 401 when the token signature is not accepted. Measured on 17.1.7.3.
    The field is spelled "Code" by some endpoints (jdev/cfg/api) and "code" by
    others (jdev/sys/*), so both are read."""
    if not body or not body.strip():
        return None
    try:
        j = _json.loads(body)
    except ValueError:
        return None
    if not isinstance(j, dict) or not isinstance(j.get("LL"), dict):
        return None
    c = j["LL"].get("code", j["LL"].get("Code"))
    if c is None or not re.match(r"^\d+$", str(c)):
        return None
    return int(c)


def _effective_code(code, body):
    """The code that really decides: an HTTP 200 carrying a different LL code is
    a failure, not a success."""
    if code is None or code != 200:
        return code
    ll = _ll_code(body)
    if ll is not None and ll != 200:
        return ll
    return code


def _client_uuid(user) -> str:
    """Stable per host and user, so the Miniserver does not collect a new client
    entry on every call. Derived, never persisted."""
    seed = "%s|%s|loxberry-auth" % (_lb.lbhostname(), user)
    h = hashlib.sha256(seed.encode("utf-8")).hexdigest()
    return "%s-%s-%s-%s-%s" % (h[0:8], h[8:12], h[12:16], h[16:20], h[20:32])


# ---------------------------------------------------------------------------
# Miniserver identity: serial + firmware in one call
# ---------------------------------------------------------------------------
def _ms_api(res, **opts):
    code, body, _status = _call(res["baseurl"] + "/jdev/cfg/api", **opts)
    if code is None:
        return _err("unreachable", "%s did not answer" % res["baseurl"])
    code = _effective_code(code, body)
    if code != 200:
        return _err("httperror", "jdev/cfg/api returned %s" % code)

    api = _parse_api_value(_ll_value(body))
    if not api:
        return _err("parseerror", "jdev/cfg/api could not be parsed")
    if not api.get("snr"):
        return _err("parseerror", "jdev/cfg/api has no serial")
    return {"ok": 1, "serial": api["snr"].upper(), "firmware": api.get("version", "")}


def _getkey2(res, user, **opts):
    url = res["baseurl"] + "/jdev/sys/getkey2/" + urllib.parse.quote(str(user), safe="")
    code, body, _status = _call(url, **opts)
    if code is None:
        return _err("unreachable", "%s did not answer" % res["baseurl"])
    code = _effective_code(code, body)
    if code == 401:
        return _err("badcredentials", "getkey2 returned %s for user %s" % (code, user))
    if code != 200:
        return _err("httperror", "getkey2 returned %s" % code)

    v = _ll_value(body)
    if not isinstance(v, dict):
        return _err("parseerror", "getkey2 could not be parsed")
    alg = _norm_alg(v.get("hashAlg"))
    if not alg:
        return _err("parseerror", "getkey2 returned an unknown hashAlg")
    return {"ok": 1, "key": v.get("key"), "salt": v.get("salt"), "alg": alg}


def _serial_from_store(msnr):
    """The serial of a Miniserver number, as far as an earlier run persisted it.
    Looking it up here keeps get_token free of HTTP when a token is cached."""
    data = _store_read()
    for s in sorted(data.keys()):
        if str(data[s].get("msnr")) == str(msnr):
            return (s, data[s].get("firmware"))
    return (None, None)


def _resolve_ms_probing(ms, **opts):
    """Like _resolve_ms, but an unknown serial makes every configured Miniserver
    be asked for its own serial. That is the only way a serial enters the store."""
    res = _resolve_ms(ms, **opts)
    if res["ok"]:
        return res
    if re.match(r"^\d+$", str(ms)):
        return res

    want = str(ms).upper()
    miniservers = _lb.get_miniservers() or {}
    for msnr in sorted(miniservers.keys(), key=lambda k: int(k) if str(k).isdigit() else 0):
        cand = _resolve_ms(msnr, **opts)
        if not cand["ok"]:
            continue
        api = _ms_api(cand, **_call_opts(opts))
        if not api["ok"] or api["serial"] != want:
            continue
        cand["serial"] = want
        cand["firmware"] = api["firmware"]
        return cand
    return _err("msnotfound", "No configured Miniserver has serial %s" % ms)


# ---------------------------------------------------------------------------
# get_token
# ---------------------------------------------------------------------------
def get_token(ms, **opts):
    res = _resolve_ms_probing(ms, **opts)
    if not res["ok"]:
        return res

    user = res["user"]
    if not user:
        return _err("nocredentials", "No user for Miniserver %s" % ms)

    perm = int(opts["perm"]) if opts.get("perm") is not None else DEFAULT_PERM

    # The serial is stable and may come from the store - that is what keeps a
    # cached token completely free of HTTP.
    serial = res.get("serial")
    firmware = res.get("firmware")
    if not serial:
        s, f = _serial_from_store(res["msnr"])
        serial = s
        if not firmware:
            firmware = f

    if not opts.get("force") and serial:
        have = _store_get_token(serial, user)
        if have and have.get("token") and _rights_granted(have.get("rights"), perm):
            return {"ok": 1, "token": have["token"], "validUntil": have["validUntil"],
                    "rights": have["rights"], "perm": have.get("perm"), "user": user,
                    "serial": serial, "firmware": firmware, "msnr": res["msnr"]}

    # Without a password nothing can be fetched - check that before bothering
    # the Miniserver with a single request.
    password = res.get("password")
    if password is None or password == "":
        return _err("nocredentials", "No password available for user %s" % user)

    # From here on a token is really fetched. Unlike the serial the firmware
    # changes with every Miniserver update, so it is never taken from the store.
    if res.get("firmware") is None:
        api = _ms_api(res, **_call_opts(opts))
        if not api["ok"]:
            return api
        serial = api["serial"]
        firmware = api["firmware"]

    if not _fw_supported(firmware):
        return _err("fwtooold", "Miniserver firmware %s is below %s - tokens would need "
                                "application encryption" % (firmware, MIN_FIRMWARE))

    k = _getkey2(res, user, **_call_opts(opts))
    if not k["ok"]:
        return k

    pwhash = _pw_hash(password, k["salt"], k["alg"])
    authhash = _auth_hash(user, pwhash, k["key"], k["alg"])
    info = opts.get("info") or ("LoxBerry %s" % _lb.lbhostname())

    url = ("%s/jdev/sys/gettoken/%s/%s/%d/%s/%s"
           % (res["baseurl"], authhash, urllib.parse.quote(str(user), safe=""), perm,
              _client_uuid(user), urllib.parse.quote(str(info), safe="")))

    code, body, _status = _call(url, **opts)
    if code is None:
        return _err("unreachable", "%s did not answer" % res["baseurl"])
    code = _effective_code(code, body)
    # A wrong user or password shows up HERE, not at getkey2
    if code == 401:
        return _err("badcredentials", "gettoken returned 401 for user %s" % user)
    if code != 200:
        return _err("httperror", "gettoken returned %s" % code)

    v = _ll_value(body)
    if not isinstance(v, dict) or not v.get("token"):
        return _err("parseerror", "gettoken could not be parsed")

    if not _rights_granted(v.get("tokenRights"), perm):
        return _err("missingright",
                    "Miniserver granted rights %s, which does not include the requested "
                    "permission %d (0x%x)" % (v.get("tokenRights"), perm, perm))

    tokendata = {"token": v["token"], "validUntil": v.get("validUntil"),
                 "rights": v.get("tokenRights"), "perm": perm,
                 "acquired": _lb.epoch2lox(), "info": info}
    _store_put_token(serial, user,
                     {"msnr": res["msnr"], "name": res["name"],
                      "is_lbsystem": res["is_lbsystem"], "lbsystem_user": res["lbsystem_user"],
                      "firmware": firmware, "checked": _lb.epoch2lox()},
                     tokendata)

    out = dict(tokendata)
    out.update({"ok": 1, "user": user, "serial": serial, "firmware": firmware,
                "msnr": res["msnr"]})
    return out


# ---------------------------------------------------------------------------
# token_info / refresh_token / kill_token / request
# ---------------------------------------------------------------------------
def token_info(ms, **opts):
    res = _resolve_ms_probing(ms, **opts)
    if not res["ok"]:
        return res

    serial = res.get("serial")
    data = _store_read()
    if not serial:
        for s in sorted(data.keys()):
            if str(data[s].get("msnr")) == str(res["msnr"]):
                serial = s
                break
    if not serial:
        return _err("notoken", "No token stored for Miniserver %s" % ms)

    have = data.get(serial, {}).get("users", {}).get(res["user"])
    if not have or not have.get("token"):
        return _err("notoken", "No token stored for user %s" % res["user"])

    return {"ok": 1, "token": have["token"], "validUntil": have["validUntil"],
            "rights": have.get("rights"), "perm": have.get("perm"), "info": have.get("info"),
            "user": res["user"], "serial": serial, "msnr": res["msnr"],
            "firmware": data[serial].get("firmware"),
            "expires_in": int(have["validUntil"]) - _lb.epoch2lox()}


def refresh_token(ms, **opts):
    """refreshjwt works with token authentication only - no password involved.
    It answers with a JWT (eyJ0eXAi...) instead of the hex token."""
    have = token_info(ms, **opts)
    if not have["ok"]:
        return have
    res = _resolve_ms_probing(ms, **opts)
    if not res["ok"]:
        return res

    k = _getkey2(res, have["user"], **_call_opts(opts))
    if not k["ok"]:
        return k
    h = _token_hash(have["token"], k["key"], k["alg"])

    # The path carries the token HASH, autht the PLAIN token. Measured on
    # 17.1.7.3: hashing both consumes the one-time key twice and the Miniserver
    # answers HTTP 200 with LL.code 401.
    quoted = urllib.parse.quote(str(have["user"]), safe="")
    url = "%s/jdev/sys/refreshjwt/%s/%s?autht=%s&user=%s" % (
        res["baseurl"], h, quoted,
        urllib.parse.quote(str(have["token"]), safe=""), quoted)

    code, body, _status = _call(url, **opts)
    if code is None:
        return _err("unreachable", "%s did not answer" % res["baseurl"])
    code = _effective_code(code, body)
    if code == 401:
        return _err("revoked", "refreshjwt returned 401 - the token was not accepted")
    if code != 200:
        return _err("httperror", "refreshjwt returned %s" % code)

    v = _ll_value(body)
    if not isinstance(v, dict) or not v.get("token"):
        return _err("parseerror", "refreshjwt could not be parsed")

    tokendata = {"token": v["token"], "validUntil": v.get("validUntil"),
                 "rights": v.get("tokenRights", have.get("rights")), "perm": have.get("perm"),
                 "acquired": _lb.epoch2lox(), "info": have.get("info")}
    _store_put_token(have["serial"], have["user"],
                     {"msnr": res["msnr"], "checked": _lb.epoch2lox()}, tokendata)

    out = dict(tokendata)
    out.update({"ok": 1, "user": have["user"], "serial": have["serial"],
                "firmware": have.get("firmware"), "msnr": res["msnr"]})
    return out


def kill_token(ms, **opts):
    """Revoking needs the password: killtoken was measured to work with Basic
    Auth only, not with token authentication."""
    have = token_info(ms, **opts)
    if not have["ok"]:
        return have
    res = _resolve_ms_probing(ms, **opts)
    if not res["ok"]:
        return res
    if res.get("password") in (None, ""):
        return _err("nopassword", "kill_token needs the password of user %s" % have["user"])

    k = _getkey2(res, have["user"], **_call_opts(opts))
    if not k["ok"]:
        return k
    h = _token_hash(have["token"], k["key"], k["alg"])

    url = "%s/jdev/sys/killtoken/%s/%s" % (res["baseurl"], h,
                                           urllib.parse.quote(str(have["user"]), safe=""))
    callopts = dict(opts)
    callopts["basicauth_user"] = have["user"]
    callopts["basicauth_password"] = res["password"]

    code, body, _status = _call(url, **callopts)
    if code is None:
        return _err("unreachable", "%s did not answer" % res["baseurl"])
    code = _effective_code(code, body)
    if code == 401:
        return _err("badcredentials", "killtoken returned 401")
    if code != 200:
        return _err("httperror", "killtoken returned %s" % code)

    _store_del_token(have["serial"], have["user"])
    return {"ok": 1, "user": have["user"], "serial": have["serial"]}


def _sign_url(baseurl, command, token, user, res, **opts):
    k = _getkey2(res, user, **_call_opts(opts))
    if not k["ok"]:
        return (None, k)
    h = _token_hash(token, k["key"], k["alg"])
    sep = "&" if "?" in command else "?"
    return ("%s%s%sautht=%s&user=%s"
            % (baseurl, command, sep, h, urllib.parse.quote(str(user), safe="")), None)


def request(ms, command, **opts):
    """Runs a Miniserver command with token authentication.
    Returns (content, info) - same keys as loxberry.io.mshttp_call2, plus
    errcode carrying the error code of this lib."""
    info = {"code": None, "status": None, "error": 1, "message": "", "errcode": None}

    tok = get_token(ms, **opts)
    if not tok["ok"]:
        info["errcode"] = tok["error"]
        info["message"] = tok["message"]
        return (None, info)

    left = int(tok["validUntil"]) - _lb.epoch2lox()
    if left <= 0:
        forced = dict(opts)
        forced["force"] = 1
        tok = get_token(ms, **forced)
    elif left < REFRESH_THRESHOLD:
        r = refresh_token(ms, **opts)
        if r["ok"]:
            tok = r
    if not tok["ok"]:
        info["errcode"] = tok["error"]
        info["message"] = tok["message"]
        return (None, info)

    res = _resolve_ms_probing(ms, **opts)
    if not res["ok"]:
        info["errcode"] = res["error"]
        info["message"] = res["message"]
        return (None, info)

    for attempt in (1, 2):
        url, urlerr = _sign_url(res["baseurl"], command, tok["token"], tok["user"], res, **_call_opts(opts))
        if not url:
            info["errcode"] = urlerr["error"]
            info["message"] = urlerr["message"]
            return (None, info)

        code, body, status = _call(url, **opts)
        if code is None:
            info["errcode"] = "unreachable"
            info["message"] = "%s did not answer" % res["baseurl"]
            return (None, info)

        code = _effective_code(code, body)
        info["code"] = code
        info["status"] = status

        if code == 401:
            # The token may be gone on the Miniserver although validUntil still
            # looks fine. Fetch a new one and retry ONCE.
            if attempt == 1:
                forced = dict(opts)
                forced["force"] = 1
                fresh = get_token(ms, **forced)
                if fresh["ok"]:
                    tok = fresh
                    continue
                info["errcode"] = fresh["error"]
                info["message"] = fresh["message"]
                return (None, info)
            info["errcode"] = "revoked"
            info["message"] = "%s returned 401 twice - the token was revoked" % command
            return (None, info)

        if code < 200 or code >= 300:
            info["errcode"] = "httperror"
            info["message"] = "%s FAILED - Error %s" % (command, code)
            return (None, info)

        info["error"] = 0
        info["message"] = "Request ok"
        return (body, info)
