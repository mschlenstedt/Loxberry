#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
mqtt-scan-miniserver.py - liest die virtuellen Eingänge aus der Programmdatei
der Miniserver. Grundlage für den Button "Miniserver scannen" im MQTT Gateway V2.

Ablauf je Miniserver:
  1. /dev/fslist/prog/         -> neueste sps_*.zip bzw. sps_*.LoxCC finden
  2. /dev/fsget/prog/<datei>   -> in den Arbeitsspeicher laden
  3. entpacken (zip/LoxCC) und VirtualIn/VirtualTextIn aus dem XML lesen
  4. jeden Eingang über die IntAddr seines LoxLIVE-Knotens einem
     LoxBerry-Miniserver zuordnen

Es wird nichts an den Miniserver gesendet und nichts auf Datenträger oder
RAM-Disk geschrieben. Bewusst ohne Cache: Der Scan wird im Wesentlichen einmal
beim Umstieg von V1 auf V2 gebraucht. Enthält ein Projekt mehrere Miniserver
(Client/Gateway), wird es nur einmal geladen.

Ausgabe auf stdout (JSON):
  {"miniservers": {"1": {"name": "Haus", "ok": true, "error": null,
                         "source": "download" | "project:<msnr>",
                         "inputs": [{"name": "w4l_cur_tt", "type": "VirtualIn"}]}}}

Fehlercodes in "error": auth_token, denied, unreachable, nofile, unpack, xml,
http, internal

Herkunft: Download, Entpacken und Miniserver-Zuordnung folgen Stats4Lox-NG
(mschlenstedt/LoxBerry-Plugin-Stats4Lox-NG, bin/libs/Loxone/GetLoxplan.pm,
unpack_loxcc.py, ParseXML.pm; Apache-2.0). LoxCC-Algorithmus von Sarnau,
https://github.com/sarnau/Inside-The-Loxone-Miniserver

