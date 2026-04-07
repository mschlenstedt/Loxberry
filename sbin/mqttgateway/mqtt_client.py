"""MQTT client — aiomqtt wrapper with subscription management."""
from __future__ import annotations

import asyncio
import logging
from typing import Callable, Awaitable

import aiomqtt

log = logging.getLogger("mqttgateway")


class MqttClient:
    def __init__(self, host: str, port: int = 1883, username: str = "", password: str = "", hostname: str = "loxberry"):
        self.host = host
        self.port = port
        self.username = username
        self.password = password
        self.hostname = hostname
        self._gw_topic = f"{hostname}/mqttgateway/"
        self._client: aiomqtt.Client | None = None

    async def connect_and_run(self, topics: list[str], on_message: Callable[[str, str], Awaitable[None]]) -> None:
        while True:
            try:
                async with aiomqtt.Client(
                    hostname=self.host, port=self.port,
                    username=self.username or None,
                    password=self.password or None,
                    will=aiomqtt.Will(topic=self._gw_topic + "status", payload="Disconnected", retain=True),
                ) as client:
                    self._client = client
                    log.info("Connected to MQTT broker %s:%d", self.host, self.port)
                    await client.publish(self._gw_topic + "status", "Connected", retain=True)

                    all_topics = list(set(topics + [self._gw_topic + "#"]))
                    for topic in all_topics:
                        await client.subscribe(topic)
                        log.info("Subscribed: %s", topic)

                    async for message in client.messages:
                        topic_str = str(message.topic)
                        payload_str = (
                            message.payload.decode("utf-8", errors="replace")
                            if isinstance(message.payload, bytes) else str(message.payload)
                        )
                        try:
                            await on_message(topic_str, payload_str)
                        except Exception as e:
                            log.error("Error processing %s: %s", topic_str, e)

            except aiomqtt.MqttError as e:
                log.warning("MQTT connection lost: %s. Reconnecting in 5s...", e)
                self._client = None
                await asyncio.sleep(5)
            except asyncio.CancelledError:
                log.info("MQTT client shutting down")
                self._client = None
                raise

    async def publish(self, topic: str, payload: str, retain: bool = False) -> None:
        if self._client:
            await self._client.publish(topic, payload, retain=retain)
        else:
            log.warning("Cannot publish — not connected")

    async def resubscribe(self, topics: list[str]) -> None:
        if not self._client:
            return
        all_topics = list(set(topics + [self._gw_topic + "#"]))
        for topic in all_topics:
            await self._client.subscribe(topic)
            log.debug("Re-subscribed: %s", topic)
