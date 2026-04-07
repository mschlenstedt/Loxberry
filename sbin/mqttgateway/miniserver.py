"""Miniserver communication — async HTTP delta-send + UDP."""
from __future__ import annotations

import asyncio
import logging
import urllib.parse
from typing import Any

import httpx

log = logging.getLogger("mqttgateway")


class MiniserverSender:
    """Manages HTTP and UDP communication to Loxone Miniservers."""

    def __init__(self, miniservers: dict[int, dict]):
        self._miniservers = miniservers
        self._http_clients: dict[int, httpx.AsyncClient] = {}
        self._cache: dict[int, dict[str, str]] = {}
        self._udp_transports: dict[int, tuple[Any, tuple[str, int]]] = {}

    @staticmethod
    def sanitize_topic(topic: str) -> str:
        return topic.replace("/", "_").replace("%", "_")

    def _get_client(self, ms_nr: int) -> httpx.AsyncClient:
        if ms_nr not in self._http_clients:
            ms = self._miniservers[ms_nr]
            auth = None
            if ms.get("Admin") and ms.get("Pass"):
                auth = httpx.BasicAuth(ms["Admin"], ms["Pass"])
            self._http_clients[ms_nr] = httpx.AsyncClient(
                base_url=f"http://{ms['Ipaddress']}:{ms.get('Port', 80)}",
                auth=auth,
                timeout=10.0,
            )
        return self._http_clients[ms_nr]

    async def _http_send(self, ms_nr: int, values: dict[str, str]) -> dict[str, dict[str, Any]]:
        client = self._get_client(ms_nr)
        results: dict[str, dict[str, Any]] = {}
        for topic, value in values.items():
            encoded_topic = urllib.parse.quote(topic, safe="")
            encoded_value = urllib.parse.quote(str(value), safe="")
            url = f"/dev/sps/io/{encoded_topic}/{encoded_value}"
            try:
                resp = await client.get(url)
                results[topic] = {"code": resp.status_code, "value": resp.text}
            except httpx.HTTPError as e:
                log.warning("HTTP send to MS %d failed for %s: %s", ms_nr, topic, e)
                results[topic] = {"code": 0, "value": str(e)}
        return results

    async def send_cached(self, ms_nr: int, values: dict[str, str]) -> dict[str, dict[str, Any]] | None:
        if ms_nr not in self._cache:
            self._cache[ms_nr] = {}
        delta: dict[str, str] = {}
        for topic, value in values.items():
            if self._cache[ms_nr].get(topic) != value:
                delta[topic] = value
                self._cache[ms_nr][topic] = value
        if not delta:
            return None
        return await self._http_send(ms_nr, delta)

    async def send_noncached(self, ms_nr: int, values: dict[str, str]) -> dict[str, dict[str, Any]]:
        return await self._http_send(ms_nr, values)

    def invalidate_cache(self, ms_nr: int | None = None) -> None:
        if ms_nr is None:
            self._cache.clear()
        else:
            self._cache.pop(ms_nr, None)

    async def send_udp(self, ms_nr: int, port: int, values: dict[str, str]) -> None:
        if ms_nr not in self._udp_transports:
            ms = self._miniservers.get(ms_nr, {})
            ip = ms.get("Ipaddress", "127.0.0.1")
            loop = asyncio.get_event_loop()
            transport, _ = await loop.create_datagram_endpoint(
                asyncio.DatagramProtocol,
                remote_addr=(ip, port),
            )
            self._udp_transports[ms_nr] = (transport, (ip, port))
        transport, addr = self._udp_transports[ms_nr]
        for topic, value in values.items():
            msg = f"{topic}={value}\n".encode("utf-8")
            transport.sendto(msg, addr)

    async def close(self) -> None:
        for client in self._http_clients.values():
            await client.aclose()
        self._http_clients.clear()
        for transport, _ in self._udp_transports.values():
            transport.close()
        self._udp_transports.clear()
