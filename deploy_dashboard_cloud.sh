#!/usr/bin/env bash
# Deploy NOC dashboard to ocbc-lab + clean ES reseed there.
set -e
SSH=(ssh -i "$HOME/.factory/.ssh/id_ed25519" -o IdentitiesOnly=yes
     -o ProxyCommand='droid computer ssh ocbc-lab --proxy'
     -o StrictHostKeyChecking=accept-new factory-user@ocbc-lab)
cd /Users/dan/Downloads/Factory_Interview_Prep/incident-lab
scp -i "$HOME/.factory/.ssh/id_ed25519" -o IdentitiesOnly=yes \
  -o ProxyCommand='droid computer ssh ocbc-lab --proxy' \
  mock/noc_dashboard.py docker-compose.yml factory-user@ocbc-lab:/tmp/ >/dev/null
"${SSH[@]}" 'cp /tmp/noc_dashboard.py ~/incident-lab/mock/ && cp /tmp/docker-compose.yml ~/incident-lab/ && cd ~/incident-lab && sudo docker compose up -d noc-dashboard >/dev/null 2>&1; sudo docker compose restart noc-dashboard >/dev/null 2>&1; curl -s -X DELETE "localhost:9200/payments-logs-2026.10.26" >/dev/null 2>&1; python3 seed/seed_es.py; sudo bash seed/seed_kafka.sh >/dev/null 2>&1; sleep 4; curl -s localhost:8090/api/summary | python3 -c "import sys,json; d=json.load(sys.stdin); print(\"cloud totals:\",d[\"totals\"],\"| deploys:\",[b[\"number\"] for b in d[\"deploys\"]])"; sudo bash verify.sh | tail -1'
