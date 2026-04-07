import logging
import re
import tempfile
import os
import pytest
from mqttgateway.logging_compat import setup_logging, LOGLEVEL_MAP, LoxBerryFormatter


class TestLoxBerryFormatter:
    def test_format_info_message(self):
        formatter = LoxBerryFormatter()
        record = logging.LogRecord(
            name="mqttgateway", level=logging.INFO,
            pathname="", lineno=0, msg="Test message",
            args=None, exc_info=None,
        )
        result = formatter.format(record)
        assert result.startswith("<INFO>")
        assert "Test message" in result
        assert re.match(r"<INFO> \d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2} Test message", result)

    def test_format_error_message(self):
        formatter = LoxBerryFormatter()
        record = logging.LogRecord(
            name="mqttgateway", level=logging.ERROR,
            pathname="", lineno=0, msg="Something broke",
            args=None, exc_info=None,
        )
        result = formatter.format(record)
        assert result.startswith("<ERROR>")

    def test_format_warning_message(self):
        formatter = LoxBerryFormatter()
        record = logging.LogRecord(
            name="mqttgateway", level=logging.WARNING,
            pathname="", lineno=0, msg="Watch out",
            args=None, exc_info=None,
        )
        result = formatter.format(record)
        assert result.startswith("<WARNING>")

    def test_format_debug_message(self):
        formatter = LoxBerryFormatter()
        record = logging.LogRecord(
            name="mqttgateway", level=logging.DEBUG,
            pathname="", lineno=0, msg="Debug info",
            args=None, exc_info=None,
        )
        result = formatter.format(record)
        assert result.startswith("<DEBUG>")

    def test_format_ok_message(self):
        """OK is a custom level between INFO and WARNING (level 25)."""
        formatter = LoxBerryFormatter()
        record = logging.LogRecord(
            name="mqttgateway", level=25,
            pathname="", lineno=0, msg="Success",
            args=None, exc_info=None,
        )
        result = formatter.format(record)
        assert result.startswith("<OK>")


class TestSetupLogging:
    def test_creates_log_file(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            logfile = os.path.join(tmpdir, "mqttgateway.log")
            logger = setup_logging(logfile=logfile, loglevel=7)
            logger.info("Test")
            for h in logger.handlers:
                h.flush()
            assert os.path.exists(logfile)
            content = open(logfile).read()
            # Close handlers before tempdir cleanup (Windows holds file locks)
            for h in logger.handlers[:]:
                h.close()
                logger.removeHandler(h)
            assert "<INFO>" in content
            assert "Test" in content

    def test_loglevel_3_filters_info(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            logfile = os.path.join(tmpdir, "mqttgateway.log")
            logger = setup_logging(logfile=logfile, loglevel=3)
            logger.info("should not appear")
            logger.error("should appear")
            for h in logger.handlers:
                h.flush()
            content = open(logfile).read()
            # Close handlers before tempdir cleanup (Windows holds file locks)
            for h in logger.handlers[:]:
                h.close()
                logger.removeHandler(h)
            assert "should not appear" not in content
            assert "should appear" in content

    def test_loglevel_map(self):
        assert LOGLEVEL_MAP[0] == logging.CRITICAL + 10
        assert LOGLEVEL_MAP[3] == logging.ERROR
        assert LOGLEVEL_MAP[4] == logging.WARNING
        assert LOGLEVEL_MAP[6] == logging.INFO
        assert LOGLEVEL_MAP[7] == logging.DEBUG
