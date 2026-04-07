"""Transformer — async subprocess execution of PHP/Perl transform scripts."""
from __future__ import annotations

import asyncio
import json
import logging
import os
from dataclasses import dataclass
from pathlib import Path

log = logging.getLogger("mqttgateway")


@dataclass
class TransformerResult:
    topic: str
    value: str
    command: str = "publish"


class TransformerManager:
    def __init__(self, base_path: str, timeout: float = 10.0):
        self._base_path = Path(base_path)
        self._timeout = timeout
        self.transformers: dict[str, dict] = {}

    def discover(self) -> None:
        self.transformers.clear()
        for subdir in ("shipped/udpin", "custom/udpin"):
            scan_dir = self._base_path / subdir
            if not scan_dir.exists():
                continue
            for filepath in scan_dir.rglob("*"):
                if not filepath.is_file() or filepath.stat().st_size == 0:
                    continue
                name = filepath.stem.lower().replace(" ", "_")
                ext = filepath.suffix.lstrip(".")
                self.transformers[name] = {
                    "filename": str(filepath), "extension": ext,
                    "input": "text", "output": "text",
                    "description": "", "link": "",
                }
        log.info("Discovered %d transformers", len(self.transformers))

    async def load_skills(self) -> None:
        for name, info in self.transformers.items():
            try:
                proc = await asyncio.create_subprocess_exec(
                    info["filename"], "skills",
                    stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.DEVNULL,
                )
                stdout, _ = await asyncio.wait_for(proc.communicate(), timeout=5.0)
                for line in stdout.decode("utf-8", errors="replace").splitlines():
                    if "=" in line:
                        key, val = line.split("=", 1)
                        key = key.strip().lower()
                        if key in ("input", "output", "description", "link"):
                            info[key] = val.strip()
                if info["input"] not in ("text", "json"):
                    info["input"] = "text"
                if info["output"] not in ("text", "json"):
                    info["output"] = "text"
            except Exception as e:
                log.debug("Could not load skills for %s: %s", name, e)

    async def execute(self, name: str, topic: str, message: str, command: str = "publish") -> list[TransformerResult]:
        if name not in self.transformers:
            log.warning("Unknown transformer: %s", name)
            return []

        info = self.transformers[name]
        if info["input"] == "json":
            param = json.dumps({topic: message})
        else:
            param = f"{topic}#{message}"

        try:
            proc = await asyncio.create_subprocess_exec(
                info["filename"], param,
                stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.DEVNULL,
            )
            stdout, _ = await asyncio.wait_for(proc.communicate(), timeout=self._timeout)
        except asyncio.TimeoutError:
            log.error("Transformer %s timed out", name)
            try:
                proc.kill()
            except ProcessLookupError:
                pass
            return []
        except Exception as e:
            log.error("Error running transformer %s: %s", name, e)
            return []

        output = stdout.decode("utf-8", errors="replace").strip()
        if not output:
            return []

        if info["output"] == "json":
            return self._parse_json_output(output, command)
        return self._parse_text_output(output, command)

    def _parse_text_output(self, output: str, command: str) -> list[TransformerResult]:
        results = []
        for line in output.splitlines():
            if "#" in line:
                topic, value = line.split("#", 1)
                results.append(TransformerResult(topic=topic.strip(), value=value.strip(), command=command))
        return results

    def _parse_json_output(self, output: str, command: str) -> list[TransformerResult]:
        try:
            data = json.loads(output)
        except json.JSONDecodeError:
            log.error("Transformer JSON invalid: %s", output[:200])
            return []
        results = []
        if isinstance(data, list):
            for item in data:
                if isinstance(item, dict):
                    for k, v in item.items():
                        results.append(TransformerResult(topic=k, value=str(v), command=command))
        elif isinstance(data, dict):
            for k, v in data.items():
                results.append(TransformerResult(topic=k, value=str(v), command=command))
        return results

    @property
    def known_names(self) -> set[str]:
        return set(self.transformers.keys())
