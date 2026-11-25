"""Serve the local demo under Windows Task Scheduler."""

from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import json
import logging
from logging.handlers import RotatingFileHandler
import os
from pathlib import Path
import subprocess
import sys
import time
from urllib.parse import urlsplit


ROOT = Path(__file__).resolve().parent
LOG_DIRECTORY = Path(os.environ.get("LOCALAPPDATA", Path.home())) / "QingxuPreview" / "logs"
LOG_DIRECTORY.mkdir(parents=True, exist_ok=True)
logger = logging.getLogger("qingxu-preview")
logger.setLevel(logging.INFO)
LOG_NAME = "supervisor.log" if "--supervise" in sys.argv else "preview.log"
logger.addHandler(RotatingFileHandler(
    LOG_DIRECTORY / LOG_NAME, maxBytes=1_000_000, backupCount=3, encoding="utf-8"
))
logger.handlers[0].setFormatter(logging.Formatter("%(asctime)s %(levelname)s %(message)s"))


class PreviewHandler(SimpleHTTPRequestHandler):
    def do_GET(self):
        path = urlsplit(self.path).path
        if path == "/healthz":
            payload = json.dumps({"status": "ok", "service": "qingxu-local-preview"}).encode()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)
        elif path in {"/", "/index.html", "/app.js", "/style.css", "/favicon.ico"}:
            super().do_GET()
        else:
            self.send_error(404)

    def do_HEAD(self):
        if urlsplit(self.path).path in {"/", "/index.html", "/app.js", "/style.css"}:
            super().do_HEAD()
        else:
            self.send_error(404)

    def end_headers(self):
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def log_message(self, format_string, *args):
        logger.info("%s %s", self.client_address[0], format_string % args)


class PreviewServer(ThreadingHTTPServer):
    def handle_error(self, request, client_address):
        logger.exception("Request failed from %s", client_address)


def main():
    for asset in ("index.html", "app.js", "style.css"):
        if not (ROOT / asset).is_file():
            raise FileNotFoundError(ROOT / asset)
    handler = partial(PreviewHandler, directory=str(ROOT))
    with PreviewServer(("127.0.0.1", 18946), handler) as server:
        logger.info("Started PID %s at http://127.0.0.1:18946/ from %s", os.getpid(), ROOT)
        server.serve_forever()


def supervise():
    logger.info("Supervisor started PID %s", os.getpid())
    while True:
        try:
            process = subprocess.Popen(
                [sys.executable, str(Path(__file__).resolve())],
                creationflags=subprocess.CREATE_NO_WINDOW,
                stdin=subprocess.DEVNULL,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
            logger.info("Started server PID %s", process.pid)
            result = process.wait()
            logger.warning("Server exited with code %s; restarting in 2 seconds", result)
        except OSError:
            logger.exception("Could not start server")
        time.sleep(2)


if __name__ == "__main__":
    try:
        if "--supervise" in sys.argv:
            supervise()
        else:
            main()
    except Exception:
        logger.exception("Local preview stopped")
        raise
