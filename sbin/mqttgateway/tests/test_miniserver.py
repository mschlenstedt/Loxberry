"""Tests for mqttgateway.miniserver — TDD, written before implementation."""
from __future__ import annotations

import pytest
from unittest.mock import AsyncMock, MagicMock, patch

from mqttgateway.miniserver import MiniserverSender


@pytest.fixture
def ms_config():
    return {
        1: {
            "Name": "MS_Gen2",
            "Ipaddress": "192.168.30.11",
            "Port": "80",
            "Admin": "admin",
            "Pass": "pass123",
        },
    }


# ---------------------------------------------------------------------------
# TestDeltaCache
# ---------------------------------------------------------------------------

class TestDeltaCache:
    @pytest.mark.asyncio
    async def test_first_send_goes_through(self, ms_config):
        sender = MiniserverSender(ms_config)
        with patch.object(sender, "_http_send", new_callable=AsyncMock) as mock:
            mock.return_value = {"topic_a": {"code": 200}}
            await sender.send_cached(1, {"topic_a": "value1"})
            mock.assert_called_once()

    @pytest.mark.asyncio
    async def test_duplicate_not_resent(self, ms_config):
        sender = MiniserverSender(ms_config)
        with patch.object(sender, "_http_send", new_callable=AsyncMock) as mock:
            mock.return_value = {"topic_a": {"code": 200}}
            await sender.send_cached(1, {"topic_a": "value1"})
            await sender.send_cached(1, {"topic_a": "value1"})
            assert mock.call_count == 1

    @pytest.mark.asyncio
    async def test_changed_value_resent(self, ms_config):
        sender = MiniserverSender(ms_config)
        with patch.object(sender, "_http_send", new_callable=AsyncMock) as mock:
            mock.return_value = {"topic_a": {"code": 200}}
            await sender.send_cached(1, {"topic_a": "value1"})
            mock.return_value = {"topic_a": {"code": 200}}
            await sender.send_cached(1, {"topic_a": "value2"})
            assert mock.call_count == 2

    @pytest.mark.asyncio
    async def test_invalidate_cache_resends(self, ms_config):
        sender = MiniserverSender(ms_config)
        with patch.object(sender, "_http_send", new_callable=AsyncMock) as mock:
            mock.return_value = {"topic_a": {"code": 200}}
            await sender.send_cached(1, {"topic_a": "value1"})
            sender.invalidate_cache(1)
            await sender.send_cached(1, {"topic_a": "value1"})
            assert mock.call_count == 2

    @pytest.mark.asyncio
    async def test_invalidate_all_caches(self, ms_config):
        config = {
            1: {"Ipaddress": "192.168.1.1", "Port": "80"},
            2: {"Ipaddress": "192.168.1.2", "Port": "80"},
        }
        sender = MiniserverSender(config)
        with patch.object(sender, "_http_send", new_callable=AsyncMock) as mock:
            mock.return_value = {"t": {"code": 200}}
            await sender.send_cached(1, {"t": "v"})
            await sender.send_cached(2, {"t": "v"})
            sender.invalidate_cache()  # no ms_nr — clears all
            await sender.send_cached(1, {"t": "v"})
            await sender.send_cached(2, {"t": "v"})
            assert mock.call_count == 4

    @pytest.mark.asyncio
    async def test_returns_none_on_no_delta(self, ms_config):
        sender = MiniserverSender(ms_config)
        with patch.object(sender, "_http_send", new_callable=AsyncMock) as mock:
            mock.return_value = {"topic_a": {"code": 200}}
            await sender.send_cached(1, {"topic_a": "value1"})
            result = await sender.send_cached(1, {"topic_a": "value1"})
            assert result is None

    @pytest.mark.asyncio
    async def test_partial_delta_only_sends_changed(self, ms_config):
        """Only the changed key is forwarded, unchanged key is skipped."""
        sender = MiniserverSender(ms_config)
        with patch.object(sender, "_http_send", new_callable=AsyncMock) as mock:
            mock.return_value = {"t1": {"code": 200}, "t2": {"code": 200}}
            await sender.send_cached(1, {"t1": "v1", "t2": "v2"})
            mock.reset_mock()
            mock.return_value = {"t1": {"code": 200}}
            await sender.send_cached(1, {"t1": "changed", "t2": "v2"})
            mock.assert_called_once_with(1, {"t1": "changed"})


