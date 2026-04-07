"""LoxBerry-compatible logging — matches <TAG> YYYY-MM-DD HH:MM:SS format."""
import logging
import os
from datetime import datetime
from logging.handlers import RotatingFileHandler

OK = 25
logging.addLevelName(OK, "OK")

LOGLEVEL_MAP = {
    0: logging.CRITICAL + 10,  # Off
    3: logging.ERROR,
    4: logging.WARNING,
    6: logging.INFO,
    7: logging.DEBUG,
}

_TAG_MAP = {
    logging.DEBUG: "DEBUG",
    logging.INFO: "INFO",
    OK: "OK",
    logging.WARNING: "WARNING",
    logging.ERROR: "ERROR",
    logging.CRITICAL: "ERROR",
}


class LoxBerryFormatter(logging.Formatter):
    def format(self, record: logging.LogRecord) -> str:
        tag = _TAG_MAP.get(record.levelno, "INFO")
        ts = datetime.fromtimestamp(record.created).strftime("%Y-%m-%d %H:%M:%S")
        msg = record.getMessage()
        return f"<{tag}> {ts} {msg}"


def setup_logging(
    logfile: str = "/dev/shm/mqttgateway.log",
    loglevel: int = 7,
) -> logging.Logger:
    logger = logging.getLogger("mqttgateway")
    logger.handlers.clear()

    py_level = LOGLEVEL_MAP.get(loglevel, logging.DEBUG)
    logger.setLevel(py_level)

    formatter = LoxBerryFormatter()

    if os.path.dirname(logfile):
        os.makedirs(os.path.dirname(logfile), exist_ok=True)
    fh = RotatingFileHandler(logfile, maxBytes=5 * 1024 * 1024, backupCount=3)
    fh.setFormatter(formatter)
    fh.setLevel(py_level)
    logger.addHandler(fh)

    sh = logging.StreamHandler()
    sh.setFormatter(formatter)
    sh.setLevel(py_level)
    logger.addHandler(sh)

    return logger
