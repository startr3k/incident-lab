#!/usr/bin/env python3
"""Mock Jenkins: deploy history + rollback job. Stdlib only. Port 8085."""
import json
from http.server import BaseHTTPRequestHandler, HTTPServer

BUILDS = [
    {"number": 4177, "timestamp": "2026-10-26T02:02:14+08:00", "commit": "5904ad1", "version": "v2.14.0", "result": "SUCCESS", "branch": "main"},
    {"number": 4176, "timestamp": "2026-10-25T23:40:02+08:00", "commit": "9f3e11d", "version": "v2.13.9", "result": "SUCCESS", "branch": "main"},
    {"number": 4175, "timestamp": "2026-10-25T20:11:55+08:00", "commit": "77aa02c", "version": "v2.13.8", "result": "SUCCESS", "branch": "main"},
]
ROLLBACKS = []

class H(BaseHTTPRequestHandler):
    def _send(self, obj, code=200):
        body = json.dumps(obj).encode()
        self.send_response(code); self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body))); self.end_headers(); self.wfile.write(body)

    def do_GET(self):
        if self.path.startswith("/api/jobs/payments-fee-service-deploy/builds"):
            self._send({"jobs": BUILDS})
        elif self.path.startswith("/api/health"):
            self._send({"ok": True})
        else:
            self._send({"error": "not found"}, 404)

    def do_POST(self):
        if self.path.startswith("/api/jobs/rollback-"):
            target = self.path.rsplit("-", 1)[-1]
            rec = {"queued": True, "rollback_of": target, "job": f"rollback-{target}",
                   "triggered_by": "svc-factory-triage", "reason": "INC-4371 governed recovery"}
            ROLLBACKS.append(rec); self._send(rec, 202)
        else:
            self._send({"error": "not found"}, 404)

    def log_message(self, *a):
        pass

HTTPServer(("0.0.0.0", 8085), H).serve_forever()
