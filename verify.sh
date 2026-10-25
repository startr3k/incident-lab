#!/usr/bin/env bash
# Pre-flight verification for the PAY-4371 incident lab. Prints PASS/FAIL per check.
set -uo pipefail
pass=0; fail=0
chk() { if eval "$2" >/dev/null 2>&1; then echo "PASS  $1"; pass=$((pass+1)); else echo "FAIL  $1"; fail=$((fail+1)); fi; }

chk "elasticsearch up"            "curl -s http://localhost:9200/_cluster/health | grep -qE '\"status\":\"(green|yellow)\"'"
chk "logs indexed (>=1000 docs)"  "test \$(curl -s 'http://localhost:9200/payments-logs-*/_count' | python3 -c 'import sys,json;print(json.load(sys.stdin)[\"count\"])') -ge 1000"
chk "postgres seq-scan reproducible" "docker compose exec -T postgres psql -U ocbc_ro -d settlement -c \"EXPLAIN (FORMAT JSON) SELECT rate FROM fee_rules WHERE rule_key LIKE '%FEE_0137_9%'\" | grep -qi 'Seq Scan'"
chk "kafka lag on settlement.fees" "docker compose exec -T redpanda rpk group describe fee-aggregator | grep -qE 'LAG[[:space:]]+[1-9]'"
chk "jenkins mock deploy history"  "curl -s http://localhost:8085/api/jobs/payments-fee-service-deploy/builds | grep -q 5904ad1"

echo "---- $pass passed, $fail failed"
[ "$fail" -eq 0 ]
