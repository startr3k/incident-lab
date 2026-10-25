#!/usr/bin/env bash
# Validate the bank policy ruleset + preview the demo's key decisions.
cd /Users/dan/Downloads/Factory_Interview_Prep/incident-lab
echo "== full-file validation (all embedded examples must pass) =="
droid rules check --file policy/permission-rules.json && echo "RULES FILE VALID"
echo
for cmd in \
  'kubectl rollout undo deployment/payments-fee-service -n prod' \
  'kubectl delete pod fee-7f9-x -n prod-sg' \
  'kubectl get pods -n prod' \
  'curl -X POST http://localhost:8085/api/jobs/rollback-4177/run' \
  'git push origin fix/fee-index-path' \
  'terraform destroy -auto-approve'
do
  d=$(droid rules check --file policy/permission-rules.json --command "$cmd" 2>&1 | grep -E "^decision:" | awk '{print $2}')
  printf '%-70s -> %s\n' "${cmd:0:68}" "$d"
done
