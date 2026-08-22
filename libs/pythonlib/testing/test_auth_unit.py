#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
test_auth_unit.py - offline unit tests for loxberry/auth.py.
No Miniserver needed; the transport hook is replaced by a fake.

    python3 test_auth_unit.py

Sets its own LBHOMEDIR below a temp dir, so the productive installation is
never touched.
"""

from __future__ import annotations

import json
import os
import sys
import tempfile
import time
import unittest

_HOME = tempfile.mkdtemp(prefix="authtest_")
os.environ["LBHOMEDIR"] = _HOME
os.makedirs(os.path.join(_HOME, "config", "system"), exist_ok=True)
os.makedirs(os.path.join(_HOME, "data", "system"), exist_ok=True)

GENERAL_JSON = """{
  "Base": { "Lang": "de", "Version": "4.0.0.15" },
  "Miniserver": {
    "1": {
      "Name": "Miniserver", "Ipaddress": "192.0.2.10",
      "Admin": "loxberry", "Pass": "TestPass%2123",
      "Admin_raw": "loxberry", "Pass_raw": "TestPass!23",
      "Credentials_raw": "loxberry:TestPass!23",
      "Port": 80, "Porthttps": 443, "Preferhttps": 0
    },
    "2": {
      "Name": "MS Secure", "Ipaddress": "192.0.2.11",
      "Admin": "admin", "Pass": "secret",
      "Admin_raw": "admin", "Pass_raw": "secret",
      "Credentials_raw": "admin:secret",
      "Port": 80, "Porthttps": 4443, "Preferhttps": 1,
      "Authmethod": "token"
    },
    "3": {
      "Name": "MS IPv6", "Ipaddress": "fe80::1",
      "Admin": "admin", "Pass": "secret",
      "Admin_raw": "admin", "Pass_raw": "secret",
      "Credentials_raw": "admin:secret",
      "Port": 80, "Porthttps": 443, "Preferhttps": 0,
      "Authmethod": "basicauth"
    }
  }
}
"""
with open(os.path.join(_HOME, "config", "system", "general.json"), "w", encoding="utf-8") as _fh:
    _fh.write(GENERAL_JSON)

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from loxberry import auth
from loxberry import system as _lbsys

KEY = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
STORE = os.path.join(_HOME, "data", "system", "tokens.json")


class TestPure(unittest.TestCase):
    def test_norm_alg(self):
        self.assertEqual(auth._norm_alg("SHA256"), "SHA256")
        self.assertEqual(auth._norm_alg("sha-256"), "SHA256")
        self.assertEqual(auth._norm_alg("SHA1"), "SHA1")
        self.assertEqual(auth._norm_alg(None), "SHA1")
        self.assertIsNone(auth._norm_alg("MD5"))

    def test_hash_chain_sha256(self):
        pw = auth._pw_hash("Test1234", "41B0A8F1", "SHA256")
        self.assertEqual(pw, "3E4A5D209675FD7633320D7F1AA5B399174D2B397ABE4FE53118FCECE38A847D")
        self.assertEqual(auth._auth_hash("loxberry", pw, KEY, "SHA256"),
                         "31db6348ae60d52f53381bc3ebf2b7b1691a55e51110ef31ac50b19b1b2f9f47")
        self.assertEqual(auth._token_hash("a1b2c3d4e5f60718293a4b5c6d7e8f90", KEY, "SHA256"),
                         "7c75d4ea7111e124200e9939ded8f9d2ece6835089a4d5ff1fb6d96e57b6dd65")

    def test_hash_chain_sha1(self):
        pw = auth._pw_hash("Test1234", "41B0A8F1", "SHA1")
        self.assertEqual(pw, "3A09820F277977B59FE88D032BBC7ECF5C2C7BCD")
        self.assertEqual(auth._auth_hash("loxberry", pw, KEY, "SHA1"),
                         "dde0f27175043736346411f693364a2bee2c0308")
        self.assertEqual(auth._token_hash("a1b2c3d4e5f60718293a4b5c6d7e8f90", KEY, "SHA1"),
                         "9135606ae0eac2862b8536f0adc059cf57fd7e62")

    def test_parse_api_value(self):
        # jdev/cfg/api returns value as a STRING with single quotes - not JSON
        val = ("{'snr': 'AB:CD:EF:01:02:03', 'version':'17.1.7.3', 'hasEventSlots':true, "
               "'isInTrust':false, 'local':true,'certTLD':'com'}")
        api = auth._parse_api_value(val)
        self.assertEqual(api["snr"], "AB:CD:EF:01:02:03")
        self.assertEqual(api["version"], "17.1.7.3")
        self.assertEqual(api["certTLD"], "com")
        self.assertEqual(api["local"], "true")
        self.assertIsNone(auth._parse_api_value(""))
        self.assertIsNone(auth._parse_api_value(None))

    def test_fw_supported(self):
        self.assertEqual(auth._fw_supported("17.1.7.3"), 1)
        self.assertEqual(auth._fw_supported("11.2.10.22"), 1)
        self.assertEqual(auth._fw_supported("11.2.10.21"), 0)
        self.assertEqual(auth._fw_supported("11.2.9.99"), 0)
        self.assertEqual(auth._fw_supported("12.0"), 1)
        self.assertEqual(auth._fw_supported(""), 0)

    def test_rights_granted(self):
        # perm 0x104 was measured to return tokenRights 1924 = 4+128+256+512+1024
        self.assertEqual(auth._rights_granted(1924, auth.PERM_SYSWS), 1)
        self.assertEqual(auth._rights_granted(1924, auth.PERM_APP), 1)
        self.assertEqual(auth._rights_granted(4, auth.PERM_SYSWS), 0)
        self.assertEqual(auth._rights_granted(1924, 0x104), 1)

    def test_constants(self):
        self.assertEqual(auth.DEFAULT_PERM, 0x104)
        self.assertEqual(auth.REFRESH_THRESHOLD, 7 * 86400)
        self.assertEqual(auth.MIN_FIRMWARE, "11.2.10.22")


class TestStore(unittest.TestCase):
    def setUp(self):
        auth.store_file = STORE
        # the process cache outlives the file - clear it or a previous test's
        # token answers here
        auth._cache_clear()
        if os.path.exists(STORE):
            os.unlink(STORE)

    def test_read_without_file(self):
        self.assertEqual(auth._store_file(), STORE)
        self.assertEqual(auth._store_read(), {})
        self.assertFalse(os.path.exists(STORE))
        self.assertIsNone(auth._store_get_token("AB:CD:EF:01:02:03", "loxberry"))

    def test_put_get_del(self):
        msmeta = {"msnr": "1", "name": "Miniserver", "is_lbsystem": True,
                  "lbsystem_user": "loxberry", "firmware": "17.1.7.3", "checked": 556606212}
        tok = {"token": "abc123", "validUntil": 564559554, "rights": 1924,
               "perm": 260, "acquired": 556606212, "info": "LoxBerry testhost"}

        self.assertEqual(auth._store_put_token("AB:CD:EF:01:02:03", "loxberry", msmeta, tok), 1)
        self.assertTrue(os.path.exists(STORE))
        if os.name == "posix":
            self.assertEqual(os.stat(STORE).st_mode & 0o777, 0o600)

        got = auth._store_get_token("AB:CD:EF:01:02:03", "loxberry")
        self.assertEqual(got["token"], "abc123")
        self.assertEqual(got["validUntil"], 564559554)

        with open(STORE, encoding="utf-8") as fh:
            raw = json.load(fh)
        self.assertEqual(raw["AB:CD:EF:01:02:03"]["name"], "Miniserver")
        self.assertEqual(raw["AB:CD:EF:01:02:03"]["firmware"], "17.1.7.3")
        self.assertIn("loxberry", raw["AB:CD:EF:01:02:03"]["users"])
        self.assertNotIn("password", raw["AB:CD:EF:01:02:03"]["users"]["loxberry"])
        self.assertNotIn("key", raw["AB:CD:EF:01:02:03"]["users"]["loxberry"])

        # unchanged content must not touch the file - the store is on the SD card
        mtime = os.stat(STORE).st_mtime
        time.sleep(1)
        self.assertEqual(auth._store_put_token("AB:CD:EF:01:02:03", "loxberry", msmeta, tok), 0)
        self.assertEqual(os.stat(STORE).st_mtime, mtime)

        tok2 = dict(tok, token="def456")
        self.assertEqual(auth._store_put_token("AB:CD:EF:01:02:03", "loxberry", msmeta, tok2), 1)
        self.assertEqual(auth._store_get_token("AB:CD:EF:01:02:03", "loxberry")["token"], "def456")

        auth._store_put_token("AB:CD:EF:01:02:03", "sortmgr", msmeta, tok)
        self.assertEqual(auth._store_get_token("AB:CD:EF:01:02:03", "sortmgr")["token"], "abc123")
        self.assertEqual(auth._store_get_token("AB:CD:EF:01:02:03", "loxberry")["token"], "def456")

        self.assertEqual(auth._store_del_token("AB:CD:EF:01:02:03", "sortmgr"), 1)
        self.assertIsNone(auth._store_get_token("AB:CD:EF:01:02:03", "sortmgr"))
        self.assertEqual(auth._store_del_token("AB:CD:EF:01:02:03", "sortmgr"), 0)

    def test_broken_file(self):
        with open(STORE, "w", encoding="utf-8") as fh:
            fh.write("{ das ist kein json")
        self.assertEqual(auth._store_read(), {})


class TestResolve(unittest.TestCase):
    def setUp(self):
        auth.store_file = STORE
        # the process cache outlives the file - clear it or a previous test's
        # token answers here
        auth._cache_clear()
        if os.path.exists(STORE):
            os.unlink(STORE)

    def test_err(self):
        e = auth._err("unreachable", "timed out")
        self.assertEqual(e["ok"], 0)
        self.assertEqual(e["error"], "unreachable")
        self.assertEqual(e["message"], "timed out")

    def test_by_number(self):
        r = auth._resolve_ms(1)
        self.assertEqual(r["ok"], 1)
        self.assertEqual(r["msnr"], "1")
        self.assertEqual(r["name"], "Miniserver")
        self.assertEqual(r["baseurl"], "http://192.0.2.10:80")
        self.assertEqual(r["user"], "loxberry")
        # the plaintext password comes from Pass_raw, never from the escaped Pass
        self.assertEqual(r["password"], "TestPass!23")
        self.assertEqual(auth._resolve_ms(2)["baseurl"], "https://192.0.2.11:4443")
        self.assertEqual(auth._resolve_ms(3)["baseurl"], "http://[fe80::1]:80")

    def test_user_option(self):
        r = auth._resolve_ms(1, user="sortmgr", password="geheim")
        self.assertEqual(r["user"], "sortmgr")
        self.assertEqual(r["password"], "geheim")
        # a foreign user must never inherit the password from general.json
        self.assertIsNone(auth._resolve_ms(1, user="sortmgr")["password"])

    def test_not_found(self):
        self.assertEqual(auth._resolve_ms(9)["error"], "msnotfound")
        self.assertEqual(auth._resolve_ms(None)["error"], "msnotfound")
        self.assertEqual(auth._resolve_ms("")["error"], "msnotfound")
        self.assertEqual(auth._resolve_ms("AB:CD:EF:01:02:03")["error"], "msnotfound")

    def test_by_serial(self):
        auth._store_put_token("AB:CD:EF:01:02:03", "loxberry",
                              {"msnr": "1", "name": "Miniserver", "firmware": "17.1.7.3"},
                              {"token": "abc", "validUntil": 1, "rights": 1924})
        r = auth._resolve_ms("AB:CD:EF:01:02:03")
        self.assertEqual(r["ok"], 1)
        self.assertEqual(r["msnr"], "1")
        self.assertEqual(r["serial"], "AB:CD:EF:01:02:03")
        self.assertEqual(auth._resolve_ms("ab:cd:ef:01:02:03")["msnr"], "1")

    def test_auth_method(self):
        auth._store_put_token("AB:CD:EF:01:02:03", "loxberry", {"msnr": "1"},
                              {"token": "abc", "validUntil": 1, "rights": 1924})
        self.assertEqual(auth.auth_method(1), "basicauth")
        self.assertEqual(auth.auth_method(2), "token")
        self.assertEqual(auth.auth_method(3), "basicauth")
        self.assertEqual(auth.auth_method(9), "basicauth")
        self.assertEqual(auth.auth_method("AB:CD:EF:01:02:03"), "basicauth")



KEY2 = KEY
TOKHASH = "3b50109633af4140485302f72bd8a2734950286ca29a4633ef6c54376540bd69"
AUTHHASH = "6811aac909afa7d530fd1cf87a28e4a9db15ad4e99eea57b33944319b05a86c5"


class FakeMiniserver(object):
    """Replaces auth.transport. Records every URL and every option dict."""

    def __init__(self):
        self.calls = []
        self.optlog = []
        self.api_fw = "17.1.7.3"
        self.api_serial = "AB:CD:EF:01:02:03"
        self.gettoken = "ok"          # ok | 401 | unreachable
        self.rights = 1924
        self.validUntil = 999999999
        self.unreachable_all = False
        self.refresh = "ok"           # ok | 401 | ll401
        self.kill = "ok"              # ok | 401
        self.cmd_401_once = 0

    def __call__(self, url, **opts):
        self.calls.append(url)
        self.optlog.append((url, dict(opts)))
        if self.unreachable_all:
            return (None, None, "Connection refused")

        if url.endswith("/jdev/cfg/api"):
            v = ("{'snr': '%s', 'version':'%s', 'hasEventSlots':true, "
                 "'isInTrust':false, 'local':true,'certTLD':'com'}" % (self.api_serial, self.api_fw))
            return (200, '{"LL": { "control": "dev/cfg/api", "value": "%s", "Code": "200"}}' % v, "200 OK")

        if "/jdev/sys/getkey2/" in url:
            return (200, '{"LL":{"control":"dev/sys/getkey2","code":"200","value":'
                         '{"key":"%s","salt":"41B0A8F1","hashAlg":"SHA256"}}}' % KEY2, "200 OK")

        if "/jdev/sys/gettoken/" in url:
            if self.gettoken == "unreachable":
                return (None, None, "Connection refused")
            if self.gettoken == "401":
                return (401, "<html><body>401</body></html>", "401 Unauthorized")
            return (200, '{"LL":{"control":"dev/sys/gettoken","code":"200","value":'
                         '{"token":"tokTESTVALUE123","key":"%s","validUntil":%d,'
                         '"tokenRights":%d,"unsecurePass":false}}}'
                         % (KEY2, self.validUntil, self.rights), "200 OK")

        if "/jdev/sys/refreshjwt/" in url:
            if self.refresh == "401":
                return (401, "<html>401</html>", "401 Unauthorized")
            if self.refresh == "ll401":
                # measured on the real Miniserver: HTTP 200 with LL.code 401
                return (200, '{"LL":{"control":"dev/sys/refreshjwt","value":{},"code":"401"}}', "200 OK")
            return (200, '{"LL":{"control":"dev/sys/refreshjwt","code":"200","value":'
                         '{"token":"eyJ0eXAiTESTJWT","validUntil":%d,"tokenRights":1924,'
                         '"unsecurePass":false}}}' % self.validUntil, "200 OK")

        if "/jdev/sys/killtoken/" in url:
            if self.kill == "401":
                return (401, "<html>401</html>", "401 Unauthorized")
            return (200, '{"LL":{"control":"dev/sys/killtoken","code":"200","value":"1"}}', "200 OK")

        if "autht=" in url:
            if self.cmd_401_once > 0:
                self.cmd_401_once -= 1
                return (401, "<html>401</html>", "401 Unauthorized")
            return (200, '{"LL":{"control":"dev/sps/io/Test","code":"200","value":"42"}}', "200 OK")

        return (404, "not found", "404 Not Found")


class TestFlows(unittest.TestCase):
    def setUp(self):
        auth.store_file = STORE
        # the process cache outlives the file - clear it or a previous test's
        # token answers here
        auth._cache_clear()
        if os.path.exists(STORE):
            os.unlink(STORE)
        self.ms = FakeMiniserver()
        auth.transport = self.ms

    def tearDown(self):
        auth.transport = None

    def _urls(self, needle):
        return [u for u in self.ms.calls if needle in u]

    def _seed(self, validUntil_offset=60 * 86400, token="tokTESTVALUE123"):
        auth._store_put_token("AB:CD:EF:01:02:03", "loxberry",
                              {"msnr": "1", "name": "Miniserver", "firmware": "17.1.7.3"},
                              {"token": token,
                               "validUntil": _lbsys.epoch2lox() + validUntil_offset,
                               "rights": 1924, "perm": 260, "acquired": 1, "info": "x"})

    def test_ll_value(self):
        self.assertEqual(auth._ll_value('{"LL":{"value":{"a":1},"Code":"200"}}')["a"], 1)
        self.assertEqual(auth._ll_value('{"LL":{"value":"text","Code":"200"}}'), "text")
        self.assertIsNone(auth._ll_value("<html>kaputt</html>"))
        self.assertIsNone(auth._ll_value(""))

    def test_ll_code_and_effective_code(self):
        self.assertEqual(auth._ll_code('{"LL":{"value":{},"code":"401"}}'), 401)
        self.assertEqual(auth._ll_code('{"LL":{"value":"x","Code":"200"}}'), 200)
        self.assertIsNone(auth._ll_code("<html>401</html>"))
        # an HTTP 200 carrying LL.code 401 is a failure
        self.assertEqual(auth._effective_code(200, '{"LL":{"value":{},"code":"401"}}'), 401)
        self.assertEqual(auth._effective_code(200, '{"LL":{"value":"x","Code":"200"}}'), 200)
        self.assertEqual(auth._effective_code(401, "<html>401</html>"), 401)

    def test_client_uuid(self):
        u = auth._client_uuid("loxberry")
        self.assertRegex(u, r"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$")
        self.assertEqual(auth._client_uuid("loxberry"), u)
        self.assertNotEqual(auth._client_uuid("sortmgr"), u)

    def test_ms_api(self):
        api = auth._ms_api(auth._resolve_ms(1))
        self.assertEqual(api["ok"], 1)
        self.assertEqual(api["serial"], "AB:CD:EF:01:02:03")
        self.assertEqual(api["firmware"], "17.1.7.3")

    def test_get_token_happy(self):
        t = auth.get_token(1)
        self.assertEqual(t["ok"], 1)
        self.assertEqual(t["token"], "tokTESTVALUE123")
        self.assertEqual(t["validUntil"], 999999999)
        self.assertEqual(t["rights"], 1924)
        self.assertEqual(t["perm"], 260)          # 0x104
        self.assertEqual(t["user"], "loxberry")
        self.assertEqual(t["serial"], "AB:CD:EF:01:02:03")
        self.assertEqual(t["firmware"], "17.1.7.3")

        url = self._urls("/jdev/sys/gettoken/")[0]
        self.assertIn("/jdev/sys/gettoken/%s/loxberry/260/" % AUTHHASH, url)

        stored = auth._store_get_token("AB:CD:EF:01:02:03", "loxberry")
        self.assertEqual(stored["token"], "tokTESTVALUE123")
        self.assertNotIn("key", stored)
        self.assertNotIn("password", stored)

    def test_get_token_uses_store(self):
        auth.get_token(1)
        self.ms.calls = []
        t = auth.get_token(1)
        self.assertEqual(t["token"], "tokTESTVALUE123")
        self.assertEqual(len(self.ms.calls), 0)

        auth.get_token(1, force=1)
        self.assertGreaterEqual(len(self.ms.calls), 2)

    def test_get_token_by_serial(self):
        auth.get_token(1)
        self.assertEqual(auth.get_token("AB:CD:EF:01:02:03")["ok"], 1)

    def test_missing_right(self):
        self.ms.rights = 4          # App only, no Sys-WS
        r = auth.get_token(1, force=1)
        self.assertEqual(r["error"], "missingright")

    def test_bad_credentials(self):
        # the 401 arrives at gettoken - getkey2 answers 200 even for an
        # unknown user
        self.ms.gettoken = "401"
        self.assertEqual(auth.get_token(1, force=1)["error"], "badcredentials")

    def test_firmware_too_old(self):
        self.ms.api_fw = "11.2.10.21"
        r = auth.get_token(1, force=1)
        self.assertEqual(r["error"], "fwtooold")
        self.assertEqual(len(self._urls("/jdev/sys/")), 0)

    def test_unreachable(self):
        self.ms.unreachable_all = True
        self.assertEqual(auth.get_token(1, force=1)["error"], "unreachable")

    def test_no_credentials(self):
        r = auth.get_token(1, user="sortmgr")
        self.assertEqual(r["error"], "nocredentials")
        self.assertEqual(len(self.ms.calls), 0)

    def test_foreign_user(self):
        t = auth.get_token(1, user="sortmgr", password="geheim", perm=0x04)
        self.assertEqual(t["ok"], 1)
        self.assertEqual(t["perm"], 4)
        self.assertEqual(t["user"], "sortmgr")
        self.assertEqual(auth._store_get_token("AB:CD:EF:01:02:03", "sortmgr")["token"],
                         "tokTESTVALUE123")

    def test_token_info(self):
        self._seed()
        ti = auth.token_info(1)
        self.assertEqual(ti["ok"], 1)
        self.assertEqual(ti["token"], "tokTESTVALUE123")
        self.assertEqual(ti["serial"], "AB:CD:EF:01:02:03")
        self.assertGreater(ti["expires_in"], 59 * 86400)
        self.assertEqual(auth.token_info(1, user="niemand")["error"], "notoken")

    def test_request_happy(self):
        self._seed()
        content, info = auth.request(1, "/jdev/sps/io/Test")
        self.assertEqual(info["code"], 200)
        self.assertEqual(info["error"], 0)
        self.assertIn('"value":"42"', content)
        url = self._urls("/jdev/sps/io/Test")[0]
        self.assertTrue(url.endswith("?autht=%s&user=loxberry" % TOKHASH))
        # the one-time key is fetched again for every signed request
        self.ms.calls = []
        auth.request(1, "/jdev/sps/io/Test")
        self.assertEqual(len(self._urls("/jdev/sys/getkey2/")), 1)

    def test_request_existing_query(self):
        self._seed()
        auth.request(1, "/jdev/sps/io/Test?state=on")
        self.assertIn("?state=on&autht=", self._urls("/jdev/sps/io/Test")[0])

    def test_request_retries_once_on_401(self):
        self._seed()
        self.ms.cmd_401_once = 1
        content, info = auth.request(1, "/jdev/sps/io/Test")
        self.assertEqual(info["error"], 0)
        self.assertEqual(len(self._urls("/jdev/sys/gettoken/")), 1)

    def test_request_revoked_on_second_401(self):
        self._seed()
        self.ms.cmd_401_once = 2
        content, info = auth.request(1, "/jdev/sps/io/Test")
        self.assertEqual(info["errcode"], "revoked")
        self.assertIsNone(content)

    def test_expired_token_is_refetched(self):
        self._seed(validUntil_offset=-10)
        auth.request(1, "/jdev/sps/io/Test")
        self.assertEqual(len(self._urls("/jdev/sys/gettoken/")), 1)
        self.assertEqual(len(self._urls("/jdev/sys/refreshjwt/")), 0)

    def test_token_below_threshold_is_renewed(self):
        self._seed(validUntil_offset=3 * 86400)
        auth.request(1, "/jdev/sps/io/Test")
        self.assertEqual(len(self._urls("/jdev/sys/refreshjwt/")), 1)
        self.assertEqual(len(self._urls("/jdev/sys/gettoken/")), 0)
        self.assertEqual(auth._store_get_token("AB:CD:EF:01:02:03", "loxberry")["token"],
                         "eyJ0eXAiTESTJWT")

    def test_refresh_token(self):
        self._seed()
        r = auth.refresh_token(1)
        self.assertEqual(r["ok"], 1)
        self.assertEqual(r["token"], "eyJ0eXAiTESTJWT")
        self.assertEqual(auth.refresh_token(1, user="niemand")["error"], "notoken")

    def test_refresh_uses_plain_token_in_autht(self):
        self._seed()
        auth.refresh_token(1)
        url = self._urls("/jdev/sys/refreshjwt/")[0]
        self.assertRegex(url, r"/jdev/sys/refreshjwt/[0-9a-f]{64}/loxberry\?autht=")
        self.assertIn("autht=tokTESTVALUE123&", url)

    def test_refresh_rejected(self):
        self._seed()
        self.ms.refresh = "401"
        self.assertEqual(auth.refresh_token(1)["error"], "revoked")
        self.ms.refresh = "ll401"
        self.assertEqual(auth.refresh_token(1)["error"], "revoked")

    def test_kill_token(self):
        self._seed()
        self.assertEqual(auth.kill_token(1, user="sortmgr")["error"], "notoken")
        k = auth.kill_token(1)
        self.assertEqual(k["ok"], 1)
        killopts = [o for u, o in self.ms.optlog if "/jdev/sys/killtoken/" in u][0]
        self.assertEqual(killopts["basicauth_user"], "loxberry")
        self.assertEqual(killopts["basicauth_password"], "TestPass!23")
        self.assertIsNone(auth._store_get_token("AB:CD:EF:01:02:03", "loxberry"))


class TestProcessCache(unittest.TestCase):
    def setUp(self):
        auth.store_file = STORE
        auth._cache_clear()
        if os.path.exists(STORE):
            os.unlink(STORE)

    def test_cache(self):
        auth._store_put_token("AA:BB:CC:DD:EE:FF", "cacheuser", {"msnr": "1"},
                              {"token": "cached1", "validUntil": 5, "rights": 1924})
        # pull the file away underneath the process - the cache must still answer
        os.unlink(STORE)
        self.assertEqual(
            auth._store_get_token("AA:BB:CC:DD:EE:FF", "cacheuser")["token"], "cached1")

        auth._cache_clear()
        self.assertIsNone(auth._store_get_token("AA:BB:CC:DD:EE:FF", "cacheuser"))

        auth._store_put_token("AA:BB:CC:DD:EE:FF", "cacheuser", {"msnr": "1"},
                              {"token": "cached2", "validUntil": 5, "rights": 1924})
        self.assertEqual(
            auth._store_get_token("AA:BB:CC:DD:EE:FF", "cacheuser")["token"], "cached2")

        auth._store_del_token("AA:BB:CC:DD:EE:FF", "cacheuser")
        self.assertIsNone(auth._store_get_token("AA:BB:CC:DD:EE:FF", "cacheuser"))


if __name__ == "__main__":
    unittest.main(verbosity=2)
