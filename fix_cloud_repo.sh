#!/usr/bin/env bash
# Clean the payments-fee-service checkout on ocbc-lab: drop macOS AppleDouble
# junk, sync to origin/main, verify policy file present.
set -e
ssh -i "$HOME/.factory/.ssh/id_ed25519" -o IdentitiesOnly=yes \
  -o ProxyCommand='droid computer ssh ocbc-lab --proxy' \
  -o StrictHostKeyChecking=accept-new factory-user@ocbc-lab '
cd ~/payments-fee-service
find . -name "._*" -delete
git fetch -q origin
git checkout -q main 2>/dev/null || true
git reset -q --hard origin/main
echo "HEAD: $(git log --oneline -1)"
echo "policy rules: $(grep -c "bank/" .factory/settings.json 2>/dev/null || echo MISSING)"
echo "untracked: $(git status --short | wc -l | tr -d " ") files"'
