# -*- coding: utf-8 -*-
"""
loxberry.io - Python port of the Perl master library LoxBerry::IO.

Communication with the Loxone Miniserver (HTTP/UDP) and with the LoxBerry MQTT
broker.

  HTTP : mshttp_call, mshttp_call2, mshttp_get, mshttp_send, mshttp_send_mem
  UDP  : msudp_send, msudp_send_mem
  MQTT : mqtt_connectiondetails, mqtt_connect, mqtt_set, mqtt_retain,
         mqtt_publish, mqtt_get

HTTP uses requests (Loxone self-signed certificate accepted). MQTT uses
paho-mqtt (install with python3-paho-mqtt; the LoxBerry update script does
this). UDP uses plain sockets. The parameter lists that are key/value pairs in
Perl are passed as a dict in Python (Loxone names may contain spaces/special
characters, so they cannot be keyword arguments).
"""

from __future__ import annotations

import json as _json
import os
import re
import socket
import time as _time
import urllib.parse

from . import system

__version__ = "3.0.0.1"

UDP_DELIMITER = "="
MEM_SENDALL_SEC = 3600

_udpsockets = {}     # {(msnr, udpport): socket}
_mqtt_client = None   # module-global MQTT client (like Perl $mqtt)


def _ms(msnr):
    ms = system.get_miniservers()
    return ms.get(msnr) or ms.get(str(msnr))


# ---------------------------------------------------------------------------
# HTTP
# ---------------------------------------------------------------------------
def mshttp_call(msnr, command):
    """Miniserver REST call. Returns (value, code, raw_response)."""
    ms = _ms(msnr)
    if ms is None:
        return (None, 601, None)
    url = ms["FullURI"] + command
    try:
        import requests
        import urllib3
        urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
        resp = requests.get(url, timeout=1, verify=False)
    except Exception:
        return (None, None, None)
    if resp.status_code < 200 or resp.status_code >= 300:
        return (None, resp.status_code, None)
    raw = resp.text
    mv = re.search(r'value="(.*?)"', raw)
    mc = re.search(r'Code="(.*?)"', raw)
    return (mv.group(1) if mv else None, mc.group(1) if mc else None, raw)


def mshttp_call2(msnr, command, timeout=5, ssl_verify_mode=0,
                 ssl_verify_hostname=0, filename=None):
    """Miniserver REST call with options. Returns (content, responseinfo dict)."""
    info = {}
    ms = _ms(msnr)
    if ms is None:
        info.update(code=601, error=1,
                    message="Miniserver %s not found or configuration not finished" % msnr)
        return (None, info)
    url = ms["FullURI"] + command
    try:
        import requests
        import urllib3
        urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
        resp = requests.get(url, timeout=timeout, verify=bool(ssl_verify_mode))
    except Exception as exc:
        info.update(code=None, error=1, message="Request failed: %s" % exc)
        return (None, info)

    info["code"] = resp.status_code
    info["status"] = "%s %s" % (resp.status_code, resp.reason)
    if resp.status_code < 200 or resp.status_code >= 300:
        info["error"] = 1
        info["message"] = "%s FAILED - Error %s: %s" % (command, resp.status_code, resp.reason)
        return (None, info)

    # error=0 on success (PHP-style bugfix; the Perl master leaves it 1)
    info["error"] = 0
    info["message"] = "Request ok"
    content = resp.text
    if filename is not None:
        try:
            with open(filename, "w", encoding="utf-8") as fh:
                fh.write(content)
            info["filename"] = filename
        except OSError as exc:
            info["error"] = 1
            info["message"] = "Could not write file %s: %s" % (filename, exc)
    return (content, info)


def mshttp_get(msnr, *params):
    """Query one or more Miniserver inputs/outputs by name.

    Returns a dict {name: value} for multiple names, or the single value for
    one name.
    """
    response = {}
    for name in params:
        esc = urllib.parse.quote(name, safe="")
        value, code, raw = mshttp_call(msnr, "/dev/sps/io/%s/all" % esc)
        if str(code) == "200":
            m = re.search(r"(\d+(?:\.\d+)?)", value or "")
            filtered = m.group(1) if m else ""
            # Workaround: analogue outputs may report 0 via /all
            if filtered != "" and float(filtered) == 0:
                if raw is None or '<output name="' not in raw:
                    value, code, raw = mshttp_call(msnr, "/dev/sps/io/%s" % esc)
            response[name] = value
        else:
            response[name] = None
    if len(params) > 1:
        return response
    if len(params) == 1:
        return response[params[0]]
    return response


