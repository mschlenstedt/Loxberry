"""Entry point: python3 -m mqttgateway or python3 /opt/loxberry/sbin/mqttgateway."""
import asyncio
import sys


async def main() -> None:
    print("MQTT Gateway V2 starting...")
    # Components will be wired here in later tasks
    await asyncio.sleep(1)
    print("MQTT Gateway V2 placeholder — not yet implemented.")


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        sys.exit(0)
