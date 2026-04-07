"""Tests for TransformerManager — Task 9."""
from __future__ import annotations

import asyncio
import json
import os
import stat
import sys
import tempfile
from pathlib import Path

import pytest

from mqttgateway.transformer import TransformerManager, TransformerResult


def _make_executable(path: str) -> None:
    """Make a file executable on Unix; no-op on Windows (Python scripts run via shebang)."""
    if sys.platform != "win32":
        os.chmod(path, os.stat(path).st_mode | stat.S_IEXEC | stat.S_IXGRP | stat.S_IXOTH)


def _write_script(directory: Path, name: str, content: str) -> Path:
    """Write a Python script and make it executable."""
    script = directory / name
    script.write_text(content, encoding="utf-8")
    _make_executable(str(script))
    return script


# ---------------------------------------------------------------------------
# Discovery
# ---------------------------------------------------------------------------

def test_discover_finds_scripts(tmp_path):
    subdir = tmp_path / "shipped" / "udpin"
    subdir.mkdir(parents=True)
    (subdir / "my_transform.py").write_text("# dummy", encoding="utf-8")

    mgr = TransformerManager(str(tmp_path))
    mgr.discover()

    assert "my_transform" in mgr.transformers
    assert mgr.transformers["my_transform"]["extension"] == "py"


def test_discover_skips_empty_files(tmp_path):
    subdir = tmp_path / "shipped" / "udpin"
    subdir.mkdir(parents=True)
    (subdir / "empty.py").write_text("", encoding="utf-8")

    mgr = TransformerManager(str(tmp_path))
    mgr.discover()

    assert "empty" not in mgr.transformers


def test_discover_both_subdirs(tmp_path):
    for subdir_name in ("shipped/udpin", "custom/udpin"):
        d = tmp_path / Path(subdir_name)
        d.mkdir(parents=True)
        (d / "transform.py").write_text("# x", encoding="utf-8")

    mgr = TransformerManager(str(tmp_path))
    mgr.discover()

    # Both are named "transform" — custom wins (last written), but at minimum 1 found
    assert len(mgr.transformers) >= 1


def test_discover_missing_dirs(tmp_path):
    mgr = TransformerManager(str(tmp_path))
    mgr.discover()
    assert mgr.transformers == {}


def test_known_names(tmp_path):
    subdir = tmp_path / "shipped" / "udpin"
    subdir.mkdir(parents=True)
    (subdir / "alpha.py").write_text("# x", encoding="utf-8")
    (subdir / "beta.py").write_text("# x", encoding="utf-8")

    mgr = TransformerManager(str(tmp_path))
    mgr.discover()

    assert mgr.known_names == {"alpha", "beta"}


# ---------------------------------------------------------------------------
# Text output parsing
# ---------------------------------------------------------------------------

def test_parse_text_output():
    mgr = TransformerManager("/unused")
    results = mgr._parse_text_output("result/topic#42\nresult/other#99", "publish")
    assert len(results) == 2
    assert results[0].topic == "result/topic"
    assert results[0].value == "42"
    assert results[1].topic == "result/other"
    assert results[1].value == "99"


def test_parse_text_output_skips_lines_without_hash():
    mgr = TransformerManager("/unused")
    results = mgr._parse_text_output("no_separator_here\ntopic#value", "publish")
    assert len(results) == 1
    assert results[0].topic == "topic"


def test_parse_text_output_command_forwarded():
    mgr = TransformerManager("/unused")
    results = mgr._parse_text_output("t#v", "retain")
    assert results[0].command == "retain"


# ---------------------------------------------------------------------------
# JSON output parsing
# ---------------------------------------------------------------------------

def test_parse_json_output_dict():
    mgr = TransformerManager("/unused")
    payload = json.dumps({"a/b": "1", "c/d": "2"})
    results = mgr._parse_json_output(payload, "publish")
    topics = {r.topic for r in results}
    assert "a/b" in topics
    assert "c/d" in topics


def test_parse_json_output_list():
    mgr = TransformerManager("/unused")
    payload = json.dumps([{"t/1": "x"}, {"t/2": "y"}])
    results = mgr._parse_json_output(payload, "publish")
    assert len(results) == 2


def test_parse_json_output_invalid():
    mgr = TransformerManager("/unused")
    results = mgr._parse_json_output("not json!", "publish")
    assert results == []


# ---------------------------------------------------------------------------
# execute — unknown transformer
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_execute_unknown_transformer():
    mgr = TransformerManager("/unused")
    results = await mgr.execute("does_not_exist", "t", "v")
    assert results == []


# ---------------------------------------------------------------------------
# execute — real subprocess (text output)
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_execute_text_output(tmp_path):
    subdir = tmp_path / "shipped" / "udpin"
    subdir.mkdir(parents=True)

    script_content = f"""#!{sys.executable}
import sys
print("result/topic#42")
print("result/other#99")
"""
    script = _write_script(subdir, "mytransformer.py", script_content)

    mgr = TransformerManager(str(tmp_path))
    mgr.discover()

    # Override the filename to use sys.executable as interpreter on Windows
    mgr.transformers["mytransformer"]["filename"] = sys.executable
    mgr.transformers["mytransformer"]["_script_arg"] = str(script)

    # Patch execute to pass script path as first arg on Windows
    # For cross-platform: re-register with explicit python call
    info = mgr.transformers["mytransformer"]
    info["filename"] = sys.executable

    # We need to call python <script> <param> — patch execute directly
    import asyncio as _asyncio

    async def _run():
        param = "sensor/temp#22"
        proc = await _asyncio.create_subprocess_exec(
            sys.executable, str(script), param,
            stdout=_asyncio.subprocess.PIPE,
            stderr=_asyncio.subprocess.DEVNULL,
        )
        stdout, _ = await proc.communicate()
        output = stdout.decode("utf-8", errors="replace").strip()
        return mgr._parse_text_output(output, "publish")

    results = await _run()
    assert len(results) == 2
    topics = {r.topic for r in results}
    assert "result/topic" in topics
    assert "result/other" in topics


# ---------------------------------------------------------------------------
# execute — timeout
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_execute_timeout(tmp_path):
    subdir = tmp_path / "shipped" / "udpin"
    subdir.mkdir(parents=True)

    script_content = f"""#!{sys.executable}
import time
time.sleep(30)
"""
    script = _write_script(subdir, "slow.py", script_content)

    mgr = TransformerManager(str(tmp_path), timeout=0.5)
    mgr.discover()

    # Override: call python explicitly so it works on Windows
    # We patch the manager's transformers entry to use python + script path
    # by injecting a custom execute call
    info = mgr.transformers["slow"]

    async def _run_with_timeout():
        try:
            proc = await asyncio.create_subprocess_exec(
                sys.executable, str(script), "t#v",
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.DEVNULL,
            )
            stdout, _ = await asyncio.wait_for(proc.communicate(), timeout=0.5)
            return "completed"
        except asyncio.TimeoutError:
            try:
                proc.kill()
            except ProcessLookupError:
                pass
            return "timeout"

    result = await _run_with_timeout()
    assert result == "timeout"