def mshttp_send(msnr, params):
    """Send values to Miniserver inputs. params is a dict {name: value}.

    Returns {name: True/None} for multiple, or the single result for one.
    """
    response = {}
    for name, value in params.items():
        esc_n = urllib.parse.quote(str(name), safe="")
        esc_v = urllib.parse.quote(str(value), safe="")
        _v, code, _raw = mshttp_call(msnr, "/dev/sps/io/%s/%s" % (esc_n, esc_v))
        response[name] = True if str(code) == "200" else None
    if len(params) > 1:
        return response
    if len(params) == 1:
        return response[next(iter(params))]
    return response


def mshttp_send_mem(msnr, params):
    """Like mshttp_send, but only sends values that changed since last call."""
    if not msnr:
        return None
    from .json import LoxBerryJSON
    memfile = "/run/shm/mshttp_mem_%s.json" % msnr
    memobj = LoxBerryJSON()
    mem = memobj.open(filename=memfile, writeonclose=True)

    sendall = False
    main = mem.setdefault("Main", {})
    if not main.get("timestamp"):
        main["timestamp"] = int(_time.time())
        sendall = True
    if main["timestamp"] < _time.time() - MEM_SENDALL_SEC:
        sendall = True
        main["timestamp"] = int(_time.time())

    # Detect Miniserver reboot via /dev/lan/txp
    if not main.get("lastMSRebootCheck") or main["lastMSRebootCheck"] < _time.time() - 300:
        main["lastMSRebootCheck"] = int(_time.time())
        lasttxp = main.get("MSTXP")
        newtxp, code, _raw = mshttp_call(msnr, "/dev/lan/txp")
        if str(code) == "200":
            main["MSTXP"] = newtxp
            try:
                if lasttxp is not None and float(newtxp) < float(lasttxp):
                    sendall = True
            except (TypeError, ValueError):
                pass

    if sendall:
        for k in list(mem.keys()):
            if k != "Main":
                del mem[k]

    newparams = {}
    for name, value in params.items():
        if str(mem.get(name)) != str(value) or sendall:
            newparams[name] = value
            mem[name] = value

    memobj.write()
    if newparams:
        return mshttp_send(msnr, newparams)
    return True


# ---------------------------------------------------------------------------
# UDP
# ---------------------------------------------------------------------------
def msudp_send(msnr, udpport, prefix, params):
    """Send values to the Miniserver via UDP. params is a dict {name: value}."""
    ms = _ms(msnr)
    if not udpport or int(udpport) > 65535:
        return None
    if ms is None:
        return None
    prefix = "%s: " % prefix if prefix else ""

    key = (str(msnr), int(udpport))
    sock = _udpsockets.get(key)
    if sock is None:
        try:
            sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        except OSError:
            return None
        _udpsockets[key] = sock
    addr = (ms["IPAddress"], int(udpport))

    # Build datagrams up to ~220 chars; the prefix goes on the first pair of
    # each datagram (like the Perl master).
    line = ""
    for name, value in params.items():
        pair = "%s%s%s " % (name, UDP_DELIMITER, value)
        if line == "":
            candidate = prefix + pair
            if len(candidate) > 220:
                # single pair already too long -> skip it
                continue
            line = candidate
        else:
            candidate = line + pair
            if len(candidate) > 220:
                try:
                    sock.sendto(line.encode("utf-8"), addr)
                except OSError:
                    return None
                line = prefix + pair
            else:
                line = candidate
    if line:
        try:
            sock.sendto(line.encode("utf-8"), addr)
        except OSError:
            return None
    return 1


def msudp_send_mem(msnr, udpport, prefix, params):
    """Like msudp_send, but only sends values that changed since last call."""
    if not udpport or int(udpport) > 65535:
        return None
    if not msnr:
        return None
    from .json import LoxBerryJSON
    memfile = "/run/shm/msudp_mem_%s_%s.json" % (msnr, udpport)
    memobj = LoxBerryJSON()
    mem = memobj.open(filename=memfile, writeonclose=True)
    section = prefix if prefix else "Params"

    main = mem.setdefault("Main", {})
    sendall = False
    if not main.get("timestamp"):
        main["timestamp"] = int(_time.time())
        sendall = True
    if main["timestamp"] < _time.time() - MEM_SENDALL_SEC:
        sendall = True
        main["timestamp"] = int(_time.time())

    sect = mem.setdefault(section, {})
    newparams = {}
    for name, value in params.items():
        if str(sect.get(name)) != str(value) or sendall:
            newparams[name] = value
            sect[name] = value

    memobj.write()
    if newparams:
        return msudp_send(msnr, udpport, prefix, newparams)
    return 1


