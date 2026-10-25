# Incident Lab — PAY-4371 (settlement fee-service degradation)
Synthetic replica of the OCBC-AIOps-shaped topology for the 10-minute Factory demo (`../07_demo_aiops_10min.md`).
Stands in: Redpanda → Kafka · mock Jenkins → Jenkins/Tekton · Postgres → Postgres/Oracle-class RDBMS · Qlik Replicate/Cloudera → seeded telemetry in ES only.

## Bring up (night before)
**Two venues. Cloud (`ocbc-lab`) is primary — webhook automations can only run on Droid Computers; the laptop is the BYOM/session backup.**

```bash
# Cloud venue (primary): one command — ships both repos over the relay, installs,
# brings up the stack, seeds everything, registers MCP, runs verify.sh
bash run_provision_remote.sh

# Laptop venue (backup):
cd incident-lab
docker compose up -d          # ES + Postgres + Redpanda + mock Jenkins + NOC dashboard
sleep 45 && ./verify.sh       # must print PASS on all 5 checks
./seed/seed_es.py             # only if verify shows missing docs (reseed_es.sh = clean reseed)
./seed/seed_kafka.sh

# NOC dashboards: laptop http://localhost:8090 ; cloud http://localhost:8091 via
droid computer port-forward ocbc-lab 8091:8090
```
Postgres seeds automatically on first start (initdb mount). If `verify.sh` fails, re-run after 30s (ES may still be warming).

## Wire to Factory (your org)
1. **MCP shim** (or use Elastic's own MCP): add to droid settings — see `mcp/droid-mcp-config.json`. Org `mcpPolicy` must allowlist `elasticsearch-lab`.
2. **Environment / Droid Computer**: image must contain `psql`, `rpk`, `kubectl`, `jq`, `curl` (or register a Droid Computer via Remote Control on this machine for the live session).
3. **Automation** `PAY Incident Triage`: webhook trigger → paste the URL into `seed/fire_alert.sh` (or export `AUTOMATION_WEBHOOK`), run-as service account, autonomy **Low**.
4. **Overnight fix PR**: in `repo/`, open a Mission/`droid exec --auto medium` task: "Fix the fee-rule lookup regression from commit marked BAD-COMMIT: restore indexed equality path, add migration 0002_add_fee_rules_idx.sql, add regression test. Open PR." Do this the night before so the PR + CI + review comments exist for minute 6:00.
5. **Record every beat** (see fallback rule in the script).

## The scripted incident (memorize this chain)
02:02 deploy build #4177 / commit `5904ad1` (v2.14.0) → 02:05 fee-rule lookups switch to `LIKE '%…'` seq scan on 200k-row `fee_rules` → pool exhaustion → 02:14 p99 ×10, HTTP 500s → Kafka `settlement.fees` consumer lag grows to ~40k → replication lag logged (Qlik Replicate telemetry) → risk dashboards stale, ~41k settlement records delayed. Recovery: rollback build #4177 **via Jenkins job** (policy: ask). Fix: restore equality query + index migration + regression test.

## Teardown
`docker compose down -v`

## Validation status (25 Oct 2026, this machine)
Built and exercised end-to-end: all 5 `verify.sh` checks PASS (ES green + 2,392 docs, Postgres seq-scan reproducible, Kafka lag ~9,999, Jenkins mock history), MCP shim answers `initialize/tools/list/tools/call` (781 ERROR hits), regression test **fails on the deployed bad path and passes on the fixed path**, git repo carries baseline `f37b8f0` + bad commit `5904ad1`. Fixed during validation: ES data-stream name collision (`payments-logs-*`), Redpanda listener port, rpk ≥24 flag changes, bulk-NDJSON trailing newline. The Factory-side wiring (Automation webhook, MCP registration, overnight Mission) is yours to run in your org — that's the night-before checklist above.

## Files
- `docker-compose.yml` — ES 8.15, Postgres 16, Redpanda, mock Jenkins (stdlib, no deps)
- `seed/` — ES log generator, Kafka lag generator, alert webhook firer
- `mcp/es_mcp.py` — minimal stdlib MCP server exposing `search_es` + `es_count` (swap for Elastic's Agent Builder MCP endpoint on ES 9.2+ if you prefer)
- `policy/enterprise-controls.example.json` — the allow/ask/block rules to mirror in Enterprise Controls
- `repo/` — `payments-fee-service` with baseline + BAD commit + regression-test design
- `verify.sh` — the 5 pre-flight checks
