#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
testmqttscan_parse.py - Offline-Test für bin/mqtt-scan-miniserver.py.

Braucht keinen Miniserver: LoxCC-Container, ZIP-Dateien, Projekt-XML und
Miniserver-Antworten werden im Test erzeugt.

  - unpack_loxcc: gegen eine wörtliche Kopie des Algorithmus aus
    Stats4Lox-NG (unpack_loxcc.py) mit vielen erzeugten Containern
  - extract_project: zip mit sps0.Loxone, zip mit sps0.LoxCC, direkte .LoxCC
  - parse_project: BOM, doppelte Attribute, Ref-Verweise, zwei Miniserver,
    VirtualTextIn, Eingänge außerhalb eines Miniservers
  - assign_inputs / pick_program_file / scan (Cache, Projekt-Doppelung,
    Token-Anmeldung, Fehlercodes)

Aufruf: python3 libs/pythonlib/testing/testmqttscan_parse.py
"""

import importlib.util
import io
import json
import os
import random
import struct
import sys
import tempfile
import zipfile
import zlib

HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPT = os.path.join(HERE, "..", "..", "..", "bin", "mqtt-scan-miniserver.py")
spec = importlib.util.spec_from_file_location("mqttscan", SCRIPT)
scanmod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(scanmod)

failures = 0


def check(name, cond, info=""):
	global failures
	if cond:
		print("OK    %s" % name)
	else:
		failures += 1
		print("FAIL  %s %s" % (name, info))


# ---------------------------------------------------------------------------
# LoxCC: Encoder + Referenz-Decoder
# ---------------------------------------------------------------------------
def _ext(rem):
	out = bytearray()
	while rem >= 255:
		out.append(0xff)
		rem -= 255
	out.append(rem)
	return out


def encode_tokens(tokens):
	"""tokens: [(literal_bytes, back, count)] - back/count None beim letzten Token."""
	data = bytearray()
	for lit, back, count in tokens:
		hi = min(len(lit), 15)
		low = 0 if back is None else min(count - 4, 15)
		data.append((hi << 4) | low)
		if hi == 15:
			data += _ext(len(lit) - 15)
		data += lit
		if back is not None:
			data += struct.pack("<H", back)
			if count - 4 >= 15:
				data += _ext(count - 4 - 15)
	return bytes(data)


def container(payload_tokens, plain):
	data = encode_tokens(payload_tokens)
	return struct.pack("<LLLL", 0xaabbccee, len(data), len(plain), zlib.crc32(plain)) + data


def reference_unpack(raw):
	"""Wörtlich nach unpack_loxcc.py aus Stats4Lox-NG (Sarnau)."""
	header, = struct.unpack('<L', raw[0:4])
	assert header == 0xaabbccee
	compressedSize, uncompressedSize, checksum, = struct.unpack('<LLL', raw[4:16])
	data = raw[16:16 + compressedSize]
	index = 0
	resultStr = bytearray()
	while index < len(data):
		byte, = struct.unpack('<B', data[index:index + 1])
		index += 1
		copyBytes = byte >> 4
		byte &= 0xf
		if copyBytes == 15:
			while True:
				addByte = data[index]
				copyBytes += addByte
				index += 1
				if addByte != 0xff:
					break
		if copyBytes > 0:
			resultStr += data[index:index + copyBytes]
			index += copyBytes
		if index >= len(data):
			break
		bytesBack, = struct.unpack('<H', data[index:index + 2])
		index += 2
		bytesBackCopied = 4 + byte
		if byte == 15:
			while True:
				val, = struct.unpack('<B', data[index:index + 1])
				bytesBackCopied += val
				index += 1
				if val != 0xff:
					break
		while bytesBackCopied > 0:
			if -bytesBack + 1 == 0:
				resultStr += resultStr[-bytesBack:]
			else:
				resultStr += resultStr[-bytesBack:-bytesBack + 1]
			bytesBackCopied -= 1
	return bytes(resultStr)


def random_stream(rng):
	"""Erzeugt gültige Tokens und den erwarteten Klartext."""
	plain = bytearray()
	tokens = []
	for _ in range(rng.randint(1, 60)):
		lit = bytes(rng.randrange(256) for _ in range(rng.choice([0, 1, 3, 14, 15, 16, 40, 270, 300])))
		plain += lit
		if not plain:
			lit = b"x"
			plain += lit
		back = rng.randint(1, min(len(plain), 65535))
		count = rng.choice([4, 5, 18, 19, 20, 100, 274, 600])
		for k in range(count):
			plain.append(plain[len(plain) - back])
		tokens.append((lit, back, count))
	last = bytes(rng.randrange(256) for _ in range(rng.choice([0, 7, 15, 290])))
	plain += last
	tokens.append((last, None, None))
	return tokens, bytes(plain)


# Hand-Fälle
plain = b"abcdabcd"
raw = container([(b"abcd", 4, 4), (b"", None, None)], plain)
check("loxcc: nicht überlappender Rückverweis", scanmod.unpack_loxcc(raw) == plain)

plain = b"ab" + b"b" * 6
raw = container([(b"ab", 1, 6), (b"", None, None)], plain)
check("loxcc: überlappender Rückverweis (letztes Byte vervielfacht)", scanmod.unpack_loxcc(raw) == plain)

lit = bytes(range(256)) * 2
raw = container([(lit, None, None)], lit)
check("loxcc: langes Literal mit 0xff-Verlängerung", scanmod.unpack_loxcc(raw) == lit)

# Zufällige Container gegen den Referenz-Decoder
rng = random.Random(4711)
same = True
for n in range(300):
	tokens, plain = random_stream(rng)
	raw = container(tokens, plain)
	ref = reference_unpack(raw)
	got = scanmod.unpack_loxcc(raw)
	if not (ref == plain == got):
		same = False
		print("      Abweichung in Container %d (len %d)" % (n, len(plain)))
		break
check("loxcc: 300 erzeugte Container identisch mit Stats4Lox-Algorithmus", same)

bad = bytearray(container([(b"abcd", 4, 4), (b"", None, None)], b"abcdabcd"))
bad[12] ^= 0xff   # Prüfsumme verfälschen
try:
	scanmod.unpack_loxcc(bytes(bad))
	check("loxcc: falsche Prüfsumme wird erkannt", False)
except scanmod.ScanError as exc:
	check("loxcc: falsche Prüfsumme wird erkannt", exc.code == "unpack")

try:
	scanmod.unpack_loxcc(container([(b"abcd", 4, 4), (b"", None, None)], b"abcdabcd")[:-3])
	check("loxcc: abgeschnittene Datei wird erkannt", False)
except scanmod.ScanError as exc:
	check("loxcc: abgeschnittene Datei wird erkannt", exc.code == "unpack")

# ---------------------------------------------------------------------------
# Projekt-XML
# ---------------------------------------------------------------------------
PROJECT = (
	'﻿<?xml version="1.0" encoding="utf-8"?>\n'
	'<ControlList Version="1">\n'
	' <C Type="Document" V="1" Title="Test"/>\n'
	' <C Type="LoxLIVE" U="ms-haus" Title="Haus" IntAddr="192.168.1.77" Serial="504F94A00001">\n'
	'  <C Type="VirtualInCaption" U="vic1" Title="Virtuelle Eingänge">\n'
	'   <C Type="VirtualIn" U="vi1" Title="w4l_cur_tt" Desc="x" Desc="doppelt"><IoData Pr="r1"/></C>\n'
	'   <C Type="VirtualIn" U="vi2" Title="z2m_Kueche_Bewegung_occupancy"/>\n'
	'   <C Type="VirtualTextIn" U="vti1" Title="tesla_Model3_state_text"/>\n'
	'   <C Type="VirtualIn" U="vi3" Title=""/>\n'
	'  </C>\n'
	' </C>\n'
	' <C Type="LoxLIVE" U="ms-garage" Title="Garage" IntAddr="garage.local:8080">\n'
	'  <C Type="VirtualIn" U="vi4" Title="easee_charger_totalPower"/>\n'
	' </C>\n'
	' <C Type="Page" U="p1" Title="Seite">\n'
	'  <C Type="Ref" U="r2" Ref="ms-garage">\n'
	'   <C Type="VirtualIn" U="vi5" Title="evcc_loadpoints_1_chargePower"/>\n'
	'  </C>\n'
	'  <C Type="VirtualIn" U="vi6" Title="ohne_miniserver"/>\n'
	' </C>\n'
	'</ControlList>\n'
).encode("utf-8")

lives, inputs = scanmod.parse_project(PROJECT)
check("xml: BOM und doppelte Attribute werden verkraftet", len(lives) == 2, repr(lives))
titles = dict((t, (ty, ref)) for t, ty, ref in inputs)
check("xml: leere Titel werden übersprungen", "" not in titles)
check("xml: VirtualIn unter LoxLIVE", titles.get("w4l_cur_tt") == ("VirtualIn", "ms-haus"), repr(titles.get("w4l_cur_tt")))
check("xml: VirtualTextIn erkannt", titles.get("tesla_Model3_state_text") == ("VirtualTextIn", "ms-haus"))
check("xml: Zuordnung über Ref", titles.get("evcc_loadpoints_1_chargePower") == ("VirtualIn", "ms-garage"))
check("xml: Eingang außerhalb eines Miniservers ohne Zuordnung", titles.get("ohne_miniserver") == ("VirtualIn", None))

MINISERVERS = {
	"1": {"Name": "Haus", "IPAddress": "192.168.1.77", "Port": 80, "Transport": "http"},
	"2": {"Name": "Garage", "IPAddress": "192.168.1.78", "Port": 80, "Transport": "http"},
}
fake_dns = {"garage.local": "192.168.1.78", "192.168.1.78": "192.168.1.78", "192.168.1.77": "192.168.1.77"}
resolve = lambda host: fake_dns.get(host)

by_ms = scanmod.assign_inputs(lives, inputs, MINISERVERS, "1", resolve=resolve)
check("assign: MS 1 bekommt seine drei Eingänge",
      [x["name"] for x in by_ms.get("1", [])] == ["tesla_Model3_state_text", "w4l_cur_tt", "z2m_Kueche_Bewegung_occupancy"],
      repr(by_ms.get("1")))
check("assign: MS 2 über Hostname mit Port + Ref",
      [x["name"] for x in by_ms.get("2", [])] == ["easee_charger_totalPower", "evcc_loadpoints_1_chargePower"],
      repr(by_ms.get("2")))

single = scanmod.parse_project(b'<L><C Type="LoxLIVE" U="a" IntAddr="10.0.0.9"/><C Type="VirtualIn" Title="lose"/></L>')
by_single = scanmod.assign_inputs(single[0], single[1], MINISERVERS, "2", resolve=resolve)
check("assign: bei nur einem Miniserver im Projekt fällt der Eingang auf die Quelle",
      [x["name"] for x in by_single.get("2", [])] == ["lose"], repr(by_single))

# Rückmeldung Jan W. (14.09.2026): "Virtueller HTTP Eingang Befehl" nimmt Werte über
# /dev/sps/io/<Name> an (Datenverkehr zeigt HTTP 200), wurde vom Scan aber übersehen.
# Typnamen wie in einer echten Programmdatei: VirtualHttpIn -> VirtualHttpInCmd.
# VirtualUdpInCmd wird über die Befehlserkennung angesprochen und bleibt außen vor.
HTTPCMD = (
	b'<ControlList><C Type="LoxLIVE" U="ms" Title="Home" IntAddr="192.168.1.77">'
	b'<C Type="VirtualInCaption" U="c" Title="Virtuelle Eingaenge">'
	b'<C Type="VirtualHttpIn" U="h" Title="easee MQTT Inputs">'
	b'<C Type="VirtualHttpInCmd" U="h1" Title="easee_EHVVL69G_cableLocked"/>'
	b'<C Type="VirtualHttpInCmd" U="h2" Title="easee_EHVVL69G_isOnline"/>'
	b'</C>'
	b'<C Type="VirtualUdpIn" U="u" Title="ekey"><C Type="VirtualUdpInCmd" U="u1" Title="ekey_finger"/></C>'
	b'</C></C></ControlList>'
)
hc_lives, hc_inputs = scanmod.parse_project(HTTPCMD)
hc_titles = dict((t, ty) for t, ty, ref in hc_inputs)
check("xml: Virtueller HTTP Eingang Befehl wird erkannt",
      hc_titles.get("easee_EHVVL69G_cableLocked") == "VirtualHttpInCmd" and hc_titles.get("easee_EHVVL69G_isOnline") == "VirtualHttpInCmd",
      repr(hc_titles))
check("xml: HTTP-Eingang selbst (Container) und UDP-Befehle nicht als Eingang",
      "easee MQTT Inputs" not in hc_titles and "ekey_finger" not in hc_titles, repr(hc_titles))

# ---------------------------------------------------------------------------
# ZIP / LoxCC-Datei
# ---------------------------------------------------------------------------
def make_zip(name, content):
	buf = io.BytesIO()
	with zipfile.ZipFile(buf, "w") as zf:
		zf.writestr("readme.txt", "x")
		zf.writestr(name, content)
	return buf.getvalue()

loxcc = container([(PROJECT, None, None)], PROJECT)
check("extract: zip mit sps0.Loxone", scanmod.extract_project("sps_1.zip", make_zip("sps0.Loxone", PROJECT)) == PROJECT)
check("extract: zip mit sps0.LoxCC", scanmod.extract_project("sps_1.zip", make_zip("sps0.LoxCC", loxcc)) == PROJECT)
check("extract: direkte .LoxCC", scanmod.extract_project("sps_1.LoxCC", loxcc) == PROJECT)

LISTING = (
	"d 0 Sep 01 10:00 old\n"
	"- 123 Sep 01 10:00 sps_old_0001.zip\n"
	"- 456 Sep 10 10:00 sps_0141_20260910100000.zip\n"
	"- 789 Sep 11 09:30 sps_0142_20260911093000.zip\n"
	"- 100 Sep 11 09:30 notes.txt\n"
)
check("fslist: neueste Programmdatei", scanmod.pick_program_file(LISTING) == "sps_0142_20260911093000.zip")
check("fslist: keine Programmdatei", scanmod.pick_program_file("- 1 Sep 1 1:00 x.txt\n") is None)

# ---------------------------------------------------------------------------
# scan() mit falschem Miniserver
# ---------------------------------------------------------------------------
downloads = []


class FakeClient:
	def __init__(self, ms):
		self.ms = ms

	def get(self, command, timeout):
		if self.ms["Name"] == "Gesperrt":
			raise scanmod.ScanError("denied", "HTTP 401")
		if command == "/jdev/sps/LoxAPPversion3":
			return json.dumps({"LL": {"value": "2026-09-11 09:30:00"}}).encode()
		if command == "/dev/fslist/prog/":
			return LISTING.encode()
		if command.startswith("/dev/fsget/prog/"):
			downloads.append(self.ms["Name"])
			return make_zip("sps0.LoxCC", loxcc)
		raise AssertionError(command)


orig_resolve = scanmod._resolve
scanmod._resolve = resolve
scanmod.match_lives.__defaults__ = (resolve,)
scanmod.assign_inputs.__defaults__ = (resolve,)

ms3 = dict(MINISERVERS)
ms3["3"] = {"Name": "Gesperrt", "IPAddress": "192.168.1.79", "Port": 80}
ms3["4"] = {"Name": "Token", "IPAddress": "192.168.1.80", "Port": 80}
token = lambda msnr: msnr == "4"

tmp_before = set(os.listdir(tempfile.gettempdir()))
out = scanmod.scan(ms3, client_factory=FakeClient, token_check=token)["miniservers"]
check("scan: MS 1 aus Download", out["1"]["ok"] and out["1"]["source"] == "download", repr(out["1"]))
check("scan: MS 2 aus demselben Projekt, ohne zweiten Download",
      out["2"]["ok"] and out["2"]["source"] == "project:1" and downloads == ["Haus"], repr((out["2"], downloads)))
check("scan: Zugriff verweigert -> denied", not out["3"]["ok"] and out["3"]["error"] == "denied")
check("scan: Token-Anmeldung -> auth_token", not out["4"]["ok"] and out["4"]["error"] == "auth_token")

out = scanmod.scan(MINISERVERS, client_factory=FakeClient, token_check=lambda m: False)["miniservers"]
check("scan: kein Cache - zweiter Lauf lädt neu", out["1"]["source"] == "download" and downloads == ["Haus", "Haus"], repr(downloads))
check("scan: schreibt nichts ins Temp-Verzeichnis", set(os.listdir(tempfile.gettempdir())) == tmp_before)
check("scan: keine Cache-Reste im Modul", not hasattr(scanmod, "CACHE_DIR") and not hasattr(scanmod, "cache_read"))

print(json.dumps(out["1"], ensure_ascii=False))

scanmod._resolve = orig_resolve

print("")
if failures:
	print("%d Test(s) FEHLGESCHLAGEN" % failures)
	sys.exit(1)
print("Alle Tests OK")
