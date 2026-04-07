"""Entry point: python3 -m mqttgateway or python3 /opt/loxberry/sbin/mqttgateway."""
from __future__ import annotations

import asyncio
import logging
import os
import socket
import sys

from .config import GatewayConfig
from .logging_compat import OK, setup_logging
from .miniserver import MiniserverSender
from .mqtt_client import MqttClient
from .pipeline import Pipeline
from .state import StateManager
from .transformer import TransformerManager
from .udp_listener import UdpListenerProtocol

# LoxBerry paths (overridable via LBHOMEDIR env var)
LBHOME = os.environ.get("LBHOMEDIR", "/opt/loxberry")
LBSCONFIG = os.path.join(LBHOME, "config", "system")
LBSBIN = os.path.join(LBHOME, "sbin")
LBPLUGINCONFIG = os.path.join(LBHOME, "config", "plugins")

log: logging.Logger = logging.getLogger("mqttgateway")


class Gateway:
    def __init__(self) -> None:
        self.config = GatewayConfig(
            general_json_path=os.path.join(LBSCONFIG, "general.json"),
            gateway_json_path=os.path.join(LBSCONFIG, "mqttgateway.json"),
            plugin_config_dir=LBPLUGINCONFIG,
        )
        self.state = StateManager()
        self.transformer = TransformerManager(os.path.join(LBSBIN, "mqtt", "transform"))

        # Initialised in run()
        self.pipeline: Pipeline
        self.ms_sender: MiniserverSender
        self.mqtt_client: MqttClient
        self._udp_queue: asyncio.Queue

    # ------------------------------------------------------------------
    # Helpers
    # ------------------------------------------------------------------

    def _build_pipeline(self) -> Pipeline:
        return Pipeline(
            hostname=socket.gethostname(),
            do_not_forward=self.config.do_not_forward,
            subscription_filters=self.config.subscription_filters,
            convert_booleans=self.config.convert_booleans,
            conversions=self.config.conversions,
            subscriptions=self.config.subscriptions,
            default_ms=self.config.default_ms,
        )

    def _get_all_topics(self) -> list[str]:
        topics = [sub.topic for sub in self.config.subscriptions]
        topics.extend(self.config.plugin_subscriptions)
        return topics

    # ------------------------------------------------------------------
    # MQTT message handler
    # ------------------------------------------------------------------

    async def _on_mqtt_message(self, topic: str, payload: str) -> None:
        result = self.pipeline.process(topic, payload)
        if result is None:
            return
        for item in result.items:
            for ms_nr in item.toms:
                if self.config.use_http:
                    self.state.record_http(
                        item.topic_underlined, item.value,
                        item.original_topic, ms_nr=ms_nr, code=0,
                    )
                    if item.noncached:
                        resp = await self.ms_sender.send_noncached(ms_nr, {item.topic_underlined: item.value})
                    else:
                        resp = await self.ms_sender.send_cached(ms_nr, {item.topic_underlined: item.value})
                    if resp:
                        for t, r in resp.items():
                            self.state.record_http(
                                t, item.value, item.original_topic,
                                ms_nr=ms_nr, code=r.get("code", 0),
                            )
                if self.config.use_udp:
                    self.state.record_udp(item.original_topic, item.value, item.original_topic)
                    if item.noncached:
                        await self.ms_sender.send_udp(ms_nr, self.config.udp_port, {item.original_topic: item.value})
                if item.reset_after_send:
                    asyncio.create_task(self._reset_after_send(ms_nr, item.topic_underlined))

    async def _reset_after_send(self, ms_nr: int, topic: str) -> None:
        await asyncio.sleep(self.config.reset_after_send_ms / 1000.0)
        if self.config.use_http:
            await self.ms_sender.send_noncached(ms_nr, {topic: "0"})
        if self.config.use_udp:
            await self.ms_sender.send_udp(ms_nr, self.config.udp_port, {topic: "0"})

    # ------------------------------------------------------------------
    # Background tasks
    # ------------------------------------------------------------------

    async def _process_udp_commands(self) -> None:
        while True:
            cmd = await self._udp_queue.get()
            if cmd.command == "save_relayed_states":
                self.state.save()
            elif cmd.command == "reconnect":
                log.info("Reconnect requested")
                self.ms_sender.invalidate_cache()
            elif cmd.command in ("publish", "retain"):
                retain = cmd.command == "retain"
                if cmd.transformer:
                    results = await self.transformer.execute(
                        cmd.transformer, cmd.topic, cmd.message, command=cmd.command,
                    )
                    for r in results:
                        await self.mqtt_client.publish(r.topic, r.value, retain=(r.command == "retain"))
                else:
                    await self.mqtt_client.publish(cmd.topic, cmd.message, retain=retain)

    async def _config_watcher(self) -> None:
        while True:
            await asyncio.sleep(5)
            if self.config.has_changed():
                log.info("Config changed — reloading")
                self.config.load()
                self.pipeline = self._build_pipeline()
                await self.mqtt_client.resubscribe(self._get_all_topics())

    async def _state_saver(self) -> None:
        while True:
            await asyncio.sleep(2)
            self.state.save()

    async def _watchdog(self) -> None:
        try:
            import sdnotify  # type: ignore[import]
            n = sdnotify.SystemdNotifier()
            n.notify("READY=1")
            while True:
                n.notify("WATCHDOG=1")
                await asyncio.sleep(30)
        except ImportError:
            log.debug("sdnotify not available — watchdog disabled")

    # ------------------------------------------------------------------
    # Main run loop
    # ------------------------------------------------------------------

    async def run(self) -> None:
        self.config.load()
        self.pipeline = self._build_pipeline()
        self.ms_sender = MiniserverSender(self.config.miniservers)
        self.mqtt_client = MqttClient(
            host=self.config.broker_host,
            port=self.config.broker_port,
            username=self.config.broker_user,
            password=self.config.broker_pass,
            hostname=socket.gethostname(),
        )
        self.transformer.discover()
        await self.transformer.load_skills()

        self.state.do_not_forward = {t: "true" for t in self.config.do_not_forward}
        self.state.subscription_filters = [p.pattern for p in self.config.subscription_filters]
        self._udp_queue: asyncio.Queue = asyncio.Queue()

        loop = asyncio.get_event_loop()
        transport, _ = await loop.create_datagram_endpoint(
            lambda: UdpListenerProtocol(self._udp_queue, self.transformer.known_names),
            local_addr=("0.0.0.0", self.config.udp_in_port),
        )
        log.info("UDP listener on port %d", self.config.udp_in_port)

        topics = self._get_all_topics()
        log.info("Starting with %d subscriptions", len(topics))

        async with asyncio.TaskGroup() as tg:
            tg.create_task(self.mqtt_client.connect_and_run(topics, self._on_mqtt_message))
            tg.create_task(self._process_udp_commands())
            tg.create_task(self._config_watcher())
            tg.create_task(self._state_saver())
            tg.create_task(self._watchdog())


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

async def main() -> None:
    global log
    log = setup_logging(loglevel=7)
    log.log(OK, "MQTT Gateway V2 starting")
    gateway = Gateway()
    try:
        await gateway.run()
    except (KeyboardInterrupt, asyncio.CancelledError):
        log.info("Shutting down...")
    finally:
        if hasattr(gateway, "ms_sender"):
            await gateway.ms_sender.close()
        log.info("MQTT Gateway V2 stopped")


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        sys.exit(0)
