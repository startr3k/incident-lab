#!/usr/bin/env bash
# Provision the PAY-4371 incident lab on a managed Droid Computer (Ubuntu, factory-user with sudo).
# Usage: git clone https://github.com/startr3k/incident-lab.git && cd incident-lab && ./provision_cloud.sh
# Safe to re-run: seeds are guarded; stack is declarative.
set -euo pipefail

echo "== 1/5 docker =="
if ! sudo docker info >/dev/null 2>&1; then
  sudo apt-get update -qq
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq docker.io >/dev/null
  (sudo systemctl start docker && sudo systemctl enable docker) || sudo service docker start
  for i in $(seq 1 15); do sudo docker info >/dev/null 2>&1 && break; sleep 2; done
fi
if ! sudo docker info >/dev/null 2>&1; then
  echo "DOCKER_UNAVAILABLE: nested containers blocked on this computer."
  echo "Fallback: run services natively (postgres via apt, redpanda binary, ES tarball, mock_jenkins.py via python3)."
  exit 42
fi
sudo usermod -aG docker "$USER" 2>/dev/null || true   # effective next login

echo "== 2/5 repos =="
cd ~
clone() {  # clone() <org/repo> <dir> — uses GH_TOKEN if set, strips creds afterwards
  local src="https://github.com/$1.git" dst="$2"
  [ -d "$dst" ] && return 0
  if [ -n "${GH_TOKEN:-}" ]; then
    git clone "https://x-access-token:${GH_TOKEN}@github.com/$1.git" "$dst"
    git -C "$dst" remote set-url origin "$src"
  else
    git clone "$src" "$dst"
  fi
}
clone startr3k/incident-lab incident-lab
clone startr3k/payments-fee-service payments-fee-service
cd ~/incident-lab
git pull -q --ff-only || true

echo "== 3/5 stack =="
sudo docker compose up -d
echo "waiting for ES health..."
for i in $(seq 1 90); do
  curl -s http://localhost:9200/_cluster/health | grep -qE '"status":"(green|yellow)"' && break
  sleep 2
done

echo "== 4/5 seeds (guarded) =="
# Postgres self-seeds via initdb mount on first boot. Wait until the DB answers
# AND the table check gives a definite answer, so we never seed mid-initdb.
seeded=""
for i in $(seq 1 60); do
  ans=$(sudo docker compose exec -T postgres psql -U ocbc_ro -d settlement -tAc \
        "select exists(select 1 from information_schema.tables where table_name='fee_rules')" 2>/dev/null || true)
  case "$ans" in
    t) seeded=1; echo "postgres already seeded (initdb)"; break ;;
    f) break ;;
    *) sleep 3 ;;
  esac
done
[ -n "$seeded" ] || sudo docker compose exec -T postgres psql -U ocbc_ro -d settlement < seed/seed_postgres.sql
# ES: wipe + reseed so the deploy marker always matches the current bad commit.
curl -s -X DELETE "localhost:9200/payments-logs-*" >/dev/null 2>&1 || true
python3 seed/seed_es.py
sudo bash seed/seed_kafka.sh

echo "== 5/5 MCP registration for droid sessions on this computer =="
mkdir -p ~/.factory
python3 - <<'EOF'
import json, pathlib
p = pathlib.Path.home()/".factory/mcp.json"
cfg = json.loads(p.read_text()) if p.exists() else {}
cfg.setdefault("mcpServers", {})["elasticsearch-lab"] = {
    "command": "python3",
    "args": [str(pathlib.Path.home()/"incident-lab/mcp/es_mcp.py")],
    "env": {"ES_URL": "http://localhost:9200"},
}
p.write_text(json.dumps(cfg, indent=2))
print("registered elasticsearch-lab MCP in ~/.factory/mcp.json")
EOF

sudo bash verify.sh
echo "PROVISION_DONE"
