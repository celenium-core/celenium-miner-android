#!/usr/bin/env python3
"""A stand-in stratum bridge that serves the same /api/status and /api/stats
bodies the real bridge does, so the app can be screenshotted in its live
mining state without running a node.

Run: python3 scripts/mock_bridge.py [port]
"""
import json
import sys
import time
from http.server import BaseHTTPRequestHandler, HTTPServer

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 3030

STATUS = {
    "celeniumd_address": "127.0.0.1:26510",
    "celeniumd_version": "2.1.0-a438515",
    "instances": 1,
    "web_bind": "0.0.0.0:3030",
}

WALLET = "celeniumsim:qpqz9k3x8v2m7n4b6c1d5f8g0h3j6k9l2"


def stats():
    return {
        "totalBlocks": 3,
        "totalShares": 1204,
        "networkHashrate": 4500000000000,
        "networkDifficulty": 1234567.5,
        "networkBlockCount": 1920,
        "activeWorkers": 1,
        "internalCpu": {
            "hashrateGhs": 1.42,
            "hashesTried": 900000000,
            "blocksSubmitted": 3,
            "blocksAccepted": 2,
            "shares": 1204,
            "stale": 1,
            "invalid": 0,
            "wallet": WALLET,
        },
        "blocks": [
            {
                "instance": "default",
                "worker": "asic-1",
                "wallet": WALLET,
                "timestamp": "2026-10-29T11:02:18Z",
                "hash": "eeb6fa5d8c1a4b7e9f0d2c3b5a6978871d4e6f8a0b1c2d3e4f5a6b7c8d9e0f1a",
            },
            {
                "instance": "default",
                "worker": "asic-1",
                "wallet": WALLET,
                "timestamp": "2026-10-29T10:14:55Z",
                "hash": "a1b2c3d4e5f60718293a4b5c6d7e8f90112233445566778899aabbccddeeff00",
            },
        ],
        "workers": [
            {
                "instance": "default",
                "worker": "asic-1",
                "wallet": WALLET,
                "hashrate": 1.42,
                "shares": 1204,
                "stale": 1,
                "invalid": 0,
                "blocks": 2,
                "lastSeen": int(time.time()),
                "status": "online",
                "currentDifficulty": 8.0,
                "sessionUptime": 3600,
            }
        ],
        "bridgeUptime": 7200,
    }


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path.startswith("/api/status"):
            body = STATUS
        elif self.path.startswith("/api/stats"):
            body = stats()
        else:
            self.send_error(404)
            return
        payload = json.dumps(body).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def log_message(self, *args):
        pass


if __name__ == "__main__":
    print("mock bridge on http://127.0.0.1:%d" % PORT, flush=True)
    HTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
