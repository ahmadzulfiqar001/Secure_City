"""Structured logging setup — one call at app startup.

Keeps a consistent `ts level logger msg key=value...` shape so logs are
greppable/parseable without pulling in a heavier logging stack for a
project this size.
"""
import logging
import sys


_BASE_RECORD_KEYS = set(logging.LogRecord("", 0, "", 0, "", (), None).__dict__) | {"message", "asctime"}


class KeyValueFormatter(logging.Formatter):
    def format(self, record: logging.LogRecord) -> str:
        base = super().format(record)  # also sets record.asctime as a side effect
        extras = {k: v for k, v in record.__dict__.items() if k not in _BASE_RECORD_KEYS}
        if extras:
            base += " " + " ".join(f"{k}={v}" for k, v in extras.items())
        return base


def configure_logging(level: str = "INFO") -> None:
    handler = logging.StreamHandler(sys.stdout)
    handler.setFormatter(KeyValueFormatter("%(asctime)s level=%(levelname)s logger=%(name)s msg=%(message)s"))

    root = logging.getLogger()
    root.setLevel(level)
    root.handlers = [handler]

    # Quiet down noisy third-party loggers unless we're actually debugging.
    if level != "DEBUG":
        logging.getLogger("uvicorn.access").setLevel("WARNING")
