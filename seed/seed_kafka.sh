#!/usr/bin/env bash
# Create topic, produce 10k messages, create consumer group at offset 1 -> visible lag ~9999.
set -euo pipefail
R="docker compose exec -T redpanda rpk"
$R topic create settlement.fees 2>/dev/null || true
seq 1 10000 | $R topic produce settlement.fees >/dev/null 2>&1
# rpk >=24 removed `group new`; create the group by consuming exactly one message (commits offset 1)
echo | $R topic consume settlement.fees -g fee-aggregator -n 1 -o 0 >/dev/null 2>&1 || true
$R topic describe settlement.fees | sed -n '1,12p'
echo "--- consumer group (lag should be ~9999) ---"
$R group describe fee-aggregator 2>/dev/null | sed -n '1,6p'
