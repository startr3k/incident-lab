#!/usr/bin/env bash
# Ship both repos (with history) to ocbc-lab over the relay, then provision.
set -euo pipefail
SSH=(ssh -i "$HOME/.factory/.ssh/id_ed25519" -o IdentitiesOnly=yes
     -o ProxyCommand='droid computer ssh ocbc-lab --proxy'
     -o StrictHostKeyChecking=accept-new factory-user@ocbc-lab)

echo "== shipping incident-lab =="
tar czf - -C /Users/dan/Downloads/Factory_Interview_Prep \
  --exclude 'incident-lab/.git' --exclude 'incident-lab/volumes' \
  --exclude 'incident-lab/repo' --exclude '__pycache__' \
  incident-lab | "${SSH[@]}" 'mkdir -p ~ && tar xzf - -C ~ && echo incident-lab shipped'

echo "== shipping payments-fee-service (with git history) =="
tar czf - -C /Users/dan/Downloads/Factory_Interview_Prep/incident-lab \
  --exclude '__pycache__' repo | "${SSH[@]}" 'tar xzf - && mv -f repo payments-fee-service && echo payments-fee-service shipped'

echo "== provisioning =="
"${SSH[@]}" 'bash -s' < /Users/dan/Downloads/Factory_Interview_Prep/incident-lab/provision_cloud.sh