# ---------------------------------------------------------------------------
# TestNoncachedSend
# ---------------------------------------------------------------------------

class TestNoncachedSend:
    @pytest.mark.asyncio
    async def test_always_sends(self, ms_config):
        sender = MiniserverSender(ms_config)
        with patch.object(sender, "_http_send", new_callable=AsyncMock) as mock:
            mock.return_value = {"topic_a": {"code": 200}}
            await sender.send_noncached(1, {"topic_a": "value1"})
            await sender.send_noncached(1, {"topic_a": "value1"})
            assert mock.call_count == 2

    @pytest.mark.asyncio
    async def test_returns_result_dict(self, ms_config):
        sender = MiniserverSender(ms_config)
        with patch.object(sender, "_http_send", new_callable=AsyncMock) as mock:
            mock.return_value = {"topic_a": {"code": 200, "value": "OK"}}
            result = await sender.send_noncached(1, {"topic_a": "value1"})
            assert result == {"topic_a": {"code": 200, "value": "OK"}}


# ---------------------------------------------------------------------------
# TestSanitize
# ---------------------------------------------------------------------------

class TestSanitize:
    def test_slash_replaced(self):
        assert MiniserverSender.sanitize_topic("a/b") == "a_b"

    def test_percent_replaced(self):
        assert MiniserverSender.sanitize_topic("a%b") == "a_b"

    def test_slash_and_percent(self):
        assert MiniserverSender.sanitize_topic("a/b%c") == "a_b_c"

    def test_no_special_chars(self):
        assert MiniserverSender.sanitize_topic("sensor_temp") == "sensor_temp"

    def test_multiple_slashes(self):
        assert MiniserverSender.sanitize_topic("a/b/c/d") == "a_b_c_d"


# ---------------------------------------------------------------------------
# TestUdpSend
# ---------------------------------------------------------------------------

class TestUdpSend:
    @pytest.mark.asyncio
    async def test_udp_format(self):
        transport = MagicMock()
        sender = MiniserverSender({1: {"Ipaddress": "192.168.30.11"}})
        sender._udp_transports = {1: (transport, ("192.168.30.11", 11883))}
        await sender.send_udp(1, 11883, {"sensor_temp": "22.5"})
        transport.sendto.assert_called()
        sent = transport.sendto.call_args[0][0]
        assert b"sensor_temp=22.5" in sent

    @pytest.mark.asyncio
    async def test_udp_newline_terminated(self):
        transport = MagicMock()
        sender = MiniserverSender({1: {"Ipaddress": "192.168.30.11"}})
        sender._udp_transports = {1: (transport, ("192.168.30.11", 11883))}
        await sender.send_udp(1, 11883, {"t": "v"})
        sent = transport.sendto.call_args[0][0]
        assert sent.endswith(b"\n")

    @pytest.mark.asyncio
    async def test_udp_multiple_values_sends_multiple_packets(self):
        transport = MagicMock()
        sender = MiniserverSender({1: {"Ipaddress": "192.168.30.11"}})
        sender._udp_transports = {1: (transport, ("192.168.30.11", 11883))}
        await sender.send_udp(1, 11883, {"t1": "v1", "t2": "v2"})
        assert transport.sendto.call_count == 2

    @pytest.mark.asyncio
    async def test_udp_utf8_encoded(self):
        transport = MagicMock()
        sender = MiniserverSender({1: {"Ipaddress": "192.168.30.11"}})
        sender._udp_transports = {1: (transport, ("192.168.30.11", 11883))}
        await sender.send_udp(1, 11883, {"t": "Ärger"})
        sent = transport.sendto.call_args[0][0]
        assert isinstance(sent, bytes)
        assert "Ärger".encode("utf-8") in sent


# ---------------------------------------------------------------------------
# TestClose
# ---------------------------------------------------------------------------

class TestClose:
    @pytest.mark.asyncio
    async def test_close_clears_http_clients(self, ms_config):
        sender = MiniserverSender(ms_config)
        # Force a client to be created via _get_client
        sender._get_client(1)
        assert 1 in sender._http_clients
        await sender.close()
        assert sender._http_clients == {}

    @pytest.mark.asyncio
    async def test_close_clears_udp_transports(self, ms_config):
        transport = MagicMock()
        sender = MiniserverSender(ms_config)
        sender._udp_transports = {1: (transport, ("192.168.30.11", 11883))}
        await sender.close()
        transport.close.assert_called_once()
        assert sender._udp_transports == {}
