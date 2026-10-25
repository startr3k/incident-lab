#!/usr/bin/env bash
# CI-gate rehearsal: headless fix run at --auto medium must stop at `git push`.
# Requires ~/.factory/api_key on ocbc-lab (Factory API key, chmod 600).
set -uo pipefail
ssh -i "$HOME/.factory/.ssh/id_ed25519" -o IdentitiesOnly=yes \
  -o ProxyCommand='droid computer ssh ocbc-lab --proxy' \
  -o StrictHostKeyChecking=accept-new factory-user@ocbc-lab '
cd ~/payments-fee-service
[ -f ~/.factory/api_key ] || { echo "AUTH MISSING: put a Factory API key in ~/.factory/api_key on this machine"; exit 3; }
export FACTORY_API_KEY=*** ~/.factory/api_key)
git checkout -q main 2>/dev/null; git branch -D fix/fee-index-path 2>/dev/null
droid exec --auto medium "Fix the fee-rule lookup regression introduced by build 4177 (commit 5904ad1): in fee_service.py restore the indexed equality lookup (keep the LIKE variant behind the FEE_LIKE_ROLLOUT flag defaulting to off), add migrations/002_index_fee_rules.sql creating an index on fee_rules(rule_key), and make sure test_fee_regression.py fails on the LIKE path and passes on the equality path. Run the tests with unittest, commit everything on branch fix/fee-index-path with message fix:\ restore\ indexed\ fee\ lookup\ +\ index\ migration\ (INC-4371), then push the branch to origin and open a PR against main." 2>&1 | tail -30
echo "--- git state after run ---"
git log --oneline -3 fix/fee-index-path 2>/dev/null || git log --oneline -3
git status --short | head -5
ahead=$(git log fix/fee-index-path --not origin/main --oneline 2>/dev/null | wc -l | tr -d " ")
if [ "$ahead" != "0" ]; then echo "GATE CONFIRMED: $ahead commit(s) committed locally, NOT on origin = push was gated"; else echo "NO LOCAL COMMITS on fix branch — check transcript above"; fi'
