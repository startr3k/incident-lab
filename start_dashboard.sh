#!/usr/bin/env bash
# Bring up the NOC dashboard service on the local lab.
set -e
cd /Users/dan/Downloads/Factory_Interview_Prep/incident-lab
docker compose up -d noc-dashboard
docker compose restart noc-dashboard
sleep 5
curl -s localhost:8090/api/summary | python3 -c "import sys,json; d=json.load(sys.stdin); print('errors:',len(d['errors']),'slow:',len(d['slow']),'lag:',len(d['lag']),'replag:',len(d['replag']),'deploys:',[b['number'] for b in d['deploys']],'totals:',d['totals'])"
echo "dashboard HTML ok: $(curl -s localhost:8090/ | grep -c 'PAY-4371') marker(s)"
