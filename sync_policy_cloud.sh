#!/usr/bin/env bash
# Trust the service repo + pull latest policy on ocbc-lab, verify decisions there.
set -e
ssh -i "$HOME/.factory/.ssh/id_ed25519" -o IdentitiesOnly=yes \
  -o ProxyCommand='droid computer ssh ocbc-lab --proxy' \
  -o StrictHostKeyChecking=accept-new factory-user@ocbc-lab '
mkdir -p ~/.factory
python3 - <<EOF
import json, pathlib, datetime
p = pathlib.Path.home()/".factory/settings.json"
s = json.loads(p.read_text()) if p.exists() else {}
s.setdefault("trustedFolders", {})["/home/factory-user/payments-fee-service"] = {"trustedAt": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.000Z")}
p.write_text(json.dumps(s, indent=2)); print("trust written")
EOF
cd ~/payments-fee-service && git pull -q origin main && grep -c "bank/" .factory/settings.json
cd ~/payments-fee-service && droid rules check --command "kubectl rollout undo deployment/payments-fee-service -n prod" 2>&1 | grep -E "decision|rule"'
