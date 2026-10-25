#!/usr/bin/env bash
# Clean reseed of ES logs on the local lab + restart dashboard.
set -e
cd /Users/dan/Downloads/Factory_Interview_Prep/incident-lab
curl -s -X DELETE "localhost:9200/payments-logs-2026.10.26" >/dev/null
python3 seed/seed_es.py
docker compose restart noc-dashboard >/dev/null 2>&1
sleep 4
curl -s localhost:8090/api/summary | python3 -c "import sys,json; d=json.load(sys.stdin); print('totals:',d['totals'])"