Aufruf: mqtt-scan-miniserver.py [--ms 1,2] [--pretty]
"""

from __future__ import annotations

import argparse
import base64
import io
import json
import os
import re
import socket
import ssl
import struct
import sys
import urllib.error
import urllib.parse
import urllib.request
import zipfile
import zlib

# Eingänge, die der Gateway über /dev/sps/io/<Name> beschreibt. Neben dem virtuellen
# (Text-)Eingang nimmt auch der "Virtuelle HTTP Eingang Befehl" (VirtualHttpInCmd)
# Werte über seinen Namen an. VirtualUdpInCmd wird über die Befehlserkennung
# angesprochen, CallerVirtualIn gehört zum Anruf-Baustein - beide bleiben außen vor.
INPUT_TYPES = ("VirtualIn", "VirtualTextIn", "VirtualHttpInCmd")
TIMEOUT_SHORT = 5
TIMEOUT_DOWNLOAD = 90
LOXCC_MAGIC = 0xaabbccee


class ScanError(Exception):
	def __init__(self, code, detail=""):
		super().__init__("%s: %s" % (code, detail))
		self.code = code
		self.detail = detail


# ---------------------------------------------------------------------------
# LoxCC entpacken
# ---------------------------------------------------------------------------
def unpack_loxcc(raw: bytes) -> bytes:
	"""Entpackt einen LoxCC-Container (Magic 0xaabbccee, LZ4-ähnlich).

	Gleiches Verfahren wie unpack_loxcc.py aus Stats4Lox-NG. Nicht überlappende
	Rückverweise werden als ein Stück kopiert, überlappende byteweise - das
	Ergebnis ist identisch, auf dem Pi aber deutlich schneller."""
	if len(raw) < 16:
		raise ScanError("unpack", "file too short")
	header, csize, usize, checksum = struct.unpack_from("<LLLL", raw, 0)
	if header != LOXCC_MAGIC:
		raise ScanError("unpack", "no LoxCC header")

	data = raw[16:16 + csize]
	n = len(data)
	i = 0
	out = bytearray()
	try:
		while i < n:
			byte = data[i]
			i += 1
			copy = byte >> 4
			byte &= 0xf
			if copy == 15:
				while True:
					add = data[i]
					copy += add
					i += 1
					if add != 0xff:
						break
			if copy:
				out += data[i:i + copy]
				i += copy
			if i >= n:
				break

			back = data[i] | (data[i + 1] << 8)
			i += 2
			count = 4 + byte
			if byte == 15:
				while True:
					val = data[i]
					count += val
					i += 1
					if val != 0xff:
						break
			if back == 0 or back > len(out):
				raise ScanError("unpack", "invalid back reference")
			start = len(out) - back
			if back >= count:
				out += out[start:start + count]
			else:
				for k in range(count):
					out.append(out[start + k])
	except IndexError:
		raise ScanError("unpack", "truncated data")

	if zlib.crc32(out) != checksum:
		raise ScanError("unpack", "checksum mismatch")
	if len(out) != usize:
		raise ScanError("unpack", "size mismatch %d != %d" % (len(out), usize))
	return bytes(out)


def extract_project(filename: str, blob: bytes) -> bytes:
	"""Liefert das Projekt-XML aus einer sps_*.zip oder sps_*.LoxCC."""
	if filename.lower().endswith(".loxcc"):
		return unpack_loxcc(blob)
	try:
		zf = zipfile.ZipFile(io.BytesIO(blob))
	except zipfile.BadZipFile:
		raise ScanError("unpack", "not a zip file")
	names = zf.namelist()
	for suffix in (".loxone", ".loxcc"):
		members = [m for m in names if m.lower().endswith(suffix)]
		members.sort(key=lambda m: 0 if os.path.basename(m).lower().startswith("sps0") else 1)
		if members:
			content = zf.read(members[0])
			return content if suffix == ".loxone" else unpack_loxcc(content)
	raise ScanError("unpack", "no project in zip")


# ---------------------------------------------------------------------------
# Projekt-XML auswerten
# ---------------------------------------------------------------------------
_C_TAG = re.compile(rb"<C\s[^>]*>")
_ATTR = re.compile(rb'([^\s=/>]+)\s*=\s*"[^"]*"')


def remove_duplicate_attributes(xml: bytes) -> bytes:
	"""Loxone schreibt manchmal doppelte Attribute in <C>-Elemente. Das ist
	ungültiges XML; das erste Vorkommen bleibt stehen (wie in Stats4Lox-NG)."""
	def fix_tag(match):
		seen = set()

		def keep_first(attr):
			name = attr.group(1)
			if name in seen:
				return b""
			seen.add(name)
			return attr.group(0)

		return _ATTR.sub(keep_first, match.group(0))

	return _C_TAG.sub(fix_tag, xml)


def _iter_project(xml: bytes, recover: bool):
	from lxml import etree

	lives = {}
	inputs = []
	stack = []   # (Type, U, Ref) aller offenen Elemente
	for event, elem in etree.iterparse(io.BytesIO(xml), events=("start", "end"),
	                                   huge_tree=True, recover=recover):
		if event == "start":
			ctype = elem.get("Type")
			if ctype == "LoxLIVE":
				lives[elem.get("U")] = {
					"title": elem.get("Title") or "",
					"intaddr": elem.get("IntAddr") or "",
					"serial": elem.get("Serial") or "",
				}
			elif ctype in INPUT_TYPES:
				title = elem.get("Title") or ""
				if title:
					inputs.append((title, ctype, _ms_ref(stack)))
			stack.append((ctype, elem.get("U"), elem.get("Ref")))
		else:
			stack.pop()
			elem.clear()
	return lives, inputs


def _ms_ref(stack):
	"""Miniserver eines Elements, wie ParseXML.pm: nach oben laufen, bis ein
	Element eine Ref hat, keinen Type hat oder selbst LoxLIVE ist."""
	for ctype, uid, ref in reversed(stack):
		if not ref and ctype is not None and ctype != "LoxLIVE":
			continue
		if ctype == "LoxLIVE":
			return uid
		return ref
	return None


def parse_project(xml: bytes):
	"""Liefert (lives, inputs). lives: {U: {title, intaddr, serial}},
	inputs: [(title, type, ms_ref)]."""
	from lxml import etree

	if xml.startswith(b"\xef\xbb\xbf"):
		xml = xml[3:]
	try:
		return _iter_project(xml, recover=False)
	except etree.XMLSyntaxError:
		pass
	fixed = remove_duplicate_attributes(xml)
	try:
		return _iter_project(fixed, recover=False)
	except etree.XMLSyntaxError:
		pass
	try:
		lives, inputs = _iter_project(fixed, recover=True)
	except etree.XMLSyntaxError as exc:
		raise ScanError("xml", str(exc))
	if not lives:
		# Recover-Modus ohne einen einzigen Miniserver ist unbrauchbar
		raise ScanError("xml", "no Miniserver in project")
	return lives, inputs


# ---------------------------------------------------------------------------
# Zuordnung LoxLIVE -> LoxBerry-Miniserver
# ---------------------------------------------------------------------------
def _host_of(intaddr: str) -> str:
	host = intaddr.strip()
	if host.startswith("["):
		return host[1:host.find("]")] if "]" in host else host[1:]
	if host.count(":") == 1:
		host = host.split(":", 1)[0]
	return host


def _resolve(host: str):
	try:
		return socket.gethostbyname(host)
	except (OSError, UnicodeError):
		return None


def match_lives(lives: dict, miniservers: dict, resolve=_resolve) -> dict:
	"""{U: msnr} über Host, danach über die aufgelöste IP (wie ParseXML.pm)."""
	result = {}
	for uid, live in lives.items():
		host = _host_of(live["intaddr"]).lower()
		if not host:
			continue
		for msnr, ms in miniservers.items():
			if str(ms.get("IPAddress") or "").lower() == host:
				result[uid] = msnr
				break
		else:
			ip = resolve(host)
			if not ip:
				continue
			for msnr, ms in miniservers.items():
				msip = str(ms.get("IPAddress") or "")
				if msip == ip or resolve(msip) == ip:
					result[uid] = msnr
					break
	return result


def assign_inputs(lives, inputs, miniservers, source_msnr, resolve=_resolve):
	"""{msnr: [{name, type}]} - Eingänge ohne zuordenbaren Miniserver landen beim
	Miniserver, von dem die Datei stammt, wenn das Projekt nur einen enthält."""
	live_to_ms = match_lives(lives, miniservers, resolve)
	single = len(lives) == 1
	by_ms = {}
	seen = set()
	for title, ctype, ref in inputs:
		msnr = live_to_ms.get(ref)
		if msnr is None and single:
			msnr = source_msnr
		if msnr is None:
			continue
		key = (msnr, title)
		if key in seen:
			continue
		seen.add(key)
		by_ms.setdefault(msnr, []).append({"name": title, "type": ctype})
	by_ms.setdefault(source_msnr, [])
	for lst in by_ms.values():
		lst.sort(key=lambda x: x["name"].lower())
	return by_ms


# ---------------------------------------------------------------------------
# Miniserver-Zugriff
# ---------------------------------------------------------------------------
def pick_program_file(listing: str):
	"""Neueste sps_*.zip/.LoxCC aus der Ausgabe von /dev/fslist/prog/."""
	files = []
	for line in listing.splitlines():
		parts = line.split()
		if len(parts) < 2 or parts[0] != "-":
			continue
		name = parts[-1]
		low = name.lower()
		if not low.startswith("sps_") or low.startswith("sps_old"):
			continue
		if not (low.endswith(".zip") or low.endswith(".loxcc")):
			continue
		files.append(name)
	if not files:
		return None
	files.sort(key=str.lower, reverse=True)
	return files[0]


class MiniserverClient:
	def __init__(self, ms: dict):
		host = str(ms.get("IPAddress") or "")
		if ":" in host and not host.startswith("["):
			host = "[" + host + "]"
		transport = ms.get("Transport") or "http"
		port = ms.get("PortHttps") if transport == "https" else ms.get("Port")
		self.base = "%s://%s:%s" % (transport, host, port)
		raw = "%s:%s" % (ms.get("Admin_RAW") or ms.get("Admin") or "",
		                 ms.get("Pass_RAW") or ms.get("Pass") or "")
		self.auth = "Basic " + base64.b64encode(raw.encode("utf-8")).decode("ascii")
		self.ctx = ssl.create_default_context()
		self.ctx.check_hostname = False
		self.ctx.verify_mode = ssl.CERT_NONE

	def get(self, command: str, timeout: int) -> bytes:
		req = urllib.request.Request(self.base + command)
		req.add_header("Authorization", self.auth)
		try:
			with urllib.request.urlopen(req, timeout=timeout, context=self.ctx) as resp:
				return resp.read()
		except urllib.error.HTTPError as exc:
			if exc.code in (401, 403):
				raise ScanError("denied", "HTTP %s on %s" % (exc.code, command.split("?")[0]))
			raise ScanError("http", "HTTP %s on %s" % (exc.code, command.split("?")[0]))
		except (urllib.error.URLError, OSError) as exc:
			raise ScanError("unreachable", str(getattr(exc, "reason", exc)))


def load_inputs_from_ms(msnr, miniservers, client):
	"""Lädt und wertet die Programmdatei eines Miniservers aus -> {msnr: [inputs]}."""
	listing = client.get("/dev/fslist/prog/", TIMEOUT_SHORT).decode("utf-8", "replace")
	filename = pick_program_file(listing)
	if not filename:
		raise ScanError("nofile")
	blob = client.get("/dev/fsget/prog/" + urllib.parse.quote(filename), TIMEOUT_DOWNLOAD)
	xml = extract_project(filename, blob)
	del blob
	lives, inputs = parse_project(xml)
	return assign_inputs(lives, inputs, miniservers, msnr)


# ---------------------------------------------------------------------------
# Scan
# ---------------------------------------------------------------------------
def token_auth_enabled(msnr) -> bool:
	cfgdir = os.environ.get("LBSCONFIG") or os.path.join(
		os.environ.get("LBHOMEDIR", "/opt/loxberry"), "config", "system")
	try:
		with open(os.path.join(cfgdir, "general.json"), "r", encoding="utf-8") as fh:
			cfg = json.load(fh)
		val = cfg.get("Miniserver", {}).get(str(msnr), {}).get("Authmethod")
		return str(val or "").lower() == "token"
	except (OSError, ValueError, AttributeError):
		return False


def scan(miniservers: dict, only=None, client_factory=MiniserverClient,
         token_check=token_auth_enabled):
	result = {}
	covered = {}
	for msnr in sorted(miniservers, key=lambda k: (len(str(k)), str(k))):
		if only and msnr not in only:
			continue
		ms = miniservers[msnr]
		entry = {"name": ms.get("Name") or "", "ok": False, "error": None,
		         "detail": None, "source": None, "inputs": []}
		result[msnr] = entry

		if msnr in covered:
			entry.update(ok=True, source="project:%s" % covered[msnr][0],
			             inputs=covered[msnr][1])
			continue
		if token_check(msnr):
			entry["error"] = "auth_token"
			continue

		try:
			by_ms = load_inputs_from_ms(msnr, miniservers, client_factory(ms))
		except ScanError as exc:
			entry.update(error=exc.code, detail=exc.detail or None)
			continue

		entry.update(ok=True, source="download", inputs=by_ms.get(msnr, []))
		for other, inputs in by_ms.items():
			if other != msnr and other in miniservers and other not in covered:
				covered[other] = (msnr, inputs)
	return {"miniservers": result}


def _load_miniservers():
	try:
		from loxberry import system as lbsystem
	except ImportError:
		sys.path.insert(0, os.path.join(os.environ.get("LBHOMEDIR", "/opt/loxberry"),
		                                "libs", "pythonlib"))
		from loxberry import system as lbsystem
	return {str(k): v for k, v in (lbsystem.get_miniservers() or {}).items()}


def main(argv=None):
	parser = argparse.ArgumentParser(description="Virtuelle Eingänge aus der Programmdatei der Miniserver lesen")
	parser.add_argument("--ms", default="", help="nur diese Miniserver, z. B. 1,2")
	parser.add_argument("--pretty", action="store_true", help="JSON eingerückt ausgeben")
	args = parser.parse_args(argv)

	try:
		import lxml  # noqa: F401
		miniservers = _load_miniservers()
		only = set(x.strip() for x in args.ms.split(",") if x.strip()) or None
		out = scan(miniservers, only=only)
		rc = 0
	except Exception as exc:  # letzte Verteidigung: die WebUI bekommt immer JSON
		out = {"miniservers": {}, "error": "internal", "detail": str(exc)}
		rc = 1
	json.dump(out, sys.stdout, ensure_ascii=False, indent=1 if args.pretty else None)
	sys.stdout.write("\n")
	return rc


if __name__ == "__main__":
	sys.exit(main())
