#!/usr/bin/env bash
# Fire the PAY-4371 alert at the Factory Automation webhook.
# Usage: AUTOMATION_WEBHOOK=https://api.factory.ai/api/webhooks/automations/<id> \
#        [WEBHOOK_SECRET=*** ./fire_alert.sh
set -euo pipefail
: "${AUTOMATION_WEBHOOK:?export AUTOMATION_WEBHOOK=<Automation webhook URL> first}"
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SECRET_ARGS=()
if [ -n "${WEBHOOK_SECRET:-}" ]; then
  SECRET_ARGS=(-H "X-Webhook-Secret: $WEBHOOK_SECRET")
fi
curl -sS -X POST -H 'Content-Type: application/json' \
  ${SECRET_ARGS[@]+"${SECRET_ARGS[@]}"} \
  --data @"$DIR/alert.json" "$AUTOMATION_WEBHOOK"
echo