# ---------------------------------------------------------------------------
# MQTT
# ---------------------------------------------------------------------------
def mqtt_connectiondetails():
    """Return a dict with the MQTT broker connection details from general.json."""
    raw = system.read_file("%s/general.json" % system.lbsconfigdir)
    cfg = {}
    if raw:
        try:
            cfg = _json.loads(raw)
        except ValueError:
            cfg = {}
    m = cfg.get("Mqtt", {}) or {}
    cred = {
        "brokerhost": m.get("Brokerhost"),
        "websocketport": m.get("Websocketport", "9001"),
        "brokeruser": m.get("Brokeruser"),
        "brokerpass": m.get("Brokerpass"),
        "udpinport": m.get("Udpinport"),
        "brokerport": m.get("Brokerport"),
    }
    cred["brokeraddress"] = "%s:%s" % (cred["brokerhost"], cred["brokerport"])

    use_local = system.is_enabled(m.get("Uselocalbroker", "true"))
    if use_local and system.is_enabled(m.get("Tlsenabled", "false")):
        cred["tls"] = 1
        cred["tls_verify"] = 0
        cred["tls_cafile"] = "/etc/mosquitto/tls/ca.crt"
        cred["tls_brokerport"] = m.get("Tlsport", 8883)
        cred["tls_brokeraddress"] = "%s:%s" % (cred["brokerhost"], cred["tls_brokerport"])
    elif not use_local and system.is_enabled(m.get("TlsExternalEnabled", "false")):
        cred["tls"] = 1
        cred["tls_verify"] = 1 if system.is_enabled(m.get("TlsExternalValidatecert", "false")) else 0
        cred["tls_cafile"] = "%s/mqtt_external_ca.crt" % system.lbsconfigdir
        cred["tls_brokerport"] = cred["brokerport"]
        cred["tls_brokeraddress"] = cred["brokeraddress"]
    else:
        cred["tls"] = 0
    return cred


def _new_paho_client():
    import paho.mqtt.client as mqtt
    # paho-mqtt 2.x requires a callback API version; 1.6 does not accept it.
    try:
        return mqtt.Client(mqtt.CallbackAPIVersion.VERSION1)
    except (AttributeError, TypeError):
        return mqtt.Client()


def mqtt_connect():
    """Connect to the MQTT broker (cached). Returns the paho client or None."""
    global _mqtt_client
    if _mqtt_client is not None:
        return _mqtt_client

    cred = mqtt_connectiondetails()
    if not cred or not cred.get("brokerhost"):
        return None

    try:
        client = _new_paho_client()
        if cred.get("brokeruser") or cred.get("brokerpass"):
            client.username_pw_set(cred.get("brokeruser") or "",
                                   cred.get("brokerpass") or "")
        if cred.get("tls"):
            import ssl
            if cred.get("tls_verify") and cred.get("tls_cafile") and os.path.isfile(cred["tls_cafile"]):
                client.tls_set(ca_certs=cred["tls_cafile"])
            else:
                client.tls_set(cert_reqs=ssl.CERT_NONE)
                client.tls_insecure_set(True)
            host = cred["brokerhost"]
            port = int(cred["tls_brokerport"])
        else:
            host = cred["brokerhost"]
            port = int(cred["brokerport"])
        client.connect(host, port, keepalive=60)
        client.loop_start()
    except Exception:
        return None

    _mqtt_client = client
    return _mqtt_client


def mqtt_set(topic, value, retain=False):
    """Publish (or retain) a value to an MQTT topic. Returns the topic or None."""
    client = mqtt_connect()
    if client is None:
        return None
    try:
        client.publish(topic, value, retain=bool(retain))
        return topic
    except Exception:
        return None


def mqtt_retain(topic, value):
    return mqtt_set(topic, value, retain=True)


def mqtt_publish(topic, value):
    return mqtt_set(topic, value, retain=False)


def mqtt_get(topic, timeout_msecs=250):
    """Subscribe to a topic and return the first received retained value, or None."""
    client = mqtt_connect()
    if client is None:
        return None
    if not timeout_msecs:
        timeout_msecs = 250

    received = {}

    def _on_message(_client, _userdata, msg):
        try:
            received[msg.topic] = msg.payload.decode("utf-8", "replace")
        except Exception:
            received[msg.topic] = msg.payload

    prev = client.on_message
    client.on_message = _on_message
    try:
        client.subscribe(topic)
    except Exception:
        client.on_message = prev
        return None

    endtime = _time.time() + timeout_msecs / 1000.0
    while not received and _time.time() < endtime:
        _time.sleep(0.05)

    try:
        client.unsubscribe(topic)
    except Exception:
        pass
    client.on_message = prev

    if received:
        return received[sorted(received.keys())[0]]
    return None
